#!/bin/sh

function install {
	tools="vim git samba-client wget telnet nmap-ncat lrzsz unzip zip tcpdump traceroute ntp openssl"
	dev="gcc gcc-c++ gdb make cmake valgrind zlib-devel pcre-devel openssl-devel"
	system="man-pages"
	servers="samba sqlite"
	
	yum install -y ${tools} ${dev} ${system} ${servers} >/dev/null 2>&1
	printf "packages install complete.\n"
}

function net_config {
	files="/etc/sysconfig/network-scripts/ifcfg-*"
	sed -i 's/ONBOOT=no/ONBOOT=yes/' $files
	systemctl restart network
	printf "network init complete.\n"
}

function sys_config {
	file="/etc/profile"
	cmd="HISTSIZE=10000"
	sed -i "s/HISTSIZE=1000$/$cmd/g" $file
	if [ `cat ${file} | grep "HISTTIMEFORMAT=" | wc -l` -eq 0 ]; then
		sed -i "/^$cmd$/aHISTTIMEFORMAT=\"[%Y-%m-%d %H:%M:%S] \"" $file
	fi 

	if [ ! -d /root/.ssh ]; then
		ssh-keygen -b 2048 -t rsa -N "" -f "/root/.ssh/id_rsa"
	fi
	systemctl restart ntpd
	printf "system config complete.\n"
}

function vim_config {
	file="/etc/vimrc"
	cmd="set ts=4"
	if [ `cat ${file} | grep "$cmd" | wc -l` -eq 0 ]; then
		printf "$cmd\n" >> ${file}
	fi

	cmd="set nu"
	if [ `cat ${file} | grep "$cmd" | wc -l` -eq 0 ]; then
		printf "$cmd\n" >> ${file}
	fi

	cmd="set sw=4"
	if [ `cat ${file} | grep "$cmd" | wc -l` -eq 0 ]; then
		printf "$cmd\n" >> ${file}
	fi

	cmd="set pastetoggle=<F2>"
	if [ `cat ${file} | grep "$cmd" | wc -l` -eq 0 ]; then
		printf "$cmd\n" >> ${file}
	fi

	cmd="filetype indent on"
	if [ `cat ${file} | grep "$cmd" | wc -l` -eq 0 ]; then
		printf "$cmd\n" >> ${file}
	fi
	printf "vim config complete.\n"
}

function git_config {
	file="/root/.gitconfig"
	if [ ! -f $file ]; then
		touch $file
	fi
	if [ `cat $file | grep "#git configuration" | wc -l` -eq 0 ]; then
		printf "#git configuration\n[merge]\n\tsummary = true\n\ttool = vimdiff\n[diff]\n\trenames = copy\n[color]\n\tdiff = auto\n\tstatus = true\n\tbranch = auto\n\tinteractive = auto\n\tui = auto\n\tlog = true\n[status]\n\tsubmodulesummary = -1\n[format]\n\tnumbered = auto\n[alias]\n\tco = checkout\n\tci = commit\n\tst = status -uno --column\n\tdt = difftool\n\tl = log --pretty=\\\\\"%%C(yellow) %%<(9)%%h%%Creset %%<(30)%%ci %%<(16)%%cn %%s\\\\\"\n\tcp = cherry-pick\n\tca = commit -a\n\tb = branch\n\tro = remote\n[core]\n\twhitespace = cr-at-eol\n\tfileMode = false\n\tpager = less -x1,5\n[user]\n\tname = \n\temail = \n[push]\n\tdefault = current\n[http]\n\t#proxy=socks5://127.0.0.1:19022\n[recieve]\n\tdenyDeleteCurrent=ignore\n" >> $file
	fi

	bashfile="/root/.bashrc"
	rpm_git=`rpm -aq|grep ^git-[1-9]`
	git_complete=`rpm -ql $rpm_git | grep git-completion.bash`
	if [ -f $git_complete ]; then
		if [ `cat $bashfile | grep "#git completion" | wc -l` -eq 0 ]; then
			printf "#git completion\nif [ -f $git_complete ]; then\n\tsource $git_complete\nfi\n" >> $bashfile
		fi
	fi
	printf "git config complete.\n"
}

