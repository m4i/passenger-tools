#!/bin/bash
#
# dependency: bash, sed, awk, perl

set -eu

function usage() {
  cat <<'EOF' >&2
Usage: passenger-monitor [options]
        --memory-limit MB
        --max-requests COUNT
        --timestamp
EOF
  exit 1
}

memory_limit=0
max_requests=0
timestamp=0

function parse_arguments() {
  while (($# > 0)); do
    case "$1" in
      --memory-limit) memory_limit="$2"; shift;;
      --max-requests) max_requests="$2"; shift;;
      --timestamp)    timestamp=1;;
      *)              usage;;
    esac
    shift
  done
}

function main() {
  local status
  status="$(passenger-status)"

  script='(s/^  \* PID: (\d+) *Sessions: (\d+) *Processed: (\d+).*\n/$1 $2 $3/'
  script=$script' || s/^    CPU: (\d+)% *Memory  : (\d+)M.*$/ $1 $2/) && print'
  local processes
  processes="$(echo "$status" | perl -ne "$script")"

  log_processes "$status" "$processes"
  detach_processes "$processes"
}

function log_processes() {
  local status="$1"
  local processes="$2"

  local processes_json=
  local session_count=0
  while read pid sessions processed cpu memory; do
    if [[ -z "$pid" ]]; then continue; fi
    if [[ -n "$processes_json" ]]; then processes_json="$processes_json,"; fi
    processes_json="$processes_json{\"pid\":$pid"
    processes_json="$processes_json,\"sessions\":$sessions"
    processes_json="$processes_json,\"processed\":$processed"
    processes_json="$processes_json,\"cpu\":$cpu"
    processes_json="$processes_json,\"memory\":$memory"
    processes_json="$processes_json}"
    session_count=$((session_count + sessions))
  done < <(echo "$processes")

  local max=$(echo "$status" | sed -n 's/^Max pool size : //p')
  local process_count=$(echo "$status" | sed -n 's/^Processes     : //p')

  local top_queue=$(echo "$status" | sed -n 's/^Requests in top-level queue : //p')
  local group_queue=$(echo "$status" | awk '/Requests in queue:/ { sum += $4 } END { print sum }')
  local queue_size=$((session_count + top_queue + group_queue - max))
  if ((queue_size < 0)); then queue_size=0; fi

  local json='{"type":"passenger-status"'
  json="$json,\"max\":$max"
  json="$json,\"process_count\":$process_count"
  json="$json,\"sessions\":$session_count"
  json="$json,\"queue_size\":$queue_size"
  json="$json,\"processes\":[$processes_json]"
  json="$json}"

  log "$json"
}

function detach_processes() {
  local processes="$1"

  if ((memory_limit == 0)) && ((max_requests == 0)); then return; fi

  while read pid sessions processed cpu memory; do
    if [[ -z "$pid" ]]; then continue; fi

    if ((memory_limit)) && ((memory > memory_limit)) || \
       ((max_requests)) && ((processed > max_requests)); then
      local json='{"type":"passenger-detach"'
      json="$json,\"pid\":$pid"
      json="$json,\"sessions\":$sessions"
      json="$json,\"processed\":$processed"
      json="$json,\"cpu\":$cpu"
      json="$json,\"memory\":$memory"
      json="$json}"

      log "$json"
      run passenger-config detach-process $pid
    fi
  done < <(echo "$processes")
}

function run() {
  log "+ $*"
  "$@"
}

function log() {
  local message="$*"
  if ((timestamp)); then message="$(date -Is) $message"; fi
  echo "$message"
}

parse_arguments "$@"
main
