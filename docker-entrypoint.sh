#!/bin/sh
# Startet den Spielserver nicht als root: /data bekommt die Rechte von PUID:PGID
# (Standard 99:100 = "nobody:users" wie bei Unraid üblich), dann wird der Benutzer gewechselt.
set -e
PUID="${PUID:-99}"
PGID="${PGID:-100}"
if [ "$(id -u)" = "0" ]; then
	mkdir -p "${DATA_DIR:-/data}"
	chown -R "$PUID:$PGID" "${DATA_DIR:-/data}" 2>/dev/null || true
	exec setpriv --reuid="$PUID" --regid="$PGID" --clear-groups "$@"
fi
exec "$@"
