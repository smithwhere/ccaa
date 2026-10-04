#!/bin/bash
#####	一键安装File Browser + Aria2 + AriaNg		#####
#####	作者：xiaoz.me						#####
#####	更新时间：2020-02-27				#####

#导入环境变量
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin:/sbin
export PATH

#CDN域名设置
if [ $1 = 'cdn' ]
	then
	aria2_url='http://soft.xiaoz.top/linux/aria2-1.37.0-linux-gnu-64bit-build1.tar.bz2'
	filebrowser_url='http://soft.xiaoz.top/linux/linux-amd64-filebrowser.tar.gz'
	master_url='https://github.com/smithwhere/ccaa/archive/refs/heads/master.zip'
	ccaa_web_url='http://soft.xiaoz.top/linux/ccaa_web.tar.gz'
	else
	aria2_url='https://github.com/dmesg00/aria2-static-builds/releases/download/v1.37.0/aria2-1.37.0-linux-gnu-64bit-build1.tar.bz2'
	filebrowser_url='https://github.com/filebrowser/filebrowser/releases/download/v2.0.16/linux-amd64-filebrowser.tar.gz'
	master_url='https://github.com/smithwhere/ccaa/archive/refs/heads/master.zip'
	ccaa_web_url='http://soft.xiaoz.org/linux/ccaa_web.tar.gz'
fi

#安装前的检查
function check(){
	echo '-------------------------------------------------------------'
	if [ -e "/etc/ccaa" ]
        then
        echo 'CCAA已经安装，若需要重新安装，请先卸载再安装！'
        echo '-------------------------------------------------------------'
        exit
	else
	        echo '检测通过，即将开始安装。'
	        echo '-------------------------------------------------------------'
	fi
}

#安装之前的准备
function setout(){
	if [ -e "/usr/bin/yum" ]
	then
		yum -y install curl gcc make bzip2 gzip wget unzip tar python3
	else
		#更新软件，否则可能make命令无法安装
		sudo apt-get update
		sudo apt-get install -y curl make bzip2 gzip wget unzip sudo python3
	fi
	#创建临时目录
	cd
	mkdir -p ./ccaa_tmp
	#创建用户和用户组（允许在安装中断后重试）
	getent group ccaa >/dev/null 2>&1 || groupadd ccaa
	if ! id -u ccaa >/dev/null 2>&1; then
		useradd -M -g ccaa ccaa -s /sbin/nologin
	fi
}
#安装Aria2
function install_aria2(){
	#优先安装静态编译版本，下载或编译失败时回退到系统软件包。
	cd "$HOME/ccaa_tmp" || return 1
	if wget -c "${aria2_url}" && \
		tar -xjf aria2-1.37.0-linux-gnu-64bit-build1.tar.bz2 && \
		(cd aria2-1.37.0-linux-gnu-64bit-build1 && make install); then
		:
	else
		echo '静态版 aria2 安装失败，尝试使用系统软件包。'
	fi

	if ! command -v aria2c >/dev/null 2>&1; then
		if command -v apt-get >/dev/null 2>&1; then
			apt-get update && apt-get install --reinstall -y aria2 || return 1
		elif command -v dnf >/dev/null 2>&1; then
			dnf reinstall -y aria2 || dnf install -y aria2 || return 1
		elif command -v yum >/dev/null 2>&1; then
			yum reinstall -y aria2 || yum install -y aria2 || return 1
		else
			echo '找不到支持的软件包管理器，无法安装 aria2。' >&2
			return 1
		fi
	fi

	if ! command -v aria2c >/dev/null 2>&1; then
		echo 'aria2 安装后仍无法找到 aria2c，停止安装。' >&2
		return 1
	fi
	cd "$HOME"
}

