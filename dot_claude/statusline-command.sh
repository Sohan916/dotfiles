#!/bin/sh
# Claude Code statusLine script
# Mirrors the built-in "model · context bar · rate limits" footer style.

input=$(cat)

model=$(printf '%s' "$input" | jq -r '.model.display_name // "Claude"')
effort=$(printf '%s' "$input" | jq -r '.effort.level // empty')

used=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')
in_tokens=$(printf '%s' "$input" | jq -r '.context_window.total_input_tokens // empty')
ctx_size=$(printf '%s' "$input" | jq -r '.context_window.context_window_size // empty')

five=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Format a raw token count like 212345 -> "212k", 1048576 -> "1.0M"
fmt_tokens() {
  n=$1
  [ -z "$n" ] && return
  awk -v n="$n" 'BEGIN {
    if (n >= 1000000) printf "%.1fM", n/1000000
    else if (n >= 1000) printf "%dk", int(n/1000)
    else printf "%d", n
  }'
}

# Build a thin, pill-style progress bar for used_percentage (0-100).
# Approximates a smooth rounded bar using a light box-drawing line for
# the empty track (dimmed) and a heavier, bolder line segment in color
# for the filled portion, so it reads as a slim solid segment on a
# track rather than blocky cells (rounds up so any non-zero usage
# shows at least one filled unit). Sets BAR_FILLED / BAR_EMPTY globals
# rather than returning a single string, since sh has no clean way to
# return a pair.
build_bar() {
  pct=$1
  len=10
  [ -z "$pct" ] && pct=0
  pct_i=$(printf '%.0f' "$pct" 2>/dev/null || echo 0)
  filled=$(( (pct_i * len + 99) / 100 ))
  [ "$filled" -lt 0 ] && filled=0
  [ "$filled" -gt "$len" ] && filled=$len
  empty=$(( len - filled ))
  BAR_FILLED=""
  i=0
  while [ "$i" -lt "$filled" ]; do BAR_FILLED="${BAR_FILLED}\xe2\x94\x81"; i=$((i+1)); done
  BAR_EMPTY=""
  i=0
  while [ "$i" -lt "$empty" ]; do BAR_EMPTY="${BAR_EMPTY}\xe2\x94\x80"; i=$((i+1)); done
}

DIM='\033[2m'
BOLD='\033[1m'
GREEN='\033[32m'
YELLOW='\033[33m'
RESET='\033[0m'

line="${BOLD}${model}${RESET}"
[ -n "$effort" ] && line="${line} ${DIM}${effort}${RESET}"

if [ -n "$used" ]; then
  build_bar "$used"
  used_i=$(printf '%.0f' "$used" 2>/dev/null || echo "$used")

  # Color the bar green/yellow/red depending on how full it is; the
  # empty portion is always dimmed so it reads as "unused" space.
  if [ "$used_i" -ge 90 ] 2>/dev/null; then
    bar_color="\033[31m"
  elif [ "$used_i" -ge 70 ] 2>/dev/null; then
    bar_color="${YELLOW}"
  else
    bar_color="${GREEN}"
  fi

  line="${line} ${bar_color}${BAR_FILLED}${RESET}${DIM}${BAR_EMPTY}${RESET}"
  line="${line} ${DIM}${used_i}%"
  if [ -n "$in_tokens" ] && [ -n "$ctx_size" ]; then
    line="${line} $(fmt_tokens "$in_tokens")/$(fmt_tokens "$ctx_size")"
  fi
  line="${line}${RESET}"
fi

if [ -n "$five" ]; then
  line="${line} ${DIM}\xc2\xb7${RESET} 5h ${YELLOW}$(printf '%.0f' "$five")%${RESET}"
fi
if [ -n "$week" ]; then
  line="${line} ${DIM}\xc2\xb7${RESET} 7d ${YELLOW}$(printf '%.0f' "$week")%${RESET}"
fi

printf '%b\n' "$line"
