#!/bin/bash
# Fetch and persist aria2 BitTorrent trackers from the configured public lists.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin:/sbin
export PATH

CONFIG=/etc/ccaa/aria2.conf
CACHE=/etc/ccaa/bt-tracker.list
TMP_DIR=$(mktemp -d) || exit 0
trap 'rm -rf "$TMP_DIR"' EXIT

fetch_list() {
	url=$1
	output=$2
	if command -v curl >/dev/null 2>&1; then
		curl -fLsS --connect-timeout 8 --max-time 20 "$url" -o "$output"
	else
		wget -q --timeout=20 --tries=1 -O "$output" "$url"
	fi
}

: > "$TMP_DIR/all"
fetched=0
for url in \
	'https://cf.trackerslist.com/best.txt' \
	'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all.txt' \
	'https://tracker.adysec.com/trackers_best_http.txt' \
	'https://tracker.adysec.com/trackers_best_https.txt' \
	'https://tracker.adysec.com/trackers_best_udp.txt' \
	'https://tracker.adysec.com/trackers_best_wss.txt'; do
	if fetch_list "$url" "$TMP_DIR/source"; then
		cat "$TMP_DIR/source" >> "$TMP_DIR/all"
		fetched=1
	else
		echo "Tracker source unavailable: $url" >&2
	fi
done

TRACKERS=$(awk '
	{
		gsub(/\r/, "")
		gsub(/^[ \t]+|[ \t]+$/, "")
	}
	/^(http|https|udp|ws|wss):\/\// && !seen[$0]++ {
		if (count++) printf ","
		printf "%s", $0
	}
	END { if (count) printf "\n" }
' "$TMP_DIR/all")

if [ -z "$TRACKERS" ]; then
	if [ -s "$CACHE" ]; then
		TRACKERS=$(cat "$CACHE")
	else
		TRACKERS=$(sed -n 's/^bt-tracker=//p' "$CONFIG" | tail -n 1)
	fi
	if [ -z "$TRACKERS" ]; then
		echo 'No tracker list available; keeping aria2 configuration unchanged.' >&2
		exit 0
	fi
else
	if [ "$fetched" -eq 1 ]; then
		TMP_CACHE=$(mktemp /etc/ccaa/bt-tracker.list.XXXXXX) || exit 0
		printf '%s\n' "$TRACKERS" > "$TMP_CACHE"
		chown ccaa:ccaa "$TMP_CACHE" 2>/dev/null || true
		mv "$TMP_CACHE" "$CACHE"
	fi
fi

TMP_CONFIG=$(mktemp /etc/ccaa/aria2.conf.XXXXXX) || exit 0
awk -v tracker="$TRACKERS" '
	BEGIN { found = 0 }
	/^bt-tracker=/ {
		if (!found) print "bt-tracker=" tracker
		found = 1
		next
	}
	{ print }
	END { if (!found) print "bt-tracker=" tracker }
' "$CONFIG" > "$TMP_CONFIG" || { rm -f "$TMP_CONFIG"; exit 0; }
chown --reference="$CONFIG" "$TMP_CONFIG" 2>/dev/null || true
chmod --reference="$CONFIG" "$TMP_CONFIG" 2>/dev/null || true
mv "$TMP_CONFIG" "$CONFIG"

if [ "${1:-}" != '--pre-start' ]; then
	if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet aria2.service; then
		systemctl restart aria2.service
	elif pgrep -x aria2c >/dev/null 2>&1; then
		/usr/sbin/ccaa restart
	fi
fi

echo "BT tracker list updated."