#安装File Browser文件管理器
function install_file_browser(){
	cd ./ccaa_tmp
	#下载File Browser
	wget ${filebrowser_url}
	#解压
	tar -zxvf linux-amd64-filebrowser.tar.gz
	#移动位置
	mv filebrowser /usr/sbin
	cd
}
#处理配置文件
function dealconf(){
	cd ./ccaa_tmp
	#下载CCAA项目
	wget ${master_url}
	#解压
	unzip master.zip
	#复制CCAA核心目录
	mv ccaa-master/ccaa_dir /etc/ccaa
	#创建aria2日志文件
	touch /var/log/aria2.log
	#upbt增加执行权限
	chmod +x /etc/ccaa/upbt.sh
	chmod +x ccaa-master/ccaa
	cp ccaa-master/ccaa /usr/sbin
	install -m 755 ccaa-master/ccaa_delete_api.py /usr/sbin/ccaa_delete_api.py
	cd
}
#自动放行端口
function chk_firewall(){
	if [ -e "/etc/sysconfig/iptables" ]
	then
		iptables -I INPUT -p tcp --dport 6080 -j ACCEPT
		iptables -I INPUT -p tcp --dport 6081 -j ACCEPT
		iptables -I INPUT -p tcp --dport 6082 -j ACCEPT
		iptables -I INPUT -p tcp --dport 6800 -j ACCEPT
		iptables -I INPUT -p tcp --dport 6998 -j ACCEPT
		iptables -I INPUT -p tcp --dport 51413 -j ACCEPT
		service iptables save
		service iptables restart
	elif [ -e "/etc/firewalld/zones/public.xml" ]
	then
		firewall-cmd --zone=public --add-port=6080/tcp --permanent
		firewall-cmd --zone=public --add-port=6081/tcp --permanent
		firewall-cmd --zone=public --add-port=6082/tcp --permanent
		firewall-cmd --zone=public --add-port=6800/tcp --permanent
		firewall-cmd --zone=public --add-port=6998/tcp --permanent
		firewall-cmd --zone=public --add-port=51413/tcp --permanent
		firewall-cmd --reload
	elif [ -e "/etc/ufw/before.rules" ]
	then
		sudo ufw allow 6080/tcp
		sudo ufw allow 6081/tcp
		sudo ufw allow 6082/tcp
		sudo ufw allow 6800/tcp
		sudo ufw allow 6998/tcp
		sudo ufw allow 51413/tcp
	fi
}
#删除端口
function del_post() {
	if [ -e "/etc/sysconfig/iptables" ]
	then
		sed -i '/^.*6080.*/'d /etc/sysconfig/iptables
		sed -i '/^.*6081.*/'d /etc/sysconfig/iptables
		sed -i '/^.*6082.*/'d /etc/sysconfig/iptables
		sed -i '/^.*6800.*/'d /etc/sysconfig/iptables
		sed -i '/^.*6998.*/'d /etc/sysconfig/iptables
		sed -i '/^.*51413.*/'d /etc/sysconfig/iptables
		service iptables save
		service iptables restart
	elif [ -e "/etc/firewalld/zones/public.xml" ]
	then
		firewall-cmd --zone=public --remove-port=6080/tcp --permanent
		firewall-cmd --zone=public --remove-port=6081/tcp --permanent
		firewall-cmd --zone=public --remove-port=6082/tcp --permanent
		firewall-cmd --zone=public --remove-port=6800/tcp --permanent
		firewall-cmd --zone=public --remove-port=6998/tcp --permanent
		firewall-cmd --zone=public --remove-port=51413/tcp --permanent
		firewall-cmd --reload
	elif [ -e "/etc/ufw/before.rules" ]
	then
		sudo ufw delete 6080/tcp
		sudo ufw delete 6081/tcp
		sudo ufw delete 6082/tcp
		sudo ufw delete 6800/tcp
		sudo ufw delete 6998/tcp
		sudo ufw delete 51413/tcp
	fi
}
#添加服务
function add_service() {
	if [ -d "/etc/systemd/system" ]
	then
		cp /etc/ccaa/services/* /etc/systemd/system
		systemctl daemon-reload
		systemctl enable aria2.service ccaa_web.service filebrowser.service ccaa_delete_api.service
	fi
}
#设置账号密码
function setting(){
	cd
	cd ./ccaa_tmp
	echo '-------------------------------------------------------------'
	read -p "设置下载路径（请填写绝对地址，默认/data/ccaaDown）:" downpath
	#自动生成10位Aria2 RPC密钥（仅数字和大小写字母）
	secret=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 10)
	if [ "${#secret}" -ne 10 ]; then
		echo '生成 Aria2 RPC 密钥失败。' >&2
		return 1
	fi
	
	#如果下载路径为空，设置默认下载路径
	if [ -z "${downpath}" ]
	then
		downpath='/data/ccaaDown'
	fi

	#获取ip
	osip=$(curl ipv4.ip.sb)
	secret_b64=$(printf '%s' "${secret}" | base64 | tr '+/' '-_' | tr -d '=')
	ariang_rpc_url="http://${osip}:6080/#!/settings/rpc/set?protocol=http&host=${osip}&port=6800&interface=jsonrpc&secret=${secret_b64}"
	
	#执行替换操作
	mkdir -p ${downpath}
	sed -i "s%dir=%dir=${downpath}%g" /etc/ccaa/aria2.conf
	sed -i "s/^rpc-secret=.*/rpc-secret=${secret}/" /etc/ccaa/aria2.conf
	#替换filebrowser读取路径
	sed -i "s%ccaaDown%${downpath}%g" /etc/ccaa/config.json
	#替换AriaNg服务器链接
	sed -i "s/server_ip/${osip}/g" /etc/ccaa/AriaNg/index.html
	
	#更新tracker
	bash /etc/ccaa/upbt.sh
	
	#安装AriaNg
	wget ${ccaa_web_url}
	tar -zxvf ccaa_web.tar.gz
	cp ccaa_web /usr/sbin/
	chmod +x /usr/sbin/ccaa_web

	#启动服务
	nohup sudo -u ccaa aria2c --conf-path=/etc/ccaa/aria2.conf > /var/log/aria2.log 2>&1 &
	#nohup caddy -conf="/etc/ccaa/caddy.conf" > /etc/ccaa/caddy.log 2>&1 &
	nohup sudo -u ccaa /usr/sbin/ccaa_web > /var/log/ccaa_web.log 2>&1 &
	#运行filebrowser
	nohup sudo -u ccaa filebrowser -c /etc/ccaa/config.json > /var/log/fbrun.log 2>&1 &
	nohup sudo -u ccaa /usr/bin/python3 /usr/sbin/ccaa_delete_api.py > /var/log/ccaa_delete_api.log 2>&1 &

	#重置权限
	chown -R ccaa:ccaa /etc/ccaa/
	chown -R ccaa:ccaa ${downpath}

	#注册服务
	add_service

	echo '-------------------------------------------------------------'
	echo "大功告成，请访问: http://${osip}:6080/"
	echo "File Browser 地址: http://${osip}:6081/"
	echo '请在浏览器中打开以下 AriaNg 自动配置链接：'
	echo 'AriaNg 会自动保存生成的 RPC 密钥并重新载入页面。'
	echo "${ariang_rpc_url}"
	echo 'File Browser 用户名:admin'
	echo 'File Browser 密码:admin'
	echo 'Aria2 RPC 密钥:' ${secret}
	echo '帮助文档: https://dwz.ovh/ccaa （必看）' 
	echo '-------------------------------------------------------------'
}
#清理工作
function cleanup(){
	cd
	rm -rf ccaa_tmp
	#rm -rf *.conf
	#rm -rf init
}

#卸载
function uninstall(){
	wget -O ccaa-uninstall.sh https://raw.githubusercontent.com/helloxz/ccaa/master/uninstall.sh
	bash ccaa-uninstall.sh
}

#选择安装方式
echo "------------------------------------------------"
echo "Linux + File Browser + Aria2 + AriaNg一键安装脚本(CCAA)"
echo "1) 安装CCAA"
echo "2) 卸载CCAA"
echo "3) 更新bt-tracker"
echo "q) 退出！"
read -p ":" istype
case $istype in
    1) 
    	check
    	setout
    	chk_firewall
    	install_aria2 && \
    	install_file_browser && \
    	dealconf && \
    	setting && \
    	cleanup
    ;;
    2) 
    	uninstall
    ;;
    3) 
    	bash /etc/ccaa/upbt.sh
    ;;
    q) 
    	exit
    ;;
    *) echo '参数错误！'
esac
