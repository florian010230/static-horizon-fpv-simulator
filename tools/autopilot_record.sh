#!/bin/bash
# Films the trailer autopilot (scripts/autopilot.gd) with Godot's movie
# maker: 60 fps, fixed time step, into a NEW folder - never overwrites.
#   tools/autopilot_record.sh [--res=1920x1080] [autopilot args...]
#   e.g. tools/autopilot_record.sh --res=1280x720 --track=2 --laps=3 --seed=7 --skill=0.85
# Output: ../public/videos/autopilot-<date>-<time>/ (lap.avi = MJPEG + wav),
# plus run.txt with the exact command. Convert for upload:
#   ffmpeg -i lap.avi -c:v libx264 -crf 16 -pix_fmt yuv420p -c:a aac lap.mp4
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
echo "-> $OUT"
