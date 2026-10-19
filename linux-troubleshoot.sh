
#!/usr/bin/env bash
# Linux Health Checker
# Read-only diagnostic checks for Linux servers.

set -u
export LC_ALL=C

WARN_DISK=80
CRIT_DISK=90
WARN_MEM=80
CRIT_MEM=95
WARN_LOAD_PER_CPU=1.0

section() {
    printf '\n===== %s =====\n' "$1"
}

have() {
    command -v "$1" >/dev/null 2>&1
}

section "SYSTEM"
printf 'Hostname: '
hostname 2>/dev/null || echo "unknown"
printf 'Time: '
date
printf 'Uptime: '
uptime 2>/dev/null || echo "unavailable"

section "CPU AND LOAD"
if have nproc; then
    cpus=$(nproc)
else
    cpus=1
    echo "WARNING: nproc unavailable; assuming 1 CPU for load comparison"
fi

if [ -r /proc/loadavg ]; then
    read -r load1 load5 load15 _ < /proc/loadavg
    printf 'Load average (1, 5, 15 min): %s %s %s\n' \
        "$load1" "$load5" "$load15"
    awk -v l="$load1" -v c="$cpus" \
        -v w="$WARN_LOAD_PER_CPU" \
        'BEGIN {
            if (l > c*w)
                print "WARNING: 1-minute load exceeds configured per-CPU threshold"
            else
                print "OK: 1-minute load is within configured threshold"
        }'
else
    echo "WARNING: Linux load information unavailable"
fi

section "MEMORY"
if have free; then
    free -h
    mem_total=$(free -b | awk '/^Mem:/ {print $2}')
    mem_avail=$(free -b | awk '/^Mem:/ {print $7}')

    if [ -n "${mem_total:-}" ] &&
       [ -n "${mem_avail:-}" ] &&
       [ "$mem_total" -gt 0 ]; then
        mem_used_pct=$(( (mem_total - mem_avail) * 100 / mem_total ))
        printf 'Estimated memory pressure: %s%%\n' "$mem_used_pct"

        if [ "$mem_used_pct" -ge "$CRIT_MEM" ]; then
            echo "CRITICAL: available-memory estimate is very low"
        elif [ "$mem_used_pct" -ge "$WARN_MEM" ]; then
            echo "WARNING: available-memory estimate is low"
        else
            echo "OK: available-memory estimate is within configured thresholds"
        fi
    fi
else
    echo "WARNING: free command unavailable"
fi

section "DISK SPACE"
if have df; then
    df -hP
    df -P -x tmpfs -x devtmpfs | awk -v w="$WARN_DISK" -v c="$CRIT_DISK" '
        NR > 1 {
            usage=$5
            gsub(/%/, "", usage)
            if (usage ~ /^[0-9]+$/ && usage >= c)
                printf "CRITICAL: %s is %s full\n", $6, $5
            else if (usage ~ /^[0-9]+$/ && usage >= w)
                printf "WARNING: %s is %s full\n", $6, $5
        }'
else
    echo "WARNING: df command unavailable"
fi

section "INODES"
if have df; then
    df -iP 2>/dev/null || echo "WARNING: inode report unavailable"
fi

section "TOP PROCESSES"
if have ps; then
    ps aux --sort=-%cpu 2>/dev/null | head -n 6 ||
        ps aux | head -n 6
else
    echo "WARNING: ps command unavailable"
fi

section "FAILED SERVICES"
if have systemctl; then
    if systemctl --failed --no-legend --no-pager 2>/dev/null; then
        echo "Review any failed units listed above."
    else
        echo "WARNING: unable to query systemd; permissions or system type may differ"
    fi
else
    echo "INFO: systemctl unavailable; systemd check skipped"
fi

section "RECENT SYSTEM ERRORS"
if have journalctl; then
    journalctl -p err -n 20 --no-pager 2>/dev/null ||
        echo "WARNING: journal unavailable or access denied"
else
    echo "INFO: journalctl unavailable; journal check skipped"
fi

section "NETWORK"
if have ip; then
    ip -brief address 2>/dev/null || echo "WARNING: unable to list IP addresses"
else
    echo "INFO: ip command unavailable; network check skipped"
fi

section "SUMMARY"
echo "Health checks completed."
echo "Review warnings and critical findings; this script does not repair issues."

