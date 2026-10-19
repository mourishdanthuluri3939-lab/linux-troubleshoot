
# Linux Health Checker

A Bash-based Linux troubleshooting toolkit.

## Checks

- System hostname and uptime
- CPU count and load average
- Memory and swap information
- Disk space and inode usage
- Top processes by CPU
- Failed systemd services
- Recent system journal errors
- Network interface addresses

## Requirements

- Bash
- Linux system
- Standard Linux utilities
- systemd and journalctl for service and journal checks

Some checks may be skipped when utilities or permissions are unavailable.

## Usage

```bash
chmod +x linux-troubleshoot.sh
./linux-troubleshoot.sh
```


