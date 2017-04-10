#!/bin/bash
#==============================================================#
#   Description: Ngrok Install Shell                           #
#   Author: reruin <reruin@gmail.com>                          #
#   Visit:  https://fansh.org                                  #
#==============================================================#

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

ngrok_dir="/usr/local/ngrok"

os_bit_64=1

download_url="https://raw.githubusercontent.com/reruin/ngrok/master/server/server_ngrokd_"

check_os_bit(){
	if [ $(getconf WORD_BIT) = '32' ] && [ $(getconf LONG_BIT) = '64' ];then
		os_bit_64 = 1
	else
		os_bit_64 = 0
	fi
}

install_dep(){
	[[ -f /etc/redhat-release ]] && os='centos'
	[[ ! -z "`egrep -i debian /etc/issue`" ]] && os='debian'
	[[ ! -z "`egrep -i ubuntu /etc/issue`" ]] && os='ubuntu'

	[[ "$os" == '' ]] && echo 'Error: Your system is not supported to run it!' && exit 1

	if [ "$os" == 'centos' ]; then
		yum -y install net-tools openssl-devel wget vim curl curl-devel
	else
		apt-get update
		apt-get -y install wget build-essential curl vim openssl libcurl4-openssl-dev net-tools 
	fi
}


install_ngrok(){
	intro

	echo "Install Ngrok ..."

	read -p "Please input domain for Ngrok(e.g.:ngrok.example.com):" NGROK_DOMAIN
	read -p "Please input password for Ngrok(Default Password: 123456}):" ngrok_pass

	if [ "$ngrok_pass" = "" ]; then
		ngrok_pass="123456"
	fi


	echo  "Domain: "${NGROK_DOMAIN}"."
	echo -e "Ngrok Pass: ${COLOR_PINKBACK_WHITEFONT} "${ngrok_pass}" ${COLOR_END}."
    echo -e "Press any key to start...or Press Ctrl+c to cancel"
    char=`get_char`
	clear

	program_file="linux_386"

	if [ "${os_bit_64}" = 1 ] ; then
		program_file = "linux_amd64"
	fi

	if ! wget --no-check-certificate ${download_url}${program_file} -O ${ngrok_dir}/bin/ngrokd; then
        echo "Failed to download ${program_file} file!"
        exit 1
    fi

    cd ${ngrok_dir}
    openssl genrsa -out rootCA.key 2048
    openssl req -x509 -new -nodes -key rootCA.key -subj "/CN=$NGROK_DOMAIN" -days 5000 -out rootCA.pem
    openssl genrsa -out server.key 2048
    openssl req -new -key server.key -subj "/CN=$NGROK_DOMAIN" -out server.csr
    openssl x509 -req -in server.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out server.crt -days 5000

	/usr/local/ngrok/bin/ngrokd -domain=$NGROK_DOMAIN -httpAddr=":51221"

    intro

    echo "Install Ngrok completed! enjoy it."
    echo "============================================"
    echo -e "Your Domain: ${COLOR_GREEN}${NGROK_DOMAIN}${COLOR_END}"
    echo -e "Ngrok password: ${COLOR_GREEN}${ngrok_pass}${COLOR_END}"
    echo -e "http_port: ${COLOR_GREEN}80${COLOR_END}"
    echo -e "https_port: ${COLOR_GREEN}443${COLOR_END}"
    echo -e "remote_port: ${COLOR_GREEN}4443${COLOR_END}"
    echo "============================================"
}


uninstall_ngrok(){
	intro
	echo "============== Uninstall =============="
	/etc/init.d/ngrokd stop

	read -p "(Do you want to KEEP the config file , Default [y]):" save_config

	# remove log
	rm -f /etc/init.d/ngrokd /usr/bin/ngrokd /var/run/ngrok_clang.pid /root/ngrok_install.log /root/ngrok_update.log

    if [ "${save_config}" == 'y' ]; then
        rm -rf ${ngrok_dir}/bin/ ${ngrok_dir}/ngrok.log ${ngrok_dir}/rootCA.* ${ngrok_dir}/server.*
    else
        rm -rf ${ngrok_dir}
    fi

    echo "Ngrok uninstall success!"
    echo ""
}


intro(){
	clear
	echo "
    #============================================
    #   SYSTEM     :  Debian / Ubuntu / Centos
    #   DESCRIPTION:  Install Ngrok
    #   AUTHOR     :  reruin <reruin@gmail.com>
    #   INTRO      :  https://fansh.org
    #============================================
	"
}

get_char()
{
    SAVEDSTTY=`stty -g`
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}

set_params(){
	COLOR_RED='\E[1;31m'
    COLOR_GREEN='\E[1;32m'
    COLOR_YELOW='\E[1;33m'
    COLOR_BLUE='\E[1;34m'
    COLOR_PINK='\E[1;35m'
    COLOR_PINKBACK_WHITEFONT='\033[45;37m'
    COLOR_GREEN_LIGHTNING='\033[32m \033[05m'
    COLOR_END='\E[0m'
}

welcome(){
	intro
	set_params
	echo "
	1. Install
	2. Uninstall
	3. Create Config
	4. Show Config
	0. Exit

	"
	read num
	case "$num" in
		[1] )
			install_dep
			install_ngrok
		;;
		[2] )
			uninstall_ngrok
		;;
		[3] )
			echo "Please Enter Domain"
			read domain
			echo "Runing Port"
			read port
			/usr/local/ngrok/bin/ngrokd -domain=$domain -httpAddr=":$port"
		;;
		[4] )
			echo "Please Enter Domain"
			read domain
			echo server_addr: '"'$domain:4443'"'
			echo "trust_host_root_certs: false"

		;;
		*) echo "";;
	esac
}

welcome