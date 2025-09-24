#!/bin/bash
# ISMS Security Hardening Script for Amazon Linux 2023
set -e

echo "Starting ISMS security hardening..."

# System Updates
dnf update -y

# Install security tools
dnf install -y aide rkhunter chkrootkit fail2ban


# Remove unnecessary packages
dnf remove -y telnet rsh ypbind tftp xinetd 2>/dev/null || echo "Some packages not found, skipping..."

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


# U-02 - /etc/security/pwdquality 
cp /etc/security/pwquality.conf /etc/security/pwquality.conf.bak
echo -e "minlen = 9\ndcredit = -1\nucredit = -1\nlcredit = -1\nocredit = -1" | sudo tee /etc/security/pwquality.conf

# U-13 - SUID, SGID, Sticky bit
sudo chmod 750 /sbin/unix_chkpwd /usr/bin/newgrp /usr/bin/at
# at 비활성화
sudo systemctl disable --now atd
chown root:root /etc/at.deny
chmod 600 /etc/at.deny


# U-46 - Account Security
sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS 90/' /etc/login.defs
sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS 1/' /etc/login.defs
sed -i 's/^PASS_MIN_LEN.*/PASS_MIN_LEN 8/' /etc/login.defs
sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE 7/' /etc/login.defs


# Configure AIDE
aide --init
mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz

# CloudWatch Agent
dnf install -y amazon-cloudwatch-agent

# U-45 - pam_wheel.so 를 사용해서 wheel 그룹으로 제한
sed -i 's/^#\s*\(auth\s\+required\s\+pam_wheel.so\s\+use_uid\)/\1/' /etc/pam.d/su

# Set timezone
timedatectl set-timezone Asia/Seoul

# U-54 - timeout 설정
echo "export TMOUT=600" | sudo tee -a /etc/profile

# U-68 - Security banner
cat > /etc/issue << 'EOF'
*******************************************************************************
*                             SECURITY NOTICE                                 *
*                                                                             *
*  This system is for the use of authorized users only.                       *
*  Unauthorized access or use is strictly prohibited and may be prosecuted    *
*  under applicable laws.                                                     *
*                                                                             *
*  All activities on this system are monitored and recorded.                  *
*  By accessing this system, you consent to such monitoring.                  *
*                                                                             *
*  Disconnect immediately if you are not an authorized user.                  *
*                                                                             *
*******************************************************************************
EOF

cp /etc/issue /etc/issue.net
sed -i 's/#Banner none/Banner \/etc\/issue.net/' /etc/ssh/sshd_config


# 백업 생성
cp /etc/pam.d/system-auth /etc/pam.d/system-auth.backup.$(date +%Y%m%d_%H%M%S)
cp /etc/pam.d/password-auth /etc/pam.d/password-auth.backup.$(date +%Y%m%d_%H%M%S)

# system-auth 새 설정 생성
cat > /etc/pam.d/system-auth << 'EOF'
#%PAM-1.0
auth        required      pam_env.so
auth        required      pam_faillock.so preauth silent audit deny=10
auth        sufficient    pam_unix.so try_first_pass nullok
auth        [default=die] pam_faillock.so authfail audit deny=10
auth        required      pam_deny.so

account     required      pam_faillock.so
account     required      pam_unix.so

password    requisite     pam_pwquality.so try_first_pass local_users_only retry=3 authtok_type=
password    sufficient    pam_unix.so try_first_pass use_authtok nullok sha512 shadow
password    required      pam_deny.so

session     optional      pam_keyinit.so revoke
session     required      pam_limits.so
-session     optional      pam_systemd.so
session     [success=1 default=ignore] pam_succeed_if.so service in crond quiet use_uid
session     required      pam_unix.so
EOF

# password-auth 새 설정 생성
cat > /etc/pam.d/password-auth << 'EOF'
#%PAM-1.0
auth        required      pam_env.so
auth        required      pam_faillock.so preauth silent audit deny=10
auth        sufficient    pam_unix.so try_first_pass nullok
auth        [default=die] pam_faillock.so authfail audit deny=10
auth        required      pam_deny.so

account     required      pam_faillock.so
account     required      pam_unix.so

password    requisite     pam_pwquality.so try_first_pass local_users_only retry=3 authtok_type=
password    sufficient    pam_unix.so try_first_pass use_authtok nullok sha512 shadow
password    required      pam_deny.so

session     optional      pam_keyinit.so revoke
session     required      pam_limits.so
-session     optional      pam_systemd.so
session     [success=1 default=ignore] pam_succeed_if.so service in crond quiet use_uid
session     required      pam_unix.so
EOF

echo "PAM configuration files have been updated with faillock settings."

# 권한 설정
chmod 644 /etc/pam.d/system-auth
chmod 644 /etc/pam.d/password-auth

# 설정 검증
echo "Verifying configuration..."
echo "=== system-auth structure ==="
grep -E "^(auth|account|password|session)" /etc/pam.d/system-auth

echo "=== password-auth structure ==="
grep -E "^(auth|account|password|session)" /etc/pam.d/password-auth








# complete
echo "ISMS security hardening completed successfully!"