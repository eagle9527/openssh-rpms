#!/bin/bash
#set -e
#判断系统版本
OSVERSION="CentOS Linux release 7.9.2009 (Core)"
VERSION=`cat /etc/redhat-release`
if [ "$VERSION" != "$OSVERSION" ];then
    echo "------  $VERSION Version Mismatch $OSVERSION ------"
    exit 1
fi

#备份配置文件
cp /etc/pam.d/sshd /etc/pam.d/sshd.bak
cp -r /etc/ssh/       /etc/ssh-bak

#移除旧版本
yum remove openssh -y
if [ $? -ne 0 ]; then
    echo "------ openssh remove failed ------"
    exit 1
else
    echo "openssh remove succeed"
fi


#安装新版本 openssh
yum localinstall  ./el7/RPMS/*.rpm -y

if [ $? -ne 0 ]; then
    echo "------ upgradeSSH failed ------"
    exit 1
else
    echo "openssh install succeed"
fi


# 修改配置文件
sed -i 's/#UsePAM no/UsePAM yes/g' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin..*/PermitRootLogin yes/g' /etc/ssh/sshd_config

# 修改/etc/pam.d/sshd
cp  /etc/pam.d/sshd   /etc/pam.d/sshd-bak

cat << EOF > /etc/pam.d/sshd
#%PAM-1.0
auth       substack     password-auth
auth       include      postlogin
account    required     pam_sepermit.so
account    required     pam_nologin.so
account    include      password-auth
password   include      password-auth
# pam_selinux.so close should be the first session rule
session    required     pam_selinux.so close
session    required     pam_loginuid.so
# pam_selinux.so open should only be followed by sessions to be executed in the user context
session    required     pam_selinux.so open env_params
session    required     pam_namespace.so
session    optional     pam_keyinit.so force revoke
session    optional     pam_motd.so
session    include      password-auth
session    include      postlogin
EOF

chmod go-r /etc/ssh/*

systemctl restart sshd
if [ $? -ne 0 ]; then
    echo "------ upgradeSSH  restart failed ------"
    exit 1
else
    echo "\033[31m"------ upgradeSSH finished ------" \033[0m"
    ssh -V
fi
