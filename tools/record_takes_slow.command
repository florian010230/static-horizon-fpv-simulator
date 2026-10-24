#!/bin/bash
# Trailer takes in slow motion (the game runs at 0.6 speed; takes replay at full speed): plays the game from this project folder (the current
# code, not the installed release) and keeps EVERY flight as its own file
# in the game's user folder, trailer_takes/ (see scripts/take_recorder.gd).
# Your records and ghosts stay untouched; races in this session keep their
# own records in trailer_takes/race_saves/. Double-click in Finder, or run
#   tools/record_takes.command
cd "$(dirname "$0")/.."
/Applications/Godot.app/Contents/MacOS/Godot --path . --time-scale 0.6 -- --record-all
echo "Takes: $HOME/Library/Application Support/Godot/app_userdata/Static Horizon FPV Simulator/trailer_takes/"
