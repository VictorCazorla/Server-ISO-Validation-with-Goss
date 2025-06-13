#!/bin/bash
MEM_TOTAL_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEMLOCK_VAL=$((MEM_TOTAL_KB * 90 / 100))
VAR_LINE="memlock: $MEMLOCK_VAL"
FILE="11.12_Variables.yaml"

if [ ! -f "$FILE" ]; then
  echo "$VAR_LINE" > "$FILE"
else
  if grep -q "^memlock:" "$FILE"; then
    sed -i "s/^memlock:.*/$VAR_LINE/" "$FILE"
  else
    tail -c1 "$FILE" | read -r _ || echo >> "$FILE"
    echo "$VAR_LINE" >> "$FILE"
  fi
fi