function samba_config {
	root=`pwd`
	file="/etc/samba/smb.conf"

	[ ! -d /root/codes ] && mkdir /root/codes
	if [ `cat ${file} | grep "\[codes\]" | wc -l` -eq 0 ]; then
		printf "\n[codes]\n\tcomment=codes\n\tpath=/root/codes\n\tpublic=no\n\twritable=yes\n\tvalid users=root\n" >> $file
	fi

	mkdir -p /usr/local/samba/include
	ver=`gcc --version|head -n1|awk '{print $3}'`
	cd /usr/local/samba/include
	printf "I:\\c++;I:\\c++-config;I:\\c++-backward;I:\\gcc;I:\\linux;I:\\local" > include.txt
	ln -sf /usr/include linux
	ln -sf /usr/lib/gcc/x86_64-redhat-linux/$ver/include gcc
	ln -sf /usr/local/include local
	ln -sf /usr/include/c++/$ver c++
	ln -sf /usr/include/c++/$ver/backward c++-backward
	ln -sf /usr/include/c++/$ver/x86_64-redhat-linux c++-config
	cd $root
	if [ `cat ${file} | grep "\[include\]" | wc -l` -eq 0 ]; then
		printf "\n[include]\n\tcomment=include files\n\tpath=/usr/local/samba/include\n\tpublic=no\n\twritable=no\n\tvalid users=root\n" >> $file
	fi

	if [ `cat ${file} | grep "wide links" | wc -l` -eq 0 ]; then
		sed -i 's/\[global\]/\[global\]\n\twide links=yes/g' $file
	fi
	if [ `cat ${file} | grep "unix extensions" | wc -l` -eq 0 ]; then
		sed -i 's/\[global\]/\[global\]\n\tunix extensions=no/g' $file
	fi

	printf "root\nroot\n" | smbpasswd -a root
	systemctl enable smb
	systemctl restart smb

	printf "samba config complete.\n"
}

function selinux_config {
	file="/etc/selinux/config"
	sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' $file
	setenforce 0
	printf "selinux config complete.\n"
}

function firewall_config {
	systemctl stop firewalld
	systemctl disable firewalld
	
	printf "firewall config complete.\n"
}

function install_nginx {
	url="http://nginx.org/download/nginx-1.12.2.tar.gz"
	tar="nginx-1.12.2.tar.gz"
	root=`pwd`
	nginx="$root/nginx_install"
	if [ ! -d $nginx ]; then
		mkdir $nginx
	fi
	cd $nginx

	if [ ! -f $tar ]; then
		wget $url
	fi

	dir="nginx-1.12.2"
	tar -zxf $tar
	cd $dir
	./configure --prefix=/usr/local/nginx
	make
	make install

	file="/usr/lib/systemd/system/nginx.service"
	if [ ! -f $file ]; then
		printf "[Unit]\nDescription=The NGINX HTTP and reverse proxy server\nAfter=syslog.target network.target remote-fs.target nss-lookup.target\n\n[Service]\nType=forking\nPIDFile=/usr/local/nginx/logs/nginx.pid\nExecStartPre=/usr/local/nginx/sbin/nginx -t\nExecStart=/usr/local/nginx/sbin/nginx\nExecReload=/usr/local/nginx/sbin/nginx -s reload\nExecStop=/bin/kill -s QUIT $MAINPID\nPrivateTmp=true\n\n[Install]\nWantedBy=multi-user.target" > $file
	fi
	cd $root

	systemctl enable nginx
	systemctl restart nginx
	printf "nginx install complete.\n"
}

install
vim_config
git_config
net_config
sys_config
samba_config
selinux_config
firewall_config
install_nginx
