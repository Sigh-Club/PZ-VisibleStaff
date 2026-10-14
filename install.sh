#!/bin/bash
# SighNet VisibleStaff installer — server-side classpath override.
# Usage: ./install.sh /path/to/ProjectZomboid  (dir containing java/projectzomboid.jar)
# Idempotent; backs up nothing (the game jar is never modified; delete the
# loose classes to uninstall).
set -e
PZ="${1:?usage: install.sh /path/to/ProjectZomboid}"
[ -f "$PZ/java/projectzomboid.jar" ] || { echo "no $PZ/java/projectzomboid.jar"; exit 1; }
cp -v "$(dirname "$0")/zombie/network/"GameServer*.class "$PZ/java/zombie/network/"
echo "VisibleStaff classes installed into $PZ/java/zombie/network/"
echo "NOTE: the JVM must load this directory before the jar (classpath order)."
echo "Verify on next boot: log an admin in; the count must appear within ~15s."
