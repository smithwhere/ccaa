#!/bin/bash
#####	涓€閿畨瑁匜ile Browser + Aria2 + AriaNg		#####
#####	浣滆€咃細xiaoz.me						#####
#####	鏇存柊鏃堕棿锛?020-02-27				#####

#瀵煎叆鐜鍙橀噺
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin:/sbin
export PATH

#CDN鍩熷悕璁剧疆
if [ $1 = 'cdn' ]
	then
	aria2_url='http://soft.xiaoz.top/linux/aria2-1.35.0-linux-gnu-64bit-build1.tar.bz2'
	filebrowser_url='http://soft.xiaoz.top/linux/linux-amd64-filebrowser.tar.gz'
	master_url='https://github.com/helloxz/ccaa/archive/master.zip'
	ccaa_web_url='http://soft.xiaoz.top/linux/ccaa_web.tar.gz'
	else
	aria2_url='https://github.com/q3aql/aria2-static-builds/releases/download/v1.35.0/aria2-1.35.0-linux-gnu-64bit-build1.tar.bz2'
	filebrowser_url='https://github.com/filebrowser/filebrowser/releases/download/v2.0.16/linux-amd64-filebrowser.tar.gz'
	master_url='https://github.com/helloxz/ccaa/archive/master.zip'
	ccaa_web_url='http://soft.xiaoz.org/linux/ccaa_web.tar.gz'
fi

#瀹夎鍓嶇殑妫€鏌?function check(){
	echo '-------------------------------------------------------------'
	if [ -e "/etc/ccaa" ]
        then
        echo 'CCAA宸茬粡瀹夎锛岃嫢闇€瑕侀噸鏂板畨瑁咃紝璇峰厛鍗歌浇鍐嶅畨瑁咃紒'
        echo '-------------------------------------------------------------'
        exit
	else
	        echo '妫€娴嬮€氳繃锛屽嵆灏嗗紑濮嬪畨瑁呫€?
	        echo '-------------------------------------------------------------'
	fi
}

#瀹夎涔嬪墠鐨勫噯澶?function setout(){
	if [ -e "/usr/bin/yum" ]
	then
		yum -y install curl gcc make bzip2 gzip wget unzip tar
	else
		#鏇存柊杞欢锛屽惁鍒欏彲鑳絤ake鍛戒护鏃犳硶瀹夎
		sudo apt-get update
		sudo apt-get install -y curl make bzip2 gzip wget unzip sudo
	fi
	#鍒涘缓涓存椂鐩綍
	cd
	mkdir ./ccaa_tmp
	#鍒涘缓鐢ㄦ埛鍜岀敤鎴风粍
	groupadd ccaa
	useradd -M -g ccaa ccaa -s /sbin/nologin
}
#瀹夎Aria2
function install_aria2(){
	#浼樺厛瀹夎闈欐€佺紪璇戠増鏈紝涓嬭浇鎴栫紪璇戝け璐ユ椂鍥為€€鍒扮郴缁熻蒋浠跺寘銆?	cd "$HOME/ccaa_tmp" || return 1
	if wget -c "${aria2_url}" && \
		tar -xjf aria2-1.35.0-linux-gnu-64bit-build1.tar.bz2 && \
		(cd aria2-1.35.0-linux-gnu-64bit-build1 && make install); then
		:
	else
		echo '闈欐€佺増 aria2 瀹夎澶辫触锛屽皾璇曚娇鐢ㄧ郴缁熻蒋浠跺寘銆?
	fi

	if ! command -v aria2c >/dev/null 2>&1; then
		if command -v apt-get >/dev/null 2>&1; then
			apt-get update && apt-get install -y aria2 || return 1
		elif command -v dnf >/dev/null 2>&1; then
			dnf install -y aria2 || return 1
		elif command -v yum >/dev/null 2>&1; then
			yum install -y aria2 || return 1
		else
			echo '鎵句笉鍒版敮鎸佺殑杞欢鍖呯鐞嗗櫒锛屾棤娉曞畨瑁?aria2銆? >&2
			return 1
		fi
	fi

	if ! command -v aria2c >/dev/null 2>&1; then
		echo 'aria2 瀹夎鍚庝粛鏃犳硶鎵惧埌 aria2c锛屽仠姝㈠畨瑁呫€? >&2
		return 1
	fi
	cd "$HOME"
}

