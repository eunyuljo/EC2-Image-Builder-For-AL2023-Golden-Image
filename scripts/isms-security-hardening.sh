#!/bin/bash
# ISMS Security Hardening Script for Amazon Linux 2023
set -e

echo "Starting ISMS security hardening..."

# System Updates
dnf update -y

# Install security tools
dnf install -y aide rkhunter chkrootkit fail2ban

# Disable unnecessary services
systemctl disable cups bluetooth 2>/dev/null || echo "Some services not found, skipping..."
systemctl stop cups bluetooth 2>/dev/null || echo "Some services not running, skipping..."

# SSH Hardening
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config
sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 300/' /etc/ssh/sshd_config
sed -i 's/#ClientAliveCountMax 3/ClientAliveCountMax 2/' /etc/ssh/sshd_config
echo 'Protocol 2' >> /etc/ssh/sshd_config

# Kernel Parameter Hardening
cat >> /etc/sysctl.conf << 'EOF'
# ISMS Security Hardening
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
kernel.dmesg_restrict = 1
EOF

# File Permission Hardening
chmod 700 /root
chmod 600 /etc/ssh/sshd_config
chmod 644 /etc/passwd
chmod 000 /etc/shadow
chmod 000 /etc/gshadow
chmod 644 /etc/group

# # Logging Configuration
# cat >> /etc/rsyslog.conf << 'EOF'
# # ISMS Logging Configuration
# auth,authpriv.*                 /var/log/auth.log
# *.info;mail.none;authpriv.none;cron.none    /var/log/messages
# EOF

# Account Security
sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS 90/' /etc/login.defs
sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS 7/' /etc/login.defs
sed -i 's/^PASS_MIN_LEN.*/PASS_MIN_LEN 8/' /etc/login.defs
sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE 7/' /etc/login.defs

# Remove unnecessary packages
dnf remove -y telnet rsh ypbind tftp xinetd 2>/dev/null || echo "Some packages not found, skipping..."

# Configure AIDE
aide --init
mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz

# CloudWatch Agent
dnf install -y amazon-cloudwatch-agent

# at 비활성화
sudo systemctl disable --now atd
chown root:root /etc/at.deny
chmod 600 /etc/at.deny

# pam_wheel.so 를 사용해서 wheel 그룹으로 제한
sed -i 's/^#\s*\(auth\s\+required\s\+pam_wheel.so\s\+use_uid\)/\1/' /etc/pam.d/su

# Set timezone
timedatectl set-timezone Asia/Seoul


# Security banner
cat > /etc/issue << 'EOF'
************************************************************************
*                          WARNING                                     *
*  이 시스템은 인가된 사용자만 접근할 수 있습니다.                      *
*  모든 활동은 모니터링되고 기록됩니다.                                *
*  무단 접근은 법적 처벌을 받을 수 있습니다.                           *
************************************************************************
EOF
cp /etc/issue /etc/issue.net
sed -i 's/#Banner none/Banner \/etc\/issue.net/' /etc/ssh/sshd_config


# complete
echo "ISMS security hardening completed successfully!"