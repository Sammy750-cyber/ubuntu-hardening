set -u

REPORT="$HOME/ubuntu-hardening/reports/baseline-$(date +%Y%m%d-%H%M%S).txt"

{
    echo "======================================"
    echo "UBUNTU SERVER SECURITY BASELINE"
    echo "======================================"
    echo "Date: $(date)"
    echo

    echo "### SYSTEM"
    hostnamectl
    uname -a

    echo
    echo "### USERS"
    echo "--- UID 0 accounts ---"
    awk -F: '$3 == 0 {print $1}' /etc/passwd

    echo
    echo "--- Interactive users ---"
    grep -E '/(bash|sh|zsh)$' /etc/passwd || true

    echo
    echo "### SUDO"
    getent group sudo || true

    echo
    echo "### LISTENING PORTS"
    ss -lntup

    echo
    echo "### RUNNING SERVICES"
    systemctl --type=service --state=running

    echo
    echo "### FIREWALL"
    ufw status verbose || true

    echo
    echo "### SSH"
    systemctl is-active ssh || true
    sshd -T 2>/dev/null | grep -E \
        'permitrootlogin|passwordauthentication|pubkeyauthentication|permitemptypasswords|maxauthtries'

    echo
    echo "### APPARMOR"
    aa-status 2>/dev/null || true

    echo
    echo "### SUID BINARIES"
    find / -xdev -perm -4000 -type f 2>/dev/null

    echo
    echo "### SGID BINARIES"
    find / -xdev -perm -2000 -type f 2>/dev/null

} | tee "$REPORT"

echo
echo "Baseline saved to:"
echo "$REPORT"