(function () {
    'use strict';

    var itemId = 'ccaa-delete-task-and-files';

    function selectedGids() {
        var rows = document.querySelectorAll('#task-table .task-table-body .row[data-gid][data-selected="true"]');
        var gids = [];
        Array.prototype.forEach.call(rows, function (row) {
            var gid = row.getAttribute('data-gid');
            if (gid && gids.indexOf(gid) < 0) {
                gids.push(gid);
            }
        });
        return gids;
    }

    function currentRpcSecret() {
        if (!window.angular) {
            return '';
        }
        var wrapper = document.querySelector('.wrapper');
        var scope = wrapper && angular.element(wrapper).scope();
        var settings = scope && scope.rpcSettings;
        if (!settings) {
            return '';
        }
        for (var i = 0; i < settings.length; i++) {
            if (settings[i].isDefault) {
                return settings[i].secret || '';
            }
        }
        return '';
    }

    function deleteSelectedTasks(event) {
        event.preventDefault();
        event.stopPropagation();

        var gids = selectedGids();
        if (gids.length === 0) {
            window.alert('请先勾选要删除的任务。');
            return;
        }

        var secret = currentRpcSecret();
        if (!secret) {
            window.alert('未读取到当前 Aria2 RPC 密钥，请先连接 Aria2。');
            return;
        }

        if (!window.confirm('确定删除选中的任务、已下载文件及任务文件夹（含文件夹内其他内容）？此操作不可撤销。')) {
            return;
        }

        var host = window.location.hostname;
        if (host.indexOf(':') >= 0 && host.charAt(0) !== '[') {
            host = '[' + host + ']';
        }

        window.fetch(window.location.protocol + '//' + host + ':6082/api/delete-task-files', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-Aria2-Secret': secret
            },
            body: JSON.stringify({ gids: gids })
        }).then(function (response) {
            return response.json().then(function (data) {
                if (!response.ok && response.status !== 207) {
                    throw new Error(data.error || '删除请求失败');
                }
                return data;
            });
        }).then(function (data) {
            var failures = (data.results || []).filter(function (result) {
                return !result.success;
            });
            if (failures.length > 0) {
                window.alert('部分任务未能完整删除：' + failures.map(function (result) {
                    return result.gid + '：' + result.error;
                }).join('\n'));
            } else {
                var deletedFiles = (data.results || []).reduce(function (total, result) {
                    return total + (result.deleted_files || 0);
                }, 0);
                var deletedFolders = (data.results || []).reduce(function (total, result) {
                    return total + (result.deleted_folders || 0);
                }, 0);
                window.alert('已删除 ' + data.results.length + ' 个任务、' + deletedFiles + ' 个文件及 ' + deletedFolders + ' 个任务文件夹。');
            }
            window.location.reload();
        }).catch(function (error) {
            window.alert('删除失败：' + error.message);
        });
    }

    function addDeleteFilesItem() {
        var menus = document.querySelectorAll('.navbar-toolbar .nav.navbar-nav > li > ul.dropdown-menu');
        Array.prototype.forEach.call(menus, function (menu) {
            var trigger = null;
            Array.prototype.forEach.call(menu.parentElement.children, function (child) {
                if (!trigger && child.tagName === 'A' && child.classList.contains('toolbar') && child.classList.contains('dropdown-toggle')) {
                    trigger = child;
                }
            });
            if (!trigger || !trigger.querySelector('.fa-trash-o') || menu.querySelector('#' + itemId)) {
                return;
            }

            var divider = document.createElement('li');
            divider.className = 'divider';
            divider.setAttribute('aria-hidden', 'true');

            var item = document.createElement('li');
            item.id = itemId;
            var link = document.createElement('a');
            link.href = '#';
            link.className = 'pointer-cursor';
            link.textContent = '删除任务及文件';
            link.addEventListener('click', deleteSelectedTasks, false);
            item.appendChild(link);
            menu.appendChild(divider);
            menu.appendChild(item);
        });
    }

    var observer = new MutationObserver(addDeleteFilesItem);
    observer.observe(document.documentElement, { childList: true, subtree: true });
    addDeleteFilesItem();
}());

