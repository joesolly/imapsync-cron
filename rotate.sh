#!/bin/sh

FILE="$1"
MAX="${2:-$MAX_LOG_SIZE}"

[ ! -f "$FILE" ] && exit 0

SIZE=$(stat -c%s "$FILE" 2>/dev/null || echo 0)

if [ "$SIZE" -gt "$MAX" ]; then
    echo "[$(date)] Rotating $FILE (size $SIZE > $MAX)" >&2
    : > "$FILE"
fi

