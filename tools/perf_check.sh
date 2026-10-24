#!/bin/bash
# FPS / draw-call check against a saved baseline (needs a real display,
# the window visible and the screen unlocked; ~10 min for all maps).
#   tools/perf_check.sh [project dir] [map ids...]      compare
#   PERF_BASELINE=1 tools/perf_check.sh [project dir]   write a new baseline
# Runs `--dev-preview perf <map>` per map (Low/Medium/High at spawn).
# FAIL when a map's FPS drops more than 5 % or its draw calls rise more
# than 5 % against tools/perf_baseline.txt; a failing map is measured
# once more before it counts (fps varies a few % run to run).
# Run it on a project copy with its own settings (the perf tool switches
# graphics quality while it runs).
HERE="$(cd "$(dirname "$0")/.." && pwd)"
PROJ="${1:-$HERE}"; shift
BASE="$HERE/tools/perf_baseline.txt"
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
MAPS="${*:-mountain_lake steelmill harbour construction village factory race_field race_arena office garage playground school}"
measure() { (cd "$PROJ" && "$GODOT" --path . -- --dev-preview perf "$1" 2>&1 | grep "^PERFROW"); }
# "PERFROW id ... | Low fps=34 draws=366 ..." -> "id Low 34 366" lines
parse() { python3 -I -c '
import re,sys
for l in sys.stdin:
    p=l.split("|"); mid=p[0].split()[1]
    for q in p[1:]:
        m=re.search(r"(\w+) fps=(\d+) draws=(\d+)",q)
        if m: print(mid,m.group(1),m.group(2),m.group(3))'; }
if [ -n "$PERF_BASELINE" ]; then
  : > "$BASE.new"
  for m in $MAPS; do measure "$m" | parse >> "$BASE.new"; done
  mv "$BASE.new" "$BASE"; echo "baseline written: $BASE"; cat "$BASE"; exit 0
fi
[ -f "$BASE" ] || { echo "no baseline - run with PERF_BASELINE=1 first"; exit 2; }
check() { # stdin: measured lines -> prints FAIL lines
  python3 -I -c '
import sys
base={}
for l in open(sys.argv[1]):
    m,q,f,d=l.split(); base[(m,q)]=(int(f),int(d))
for l in sys.stdin:
    m,q,f,d=l.split(); f=int(f); d=int(d)
    if (m,q) not in base: print("NEW",m,q,"fps",f,"draws",d); continue
    bf,bd=base[(m,q)]
    bad=[]
    if f < bf*0.95: bad.append("fps %d -> %d (%+.0f%%)"%(bf,f,100.0*(f-bf)/bf))
    if d > bd*1.05: bad.append("draws %d -> %d"%(bd,d))
    print(("FAIL " if bad else "ok   ")+m+" "+q+" fps %d (base %d) draws %d (base %d) "%(f,bf,d,bd)+"; ".join(bad))' "$BASE"; }
FAILS=0
for m in $MAPS; do
  out=$(measure "$m" | parse | check)
  if echo "$out" | grep -q "^FAIL"; then
    out=$(measure "$m" | parse | check) # once more before it counts
  fi
  echo "$out"
  echo "$out" | grep -q "^FAIL" && FAILS=$((FAILS+1))
done
echo "PERF CHECK DONE: $FAILS map(s) failed"
[ "$FAILS" -eq 0 ]
