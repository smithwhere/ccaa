#!/usr/bin/env python3
"""Authenticated API for removing aria2 tasks and their downloaded files."""

import hmac
import json
import os
import re
import shutil
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import Request, urlopen


CONFIG_PATH = "/etc/ccaa/aria2.conf"
LISTEN_HOST = "0.0.0.0"
LISTEN_PORT = 6082
MAX_BODY_SIZE = 65536
GID_PATTERN = re.compile(r"^[0-9a-fA-F]{16}$")
INFO_HASH_PATTERN = re.compile(r"^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$")


class ApiError(Exception):
    pass


def read_config():
    values = {}
    with open(CONFIG_PATH, "r", encoding="utf-8") as config_file:
        for line in config_file:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()

    secret = values.get("rpc-secret", "")
    download_dir = values.get("dir", "")
    if not secret or not download_dir:
        raise ApiError("Aria2 RPC secret or download directory is not configured")

    if not os.path.isabs(download_dir):
        download_dir = os.path.join(os.path.dirname(CONFIG_PATH), download_dir)

    return {
        "secret": secret,
        "port": int(values.get("rpc-listen-port", "6800")),
        "download_root": os.path.realpath(download_dir),
    }


def rpc_call(config, method, *args):
    payload = json.dumps({
        "jsonrpc": "2.0",
        "id": "ccaa-delete-files",
        "method": "aria2." + method,
        "params": ["token:" + config["secret"]] + list(args),
    }).encode("utf-8")
    request = Request(
        "http://127.0.0.1:{}/jsonrpc".format(config["port"]),
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urlopen(request, timeout=15) as response:
            result = json.loads(response.read().decode("utf-8"))
    except HTTPError as error:
        try:
            result = json.loads(error.read().decode("utf-8"))
        except (UnicodeDecodeError, ValueError):
            raise ApiError("Could not communicate with aria2") from error
        if "error" in result:
            raise ApiError("aria2 rejected the operation: " + result["error"].get("message", "request failed")) from error
        raise ApiError("Could not communicate with aria2") from error
    except (URLError, TimeoutError, ValueError) as error:
        raise ApiError("Could not communicate with aria2") from error

    if "error" in result:
        raise ApiError("aria2 rejected the operation")
    return result.get("result")


def is_within_root(path, root):
    try:
        return os.path.commonpath([path, root]) == root
    except ValueError:
        return False


def validate_task_file(path, root):
    if not path:
        return None
    if not os.path.isabs(path):
        path = os.path.join(root, path)

    path = os.path.abspath(path)
    resolved_path = os.path.realpath(path)
    if resolved_path == root or not is_within_root(resolved_path, root):
        raise ApiError("A task file is outside the configured download directory")
    if os.path.islink(path):
        raise ApiError("A task file is a symbolic link; refusing to remove it")
    if not os.path.lexists(path):
        return None
    if not os.path.isfile(path):
        raise ApiError("A task path is not a regular file; refusing to remove it")
    return path


def task_parent_directory(path, root):
    """Return a task file's safe parent directory, unless it is the download root."""
    if not os.path.isabs(path):
        path = os.path.join(root, path)
    parent = os.path.abspath(os.path.dirname(path))
    resolved_parent = os.path.realpath(parent)
    if parent != resolved_parent or not is_within_root(parent, root):
        raise ApiError("A task directory is outside the configured download directory or is a symbolic link")

    if parent == root:
        return None
    return parent


def delete_task_and_files(config, gid):
    task = rpc_call(config, "tellStatus", gid, ["gid", "status", "files", "infoHash", "dir"])
    if not isinstance(task, dict) or task.get("gid") != gid:
        raise ApiError("aria2 did not return the requested task")

    files = task.get("files") or []
    paths = []
    seen = set()
    task_directories = set()
    for item in files:
        task_path = item.get("path", "")
        if task_path:
            directory = task_parent_directory(task_path, config["download_root"])
            if directory:
                task_directories.add(directory)
        path = validate_task_file(task_path, config["download_root"])
        if path and path not in seen:
            paths.append(path)
            seen.add(path)
            control_file = validate_task_file(path + ".aria2", config["download_root"])
            if control_file and control_file not in seen:
                paths.append(control_file)
                seen.add(control_file)

    # aria2 keeps magnet-link metadata outside the download file list as
    # <infoHash>.torrent when bt-save-metadata is enabled.
    info_hash = task.get("infoHash", "")
    if info_hash:
        if not INFO_HASH_PATTERN.fullmatch(info_hash):
            raise ApiError("aria2 returned an invalid torrent info hash")
        task_dir = task.get("dir") or config["download_root"]
        metadata_path = validate_task_file(
            os.path.join(task_dir, info_hash.lower() + ".torrent"),
            config["download_root"],
        )
        if metadata_path and metadata_path not in seen:
            paths.append(metadata_path)
            seen.add(metadata_path)
            metadata_control_file = validate_task_file(metadata_path + ".aria2", config["download_root"])
            if metadata_control_file and metadata_control_file not in seen:
                paths.append(metadata_control_file)
                seen.add(metadata_control_file)

    status = task.get("status")
    if status in ("active", "waiting", "paused"):
        rpc_call(config, "forceRemove", gid)
        rpc_call(config, "removeDownloadResult", gid)
    elif status in ("complete", "error", "removed"):
        rpc_call(config, "removeDownloadResult", gid)
    else:
        raise ApiError("aria2 returned an unsupported task status")

    deleted = 0
    for path in paths:
        try:
            os.remove(path)
            deleted += 1
        except FileNotFoundError:
            pass
        except OSError as error:
            raise ApiError("The task was removed, but a downloaded file could not be deleted") from error

    # Remove only the deepest shared task directory. Never walk up to a broader
    # directory that could contain downloads belonging to other tasks.
    deleted_folders = 0
    if task_directories:
        try:
            directory = os.path.commonpath(sorted(task_directories))
        except ValueError:
            directory = config["download_root"]
        try:
            if (
                directory != config["download_root"]
                and not os.path.islink(directory)
                and os.path.realpath(directory) == directory
                and is_within_root(directory, config["download_root"])
                and os.path.isdir(directory)
            ):
                shutil.rmtree(directory)
                deleted_folders += 1
        except FileNotFoundError:
            pass
        except OSError as error:
            raise ApiError("The task was removed, but its folder could not be deleted") from error

    return {"gid": gid, "deleted_files": deleted, "deleted_folders": deleted_folders}


class Handler(BaseHTTPRequestHandler):
    server_version = "CCAADeleteAPI/1.0"

    def log_message(self, _format, *_args):
        # Do not log request headers, which contain the RPC secret.
        return

    def allowed_origin(self):
        origin = self.headers.get("Origin", "")
        parsed_origin = urlparse(origin)
        parsed_host = urlparse("//" + self.headers.get("Host", ""))
        try:
            return (
                parsed_origin.scheme in ("http", "https")
                and parsed_origin.port == 6080
                and parsed_origin.hostname
                and parsed_origin.hostname.lower() == (parsed_host.hostname or "").lower()
            )
        except ValueError:
            return False

    def send_json(self, status, data):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        if self.allowed_origin():
            self.send_header("Access-Control-Allow-Origin", self.headers["Origin"])
            self.send_header("Vary", "Origin")
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        if not self.allowed_origin():
            self.send_json(403, {"error": "Origin not allowed"})
            return
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", self.headers["Origin"])
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, X-Aria2-Secret")
        self.send_header("Access-Control-Max-Age", "600")
        self.send_header("Vary", "Origin")
        self.end_headers()

    def do_POST(self):
        if self.path != "/api/delete-task-files" or not self.allowed_origin():
            self.send_json(403, {"error": "Request not allowed"})
            return

        try:
            config = read_config()
        except (ApiError, OSError, ValueError):
            self.send_json(503, {"error": "Deletion service is not configured"})
            return

        supplied_secret = self.headers.get("X-Aria2-Secret", "")
        if not supplied_secret or not hmac.compare_digest(supplied_secret, config["secret"]):
            self.send_json(401, {"error": "Aria2 RPC secret is invalid"})
            return

        try:
            content_length = int(self.headers.get("Content-Length", "0"))
            if content_length < 1 or content_length > MAX_BODY_SIZE:
                raise ValueError("invalid body length")
            payload = json.loads(self.rfile.read(content_length).decode("utf-8"))
            gids = payload.get("gids") if isinstance(payload, dict) else None
            if not isinstance(gids, list) or not gids or len(gids) > 100:
                raise ValueError("invalid gids")
            if any(not isinstance(gid, str) or not GID_PATTERN.fullmatch(gid) for gid in gids):
                raise ValueError("invalid gid")
        except (UnicodeDecodeError, ValueError, json.JSONDecodeError):
            self.send_json(400, {"error": "Invalid request body"})
            return

        results = []
        for gid in dict.fromkeys(gids):
            try:
                results.append({"success": True, **delete_task_and_files(config, gid)})
            except ApiError as error:
                results.append({"success": False, "gid": gid, "error": str(error)})

        success = all(item["success"] for item in results)
        self.send_json(200 if success else 207, {"success": success, "results": results})


if __name__ == "__main__":
    ThreadingHTTPServer((LISTEN_HOST, LISTEN_PORT), Handler).serve_forever()

