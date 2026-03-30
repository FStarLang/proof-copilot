#!/usr/bin/env bash
# ── Shared helpers for benchmark evaluation ──────────────────────────
set -euo pipefail

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

BENCH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FSTAR_HOME="${FSTAR_HOME:-}"
FSTAR_EXE="${FSTAR_EXE:-${FSTAR_HOME:+$FSTAR_HOME/bin/fstar.exe}}"
KRML_EXE="${KRML_EXE:-${FSTAR_HOME:+$FSTAR_HOME/karamel/krml}}"
RESULTS_DIR="${RESULTS_DIR:-$BENCH_ROOT/_results}"

# ── Verification helpers ─────────────────────────────────────────────

# Check that fstar.exe is available
check_fstar() {
    if [ -z "$FSTAR_EXE" ] || [ ! -x "$FSTAR_EXE" ]; then
        echo -e "${RED}ERROR: fstar.exe not found. Set FSTAR_HOME or FSTAR_EXE.${NC}" >&2
        return 1
    fi
}

# Verify an F* file. Returns 0 on success.
# Usage: verify_fst file.fst [extra fstar flags...]
verify_fst() {
    check_fstar || return 1
    local file="$1"; shift
    "$FSTAR_EXE" "$@" "$file" 2>&1
}

# ── Deterministic checks ────────────────────────────────────────────

# Check that no admits exist in the file
# Returns 0 if clean, 1 if admits found
check_no_admits() {
    local file="$1"
    if grep -qE '\badmit\b|\badmit\(\)|\bassume\b|Tactics\.admit|admit_' "$file"; then
        echo -e "${RED}FAIL: Found admit/assume in $file${NC}"
        grep -nE '\badmit\b|\badmit\(\)|\bassume\b|Tactics\.admit|admit_' "$file"
        return 1
    fi
    echo -e "${GREEN}PASS: No admits/assumes in $file${NC}"
    return 0
}

# Check rlimit pragmas. Returns the max rlimit found.
# Usage: max_rlimit file.fst
max_rlimit() {
    local file="$1"
    local max=0
    while IFS= read -r val; do
        if (( val > max )); then max=$val; fi
    done < <(grep -oE 'z3rlimit[[:space:]]+[0-9]+' "$file" | grep -oE '[0-9]+$')
    echo "$max"
}

# Check that all rlimits are ≤ threshold
# Usage: check_rlimit file.fst [max_allowed]
check_rlimit() {
    local file="$1"
    local threshold="${2:-10}"
    local m
    m=$(max_rlimit "$file")
    if (( m > threshold )); then
        echo -e "${YELLOW}WARN: Max rlimit $m > $threshold in $file${NC}"
        return 1
    fi
    echo -e "${GREEN}PASS: rlimits ≤ $threshold in $file${NC}"
    return 0
}

# Count .fst/.fsti files in a directory
count_fstar_files() {
    find "$1" -name '*.fst' -o -name '*.fsti' | wc -l
}

# ── Scoring ──────────────────────────────────────────────────────────

# Write a score line to the results file
# Usage: record_score task_name criterion points max_points comment
record_score() {
    local task="$1" criterion="$2" points="$3" max="$4" comment="${5:-}"
    local results_file="$RESULTS_DIR/${task}.scores"
    mkdir -p "$RESULTS_DIR"
    echo "${criterion}|${points}|${max}|${comment}" >> "$results_file"
}

# Read total score from results file
total_score() {
    local task="$1"
    local results_file="$RESULTS_DIR/${task}.scores"
    if [ ! -f "$results_file" ]; then echo 0; return; fi
    awk -F'|' '{sum+=$2} END {print sum+0}' "$results_file"
}

# Read max possible score
max_score() {
    local task="$1"
    local results_file="$RESULTS_DIR/${task}.scores"
    if [ ! -f "$results_file" ]; then echo 0; return; fi
    awk -F'|' '{sum+=$3} END {print sum+0}' "$results_file"
}

# Print a summary table for a task
print_task_summary() {
    local task="$1"
    local results_file="$RESULTS_DIR/${task}.scores"
    if [ ! -f "$results_file" ]; then
        echo -e "${RED}No results for $task${NC}"
        return
    fi
    echo -e "${BOLD}── $task ──${NC}"
    printf "  %-20s %5s / %-5s  %s\n" "Criterion" "Score" "Max" "Notes"
    printf "  %-20s %5s   %-5s  %s\n" "────────────────────" "─────" "─────" "─────"
    while IFS='|' read -r criterion points max comment; do
        printf "  %-20s %5s / %-5s  %s\n" "$criterion" "$points" "$max" "$comment"
    done < "$results_file"
    local t m
    t=$(total_score "$task")
    m=$(max_score "$task")
    printf "  %-20s %5s / %-5s\n" "TOTAL" "$t" "$m"
    echo
}

# ── Judge integration ────────────────────────────────────────────────

# Prepare a prompt for the LLM judge and write it to a file.
# The caller sends it to copilot or another LLM.
# Usage: prepare_judge_prompt task_name task_md workspace_dir output_file
prepare_judge_prompt() {
    local task="$1" task_md="$2" workspace="$3" output="$4"
    local judge_system
    judge_system="$(cat "$BENCH_ROOT/lib/judge_prompt.md")"

    {
        echo "=== JUDGE SYSTEM PROMPT ==="
        echo "$judge_system"
        echo
        echo "=== TASK DESCRIPTION ==="
        cat "$task_md"
        echo
        echo "=== AGENT OUTPUT ==="
        # Concatenate all .fst/.fsti files from workspace
        find "$workspace" \( -name '*.fst' -o -name '*.fsti' -o -name 'Makefile' -o -name '*.c' -o -name '*.h' \) \
            -exec echo "--- {} ---" \; -exec cat {} \; 2>/dev/null || true
        echo
        echo "=== END ==="
    } > "$output"
}
