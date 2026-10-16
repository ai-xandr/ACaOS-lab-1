#!/usr/bin/env bash

set -euo pipefail


usage() {
    echo "Incorrect usage; Gotta be: $0 <log_dir> <threshold_percent> <backup_dir>"
    exit 1
}

error() {
    echo "Error: $*" >&2
    exit 1
}

(( $# == 3 )) || usage

LOG_DIR="$1"
THRESHOLD="$2"
BACKUP_DIR="$3"

[[ -d "$LOG_DIR" ]] || error "log directory does not exist: $LOG_DIR"

(( THRESHOLD == THRESHOLD + 0 )) 2>/dev/null || error "threshold must be an integer from 0 to 100"

(( THRESHOLD >= 0 && THRESHOLD <= 100 )) || error "threshold must be between 0 and 100"

mkdir -p "$BACKUP_DIR"

COMPRESSION="gzip"
ARCHIVE_SUFFIX="tar.gz"
TAR_COMPRESSION_OPTION="--gzip"

if [[ "${LAB1_MAX_COMPRESSION:-0}" == "1" ]]; then
    COMPRESSION="lzma"
    ARCHIVE_SUFFIX="tar.lzma"
    TAR_COMPRESSION_OPTION="--lzma"
fi
    
{ read -r _; read -r _ TOTAL_KB _; } < <(df -P -k "$LOG_DIR")

read -r DIR_USED_KB _ < <(du -s -k "$LOG_DIR")

[[ -n "$TOTAL_KB" ]] || error "failed to get directory size"

USED_PERCENT=$(( USED_KB * 10000 / TOTAL_KB ))

USED_PERCENT_INT=$(( USED_PERCENT / 100 ))
USED_PERCENT_FRAC=$(( USED_PERCENT % 100 ))

echo "Directory : $LOG_DIR"
echo "Usage     : ${USED_PERCENT_INT}.${USED_PERCENT_FRAC}%"
echo "Threshold : ${THRESHOLD}%"
echo "Mode      : $COMPRESSION"


if (( USED_PERCENT <= THRESHOLD * 100 )); then
    echo "${USED_PERCENT_INT}.${USED_PERCENT_FRAC}% <= ${THRESHOLD}%; hence nothing to archive."
    exit 0
fi

echo "Threshold exceeded. Selecting oldest files..."


TARGET_USED_KB=$(( TOTAL_KB * THRESHOLD / 100 ))
NEEDED_FREE_KB=$(( USED_KB - TARGET_USED_KB ))