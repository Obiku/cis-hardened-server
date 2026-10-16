#!/bin/bash
# Daily CIS compliance check: writes JSON evidence and uploads it to S3
set -uo pipefail

BUCKET="cis-evidence-575141563901"
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
RESULTS="[]"

# record: compare expected vs actual and add the result to the JSON list
# usage: record CHECK_ID CIS_ITEM ISO_CONTROL DESCRIPTION EXPECTED ACTUAL
record() {
  local result="FAIL"
  [ "$5" = "$6" ] && result="PASS"
  RESULTS=$(echo "$RESULTS" | jq -c \
    --arg id "$1" --arg cis "$2" --arg iso "$3" --arg desc "$4" \
    --arg exp "$5" --arg act "$6" --arg res "$result" \
    '. + [{check_id:$id, cis:$cis, iso27001:$iso, description:$desc, expected:$exp, actual:$act, result:$res}]')
    }


# Control 1: Root login
actual=$(grep -hi '^PermitRootLogin' /etc/ssh/sshd_config.d/*.conf 2>/dev/null | awk '{print $2}' | head -1)
record "CIS-01" "5.1 SSH: PermitRootLogin disabled" "A.8.2, A.8.5" "Root login over SSH is disabled" "no" "$actual"

actual=$(passwd -S root | awk '{print $2}')
record "CIS-02" "5.4 Root account: password locked" "A.8.2, A.8.5" "Root password is locked" "L" "$actual"

# Control 2: Unused services
for svc in ssh.socket ModemManager.service udisks2.service; do
  actual=$(systemctl is-enabled "$svc" 2>/dev/null)
  record "CIS-03-$svc" "2.x Services: unused service not in use" "A.8.9, A.8.20" "$svc is masked" "masked" "$actual"
done

# Control 3: Key file permissions
actual=$(stat -c "%a %U:%G" /etc/passwd)
record "CIS-04" "7.1 /etc/passwd permissions" "A.8.3, A.5.15" "/etc/passwd is 644 root:root" "644 root:root" "$actual"

actual=$(stat -c "%a %U:%G" /etc/shadow)
record "CIS-05" "7.1 /etc/shadow permissions" "A.8.3, A.5.15" "/etc/shadow is 640 root:shadow" "640 root:shadow" "$actual"

# Control 4: auditd
actual=$(systemctl is-active auditd 2>/dev/null)
record "CIS-06" "6.3 auditd enabled and active" "A.8.15" "auditd service is running" "active" "$actual"

actual=$(auditctl -l 2>/dev/null | grep -q -- '-k privileged' && echo present || echo missing)
record "CIS-07" "6.3 Privileged command use is collected" "A.8.15, A.8.2" "Audit rules for privileged commands loaded" "present" "$actual"

# Control 5: Automatic security updates
actual=$(apt-config dump APT::Periodic::Unattended-Upgrade | awk -F'"' '{print $2}')
record "CIS-08" "1.2 Automatic security updates" "A.8.8" "Unattended security upgrades enabled" "1" "$actual"

# Build the evidence document
PASSED=$(echo "$RESULTS" | jq '[.[] | select(.result=="PASS")] | length')
TOTAL=$(echo "$RESULTS" | jq 'length')
mkdir -p /var/log/cis-evidence
OUTFILE="/var/log/cis-evidence/cis-check-$(date -u +%Y%m%dT%H%M%SZ).json"

jq -n --arg host "$INSTANCE_ID" --arg ts "$TIMESTAMP" \
  --argjson passed "$PASSED" --argjson total "$TOTAL" --argjson checks "$RESULTS" \
  '{instance_id:$host, timestamp:$ts, benchmark:"CIS Ubuntu Linux 24.04 LTS", summary:{passed:$passed, total:$total}, checks:$checks}' > "$OUTFILE"
echo "Evidence written to $OUTFILE ($PASSED/$TOTAL passed)"

# Upload to the evidence bucket
export PATH="$PATH:/snap/bin"
S3KEY="evidence/$INSTANCE_ID/$(date -u +%Y/%m/%d)/$(basename "$OUTFILE")"
aws s3 cp "$OUTFILE" "s3://$BUCKET/$S3KEY" --only-show-errors && echo "Uploaded to s3://$BUCKET/$S3KEY"

