#!/usr/bin/env bash

set -u

PASS=0
FAIL=0

pass() {
    echo "[PASS] $1"
    ((PASS+=1))
}

fail() {
    echo "[FAIL] $1"
    ((FAIL+=1))
}

check_command() {
    command -v "$1" >/dev/null 2>&1
}

echo "======================================"
echo "UBUNTU HARDENING VERIFICATION"
echo "======================================"

echo
echo "### SSH"

if sshd -T | grep -q '^permitrootlogin no$'; then
    pass "Root SSH login disabled"
else
    fail "Root SSH login enabled"
fi

if sshd -T | grep -q '^permitemptypasswords no$'; then
    pass "Empty passwords prohibited"
else
    fail "Empty password policy not confirmed"
fi

echo
echo "### FIREWALL"

if ufw status | grep -q "Status: active"; then
    pass "UFW enabled"
else
    fail "UFW disabled"
fi

echo
echo "### APPARMOR"

if check_command aa-status; then
    if aa-status >/dev/null 2>&1; then
        pass "AppArmor available"
    else
        fail "AppArmor check failed"
    fi
else
    fail "AppArmor tools unavailable"
fi

echo
echo "### SERVICES"

if systemctl is-active --quiet ssh; then
    pass "SSH service active"
else
    fail "SSH service inactive"
fi

echo
echo "======================================"
echo "RESULT"
echo "======================================"

echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi

exit 0
