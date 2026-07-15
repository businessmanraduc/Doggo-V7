#!/usr/bin/env bash
# ============================================================================
#  sweep.sh  --  N-seed nextpnr sweep -> floor/mean/ceil + per-seed census
#  args: MOD JSON LPF TOP SEEDS TW OUT [JOBS]
# ============================================================================
set -euo pipefail
mod=$1
json=$2
lpf=$3
top=$4
seeds=$5
tw=$6
out=$7
jobs=${8:-1}
logdir=$(dirname "$json")
res="$logdir/results.tsv"

echo "  sweeping $seeds seeds at tw=$tw, $jobs at a time"

seq 1 "$seeds" | xargs -P "$jobs" -I{} bash -c '
  s=$1; logdir=$2; json=$3; lpf=$4; tw=$5
  log="$logdir/s$s.log"
  nextpnr-ecp5 --85k --package CABGA381 --json "$json" --lpf "$lpf" \
    --seed "$s" --placer-heap-timingweight "$tw" --timing-allow-fail \
    --textcfg /dev/null >"$log" 2>&1 || true
  brief=$(python3 flow/critpath.py "$log" --brief 2>/dev/null || echo "  0.00 MHz  ? -> ?")
  printf "%s\t%s\n" "$s" "$brief"
' _ {} "$logdir" "$json" "$lpf" "$tw" >"$res"

sort -n -o "$res" "$res"

vals=()
census=()
while IFS=$'\t' read -r s brief; do
  vals+=("$(printf '%s' "$brief" | awk '{print $1}')")
  census+=("| $s | $brief |")
  printf '  seed %2d : %s\n' "$s" "$brief"
done <"$res"

sorted=$(printf '%s\n' "${vals[@]}" | sort -n)
floor=$(printf '%s' "$sorted" | head -1)
ceil=$(printf '%s' "$sorted" | tail -1)
mean=$(printf '%s\n' "${vals[@]}" | awk '{s+=$1} END{printf "%.2f", s/NR}')

{
  echo "# $mod solo Fmax"
  echo
  echo "ring-of-regs, nextpnr --85k CABGA381, tw=$tw, $seeds seeds"
  echo
  echo "| floor | mean | ceil |"
  echo "|---|---|---|"
  echo "| $floor | $mean | $ceil |"
  echo
  echo "## census (worst path per seed)"
  echo
  echo "| seed | fmax | start -> end |"
  echo "|---|---|---|"
  printf '%s\n' "${census[@]}" | sed -E 's/ MHz +/ | /'
} >"$out"

printf 'RESULT  floor %s / mean %s / ceil %s  ->  %s\n' "$floor" "$mean" "$ceil" "$out"
echo 'deep dive:  python3 flow/critpath.py '"$logdir"'/s<seed>.log'