#瀹夎File Browser鏂囦欢绠＄悊鍣?function install_file_browser(){
	cd ./ccaa_tmp
	#涓嬭浇File Browser
	wget ${filebrowser_url}
	#瑙ｅ帇
	tar -zxvf linux-amd64-filebrowser.tar.gz
	#绉诲姩浣嶇疆
	mv filebrowser /usr/sbin
	cd
}
#澶勭悊閰嶇疆鏂囦欢
function dealconf(){
	cd ./ccaa_tmp
	#涓嬭浇CCAA椤圭洰
	wget ${master_url}
	#瑙ｅ帇
	unzip master.zip
	#澶嶅埗CCAA鏍稿績鐩綍
	mv ccaa-master/ccaa_dir /etc/ccaa
	#鍒涘缓aria2鏃ュ織鏂囦欢
	touch /var/log/aria2.log
	#upbt澧炲姞鎵ц鏉冮檺
	chmod +x /etc/ccaa/upbt.sh
	chmod +x ccaa-master/ccaa
	cp ccaa-master/ccaa /usr/sbin
	cd
}
#鑷姩鏀捐绔彛
function chk_firewall(){
	if [ -e "/etc/sysconfig/iptables" ]
	then
		iptables -I INPUT -p tcp --dport 6080 -j ACCEPT
		iptables -I INPUT -p tcp --dport 6081 -j ACCEPT
		iptables -I INPUT -p tcp --dport 6800 -j ACCEPT
		iptables -I INPUT -p tcp --dport 6998 -j ACCEPT
		iptables -I INPUT -p tcp --dport 51413 -j ACCEPT
		service iptables save
		service iptables restart
	elif [ -e "/etc/firewalld/zones/public.xml" ]
	then
		firewall-cmd --zone=public --add-port=6080/tcp --permanent
		firewall-cmd --zone=public --add-port=6081/tcp --permanent
		firewall-cmd --zone=public --add-port=6800/tcp --permanent
		firewall-cmd --zone=public --add-port=6998/tcp --permanent
		firewall-cmd --zone=public --add-port=51413/tcp --permanent
		firewall-cmd --reload
	elif [ -e "/etc/ufw/before.rules" ]
	then
		sudo ufw allow 6080/tcp
		sudo ufw allow 6081/tcp
		sudo ufw allow 6800/tcp
		sudo ufw allow 6998/tcp
		sudo ufw allow 51413/tcp
	fi
}
#鍒犻櫎绔彛
function del_post() {
	if [ -e "/etc/sysconfig/iptables" ]
	then
		sed -i '/^.*6080.*/'d /etc/sysconfig/iptables
		sed -i '/^.*6081.*/'d /etc/sysconfig/iptables
		sed -i '/^.*6800.*/'d /etc/sysconfig/iptables
		sed -i '/^.*6998.*/'d /etc/sysconfig/iptables
		sed -i '/^.*51413.*/'d /etc/sysconfig/iptables
		service iptables save
		service iptables restart
	elif [ -e "/etc/firewalld/zones/public.xml" ]
	then
		firewall-cmd --zone=public --remove-port=6080/tcp --permanent
		firewall-cmd --zone=public --remove-port=6081/tcp --permanent
		firewall-cmd --zone=public --remove-port=6800/tcp --permanent
		firewall-cmd --zone=public --remove-port=6998/tcp --permanent
		firewall-cmd --zone=public --remove-port=51413/tcp --permanent
		firewall-cmd --reload
	elif [ -e "/etc/ufw/before.rules" ]
	then
		sudo ufw delete 6080/tcp
		sudo ufw delete 6081/tcp
		sudo ufw delete 6800/tcp
		sudo ufw delete 6998/tcp
		sudo ufw delete 51413/tcp
	fi
}
#娣诲姞鏈嶅姟
function add_service() {
	if [ -d "/etc/systemd/system" ]
	then
		cp /etc/ccaa/services/* /etc/systemd/system
		systemctl daemon-reload
	fi
}
#璁剧疆璐﹀彿瀵嗙爜
function setting(){
	cd
	cd ./ccaa_tmp
	echo '-------------------------------------------------------------'
	read -p "璁剧疆涓嬭浇璺緞锛堣濉啓缁濆鍦板潃锛岄粯璁?data/ccaaDown锛?" downpath
	read -p "Aria2 RPC 瀵嗛挜:(瀛楁瘝鎴栨暟瀛楃粍鍚堬紝涓嶈鍚湁鐗规畩瀛楃):" secret
	#濡傛灉Aria2瀵嗛挜涓虹┖
	while [ -z "${secret}" ]
	do
		read -p "Aria2 RPC 瀵嗛挜:(瀛楁瘝鎴栨暟瀛楃粍鍚堬紝涓嶈鍚湁鐗规畩瀛楃):" secret
	done
	
	#濡傛灉涓嬭浇璺緞涓虹┖锛岃缃粯璁や笅杞借矾寰?	if [ -z "${downpath}" ]
	then
		downpath='/data/ccaaDown'
	fi

	#鑾峰彇ip
	osip=$(curl ipv4.ip.sb)
	
	#鎵ц鏇挎崲鎿嶄綔
	mkdir -p ${downpath}
	sed -i "s%dir=%dir=${downpath}%g" /etc/ccaa/aria2.conf
	sed -i "s/rpc-secret=/rpc-secret=${secret}/g" /etc/ccaa/aria2.conf
	#鏇挎崲filebrowser璇诲彇璺緞
	sed -i "s%ccaaDown%${downpath}%g" /etc/ccaa/config.json
	#鏇挎崲AriaNg鏈嶅姟鍣ㄩ摼鎺?	sed -i "s/server_ip/${osip}/g" /etc/ccaa/AriaNg/index.html
	
	#鏇存柊tracker
	bash /etc/ccaa/upbt.sh
	
	#瀹夎AriaNg
	wget ${ccaa_web_url}
	tar -zxvf ccaa_web.tar.gz
	cp ccaa_web /usr/sbin/
	chmod +x /usr/sbin/ccaa_web

	#鍚姩鏈嶅姟
	nohup sudo -u ccaa aria2c --conf-path=/etc/ccaa/aria2.conf > /var/log/aria2.log 2>&1 &
	#nohup caddy -conf="/etc/ccaa/caddy.conf" > /etc/ccaa/caddy.log 2>&1 &
	nohup sudo -u ccaa /usr/sbin/ccaa_web > /var/log/ccaa_web.log 2>&1 &
	#杩愯filebrowser
	nohup sudo -u ccaa filebrowser -c /etc/ccaa/config.json > /var/log/fbrun.log 2>&1 &

	#閲嶇疆鏉冮檺
	chown -R ccaa:ccaa /etc/ccaa/
	chown -R ccaa:ccaa ${downpath}

	#娉ㄥ唽鏈嶅姟
	add_service

	echo '-------------------------------------------------------------'
	echo "澶у姛鍛婃垚锛岃璁块棶: http://${osip}:6080/"
	echo 'File Browser 鐢ㄦ埛鍚?ccaa'
	echo 'File Browser 瀵嗙爜:admin'
	echo 'Aria2 RPC 瀵嗛挜:' ${secret}
	echo '甯姪鏂囨。: https://dwz.ovh/ccaa 锛堝繀鐪嬶級' 
	echo '-------------------------------------------------------------'
}
#娓呯悊宸ヤ綔
function cleanup(){
	cd
	rm -rf ccaa_tmp
	#rm -rf *.conf
	#rm -rf init
}

#鍗歌浇
function uninstall(){
	wget -O ccaa-uninstall.sh https://raw.githubusercontent.com/helloxz/ccaa/master/uninstall.sh
	bash ccaa-uninstall.sh
}

#閫夋嫨瀹夎鏂瑰紡
echo "------------------------------------------------"
echo "Linux + File Browser + Aria2 + AriaNg涓€閿畨瑁呰剼鏈?CCAA)"
echo "1) 瀹夎CCAA"
echo "2) 鍗歌浇CCAA"
echo "3) 鏇存柊bt-tracker"
echo "q) 閫€鍑猴紒"
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
    *) echo '鍙傛暟閿欒锛?
esac

