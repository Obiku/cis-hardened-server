#!/bin/bash
set -euo pipefail
exec > >(tee -a /var/log/cis-hardening.log) 2>&1

echo "=== CIS hardening started: $(date) ==="

# Control 1: Disable root login
echo "[1] Disabling root login"
passwd -l root
echo "PermitRootLogin no" > /etc/ssh/sshd_config.d/99-cis-hardening.conf

# Control 2: Disable unused services
echo "[2] Disabling unused services"
systemctl disable --now ssh.socket ssh.service ModemManager.service udisks2.service || true
systemctl mask ssh.socket ssh.service ModemManager.service udisks2.service

# Control 3: Permissions on key files
echo "[3] Setting permissions on passwd, shadow, group, gshadow"
chown root:root /etc/passwd /etc/group
chmod 644 /etc/passwd /etc/group
chown root:shadow /etc/shadow /etc/gshadow
chmod 640 /etc/shadow /etc/gshadow

# Control 4: auditd for privileged commands and identity changes
echo "[4] Installing and configuring auditd"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y auditd

cat > /etc/audit/rules.d/50-cis-identity.rules <<'EOF'
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d -p wa -k scope
EOF

find / -xdev -perm /6000 -type f 2>/dev/null | awk '{print "-a always,exit -F path=" $1 " -F perm=x -k privileged"}' > /etc/audit/rules.d/51-cis-privileged.rules || true

systemctl enable --now auditd
augenrules --load

# Control 5: Automatic security updates
echo "[5] Enabling automatic security updates"
apt-get install -y unattended-upgrades
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
systemctl enable --now unattended-upgrades

echo "=== CIS hardening finished: $(date) ==="

