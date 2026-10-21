#!/bin/bash
# Films the trailer autopilot (scripts/autopilot.gd) with Godot's movie
# maker: 60 fps, fixed time step, into a NEW folder - never overwrites.
#   tools/autopilot_record.sh [--res=1920x1080] [autopilot args...]
#   e.g. tools/autopilot_record.sh --res=1280x720 --track=2 --laps=3 --seed=7 --skill=0.85
# Output: ../public/videos/autopilot-<date>-<time>/lap.mp4 (from the movie
# maker's MJPEG lap.avi, removed after converting) + run.txt with the command.
set -e
cd "$(dirname "$0")/.."
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
RES=1920x1080
ARGS=()
for a in "$@"; do
	case "$a" in
		--res=*) RES="${a#--res=}" ;;
		*) ARGS+=("$a") ;;
	esac
done
BASE="../public/videos/autopilot-$(date +%Y-%m-%d-%H%M%S)"
OUT="$BASE"
n=2
while [ -e "$OUT" ]; do OUT="$BASE-$n"; n=$((n + 1)); done
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
echo "$GODOT --path . --resolution $RES --fixed-fps 60 --write-movie $OUT/lap.avi -- --dev-preview autopilot ${ARGS[*]}" > "$OUT/run.txt"
"$GODOT" --path . --resolution "$RES" --fixed-fps 60 --write-movie "$OUT/lap.avi" -- --dev-preview autopilot "${ARGS[@]}" 2>&1 | grep -E "AUTOPILOT|ERROR" | tee -a "$OUT/run.txt"
# (The window, and so the movie, can come out smaller than --res - 1600x900
# on the dev Mac - so the mp4 is scaled to --res.)
# MJPEG is huge (~1.3 GB per 1080p lap): an mp4 next to it, and the avi
# from THIS run goes once the mp4 is there.
if command -v ffmpeg >/dev/null && [ -s "$OUT/lap.avi" ]; then
	ffmpeg -loglevel error -i "$OUT/lap.avi" -vf "scale=${RES/x/:}:flags=lanczos" -c:v libx264 -crf 18 -pix_fmt yuv420p -c:a aac "$OUT/lap.mp4" && [ -s "$OUT/lap.mp4" ] && rm "$OUT/lap.avi"
fi
echo "-> $OUT"
