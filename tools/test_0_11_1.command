#!/bin/bash
# 0.11.1 test: plays the game from this project folder (the current,
# uncommitted code, not the installed 0.11.0) with your own settings,
# records and saves. Every frame longer than 150 ms is written to
#   previews/hitch_log_<date>.txt
# (with the map and the time) so Mountain Lake hitches can be looked at.
# Double-click in Finder, or run   tools/test_0_11_1.command
# Note: settings you change here are saved as usual; the installed 0.11.0
# reads the same settings file.
cd "$(dirname "$0")/.."
LOG="previews/hitch_log_$(date +%Y-%m-%d_%H-%M).txt"
SH_HITCH=150 /Applications/Godot.app/Contents/MacOS/Godot --path . 2>&1 | tee "$LOG"
echo "Log: $LOG"
