#!/bin/bash
#==============================================================#
#   Description: Ngrok Install Shell                           #
#   Author: reruin <reruin@gmail.com>                          #
#   Intro:  https://fansh.org                                  #
#==============================================================#

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

ngrok_dir="/usr/local/ngrok"

ngrok_bin=${ngrok_dir}/bin/ngrokd

ngrok_log=${ngrok_dir}/ngrok.log

ngrok_cfg=${ngrok_dir}/ngrok.conf

server_crt=${ngrok_dir}/server.crt
server_key=${ngrok_dir}/server.key

currentfile=${BASH_SOURCE[0]} 

echo "${basepath}"

os_bit_64=1

download_url="https://raw.githubusercontent.com/reruin/ngrok/master/server/server_ngrokd_"

check_os_bit(){
	if [ $(getconf WORD_BIT) = '32' ] && [ $(getconf LONG_BIT) = '64' ];then
		os_bit_64=1
	else
		os_bit_64=0
	fi
}

wait_(){
	sleep 1
	echo -n '.'
	sleep 1
	echo -n '.'
	sleep 1
	echo -n '.'

}

wait_for(){
	count=0;  
    while [ $count -lt $1 ] ;  
    	do  
    	echo -n ".";  
    	let ++count;  
    	sleep 1;  
    done  

    return 0; 
}

install_dep(){
	echo "Preparatory work ... "
	[[ -f /etc/redhat-release ]] && os='centos'
	[[ ! -z "`egrep -i debian /etc/issue`" ]] && os='debian'
	[[ ! -z "`egrep -i ubuntu /etc/issue`" ]] && os='ubuntu'

	[[ "$os" == '' ]] && echo 'Error: Your system is not supported to run it!' && exit 1

	if [ "$os" == 'centos' ]; then
		yum -y -q install wget vim curl curl-devel jq >/dev/null 2>&1
	else
		apt-get update >/dev/null 2>&1
		apt-get -y -qq install wget curl vim openssl libcurl4-openssl-dev jq >/dev/null 2>&1
	fi
}


do_install(){
	header

	echo "============== Install =============="

	set_cofig_process

	install_dep

	program_file="linux_386"

	if [ "${os_bit_64}" = 1 ] ; then
		program_file="linux_amd64"
	fi

	if ! wget --no-check-certificate ${download_url}${program_file} -O ${ngrok_bin}; then
        echo "Failed to download ${program_file} file!"
        exit 1
    fi

    chmod 755 ${ngrok_bin}
    cd ${ngrok_dir}

    openssl genrsa -out rootCA.key 2048
    openssl req -x509 -new -nodes -key rootCA.key -subj "/CN=${domain}" -days 5000 -out rootCA.pem
    openssl genrsa -out server.key 2048
    openssl req -new -key server.key -subj "/CN=${domain}" -out server.csr
    openssl x509 -req -in server.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out server.crt -days 5000

    do_start

    echo "Install Ngrok completed."

    if [ "${arg1}" = "install" ]; then
      exit 0
    fi

    init
}


do_uninstall(){
	header

	echo "============== Uninstall =============="
	

	read -p "Do you want to KEEP the config file , Default [y]:" strSaveConfig

	local PID=`ps -ef | grep -v grep | grep -i "${ngrok_bin}" | awk '{print $2}'`

	if [ ! -z $PID ]; then
        kill -9 $PID >/root/a.txt 2>&1
    fi


	if [ "${strSaveConfig}" = "" ]; then
		strSaveConfig="y"
	fi

    if [ "${strSaveConfig}" = 'y' ]; then
        rm -rf ${ngrok_dir}/bin ${ngrok_dir}/ngrok.log ${ngrok_dir}/rootCA.* 
    else
        rm -rf ${ngrok_dir}
    fi

    echo "Ngrok uninstall success!"

    if [ "${arg1}" = "uninstall" ]; then
      exit 0
    fi

	$currentfile
}

check_run(){
	local PID=`ps -ef | grep -v grep | grep -i "${ngrok_bin}" | awk '{print $2}'`

	if [ -z ${PID} ]; then
        return 1
    else
        return 0
    fi
}

do_start(){

	header
	
	if check_run; then
		echo "Ngrok is already running ..."
		exit 0
	fi

    get_config

    if [ "${1}" = "r" ] ; then
    	echo -n "Restarting : "
    else
    	echo -n "Starting : "
    fi


	${ngrok_bin} -domain="${domain}" -httpAddr=":${httpAddr}" -httpsAddr=":${httpsAddr}" -pass="${pass}" -tlsCrt="${server_crt}" -tlsKey="${server_key}" > ${ngrok_log} 2>&1 &
    #-log "${ngrok_log}" 
    wait_

    if check_run; then
        echo "    [OK]"
    else
        echo "    [FAILED]"
    fi
}

do_stop(){	
	header

	echo -n "Stopping : "

	local PID=`ps -ef | grep -v grep | grep -i "${ngrok_bin}" | awk '{print $2}'`
	

	if [ ! -z $PID ]; then
		# echo "#!/bin/bash" > ${ngrok_dir}/.stop.sh

		# for i in $PID  
		# do  
		#   echo "kill -9 $i" >> ${ngrok_dir}/.stop.sh
		# done

		# chmod 500 ${ngrok_dir}/.stop.sh

		# ${ngrok_dir}/.stop.sh



        
		for i in $PID  
		do  
		  kill -9 $i >/dev/null 2>&1
		done
        echo "    [OK]"
        #rm -f ${ngrok_pid}
    else
        echo "Ngrok is not running."
    fi

    #RETVAL=$?

	#$currentfile

	exit 0
}

do_restart(){
	header

	local PID=`ps -ef | grep -v grep | grep -i "${ngrok_bin}" | awk '{print $2}'`

    echo -n "Stopping : "

	if [ ! -z $PID ]; then
        kill -9 $PID >/dev/null 2>&1
        echo "    [OK]"
    else
    	echo "    [OK]"
    fi

    $currentfile "start" "r"

    exit 0
}

get_config(){
	if [ ! -r ${ngrok_cfg} ]; then
        echo "config file ${ngrok_cfg} not found"
        init
    else
		domain=$(cat $ngrok_cfg | jq '.domain')
		httpAddr=$(cat $ngrok_cfg | jq '.http_addr')
		httpsAddr=$(cat $ngrok_cfg | jq '.https_addr')
		pass=$(cat $ngrok_cfg | jq '.pass')
    fi
}

do_config(){
	header

	echo "============== Edit Config =============="
	echo ""
	set_cofig_process
}

set_cofig_process(){

	read -p "Please input domain for Ngrok(e.g.:ngrok.example.com):" domain
	read -p "Please input password for Ngrok(Default: 123456}):" ngrok_pass
	read -p "Please input http port for Ngrok(Default: 80}):" http_port
	read -p "Please input https port for Ngrok(Default: 443}):" https_port

	if [ "${ngrok_pass}" = "" ]; then
		ngrok_pass="123456"
	fi

	if [ "${http_port}" = "" ]; then
		http_port="80"
	fi

	if [ "${https_port}" = "" ]; then
		https_port="443"
	fi

	echo ""
	echo "domain: "${domain}
	echo "password: "${ngrok_pass}
	echo "http port: "${http_port}
	echo "https port: "${https_port}
	echo ""
	read -p "Please confirm config (Y/n):" strConfirmSaveCfg

	case "${strConfirmSaveCfg}" in
        y|Y|Yes|YES|yes|yES|yEs|YeS|yeS)
			echo ""
			strConfirmSaveCfg='y'
		;;
		n|N|No|NO|no|nO)
        	echo ""
        	strConfirmSaveCfg='n'
        ;;
		*)
			echo ""
			strConfirmSaveCfg='y'
		;;
	esac
    if [ "${strConfirmSaveCfg}" = "y" ]; then
		echo '{"domain":"'${domain}'","pass":"'${ngrok_pass}'","http_addr":'${http_port}',"https_addr":'${https_port}'}' > ${ngrok_cfg}
	else
		set_cofig_process
	fi

	if [ "${arg1}" = "config" ] ; then
    	exit 0
    elif [ "${arg1}" = "install" ]; then
    	echo -n ""
  	else
  		init
    fi

}


do_status(){
	header

	echo ""
	domain=$(cat $ngrok_cfg | jq '.domain')
	httpAddr=$(cat $ngrok_cfg | jq '.http_addr')
	httpsAddr=$(cat $ngrok_cfg | jq '.https_addr')
	pass=$(cat $ngrok_cfg | jq '.pass')

	echo  "domain: "${domain}
	echo -e "password: ${COLOR_PINKBACK_WHITEFONT} "${pass}" ${COLOR_END}."
	echo "http port: "${httpAddr}
	echo "https port: "${httpsAddr}

	echo ""
	if check_run; then
		echo "Ngrok is running ..."
	else
		echo "Ngrok is NOT running ..."
	fi
	echo ""
}

check_env(){
	mkdir -p ${ngrok_dir}/bin
}

init(){
	echo ""
	echo "Press any key to continue ..."
	get_char
	welcome
}

header(){
	clear
	echo "+============================================================+"
    echo "|                      Ngrok for Linux                       |"
    echo "|                                                            |"
    echo "|                                         <reruin@gmail.com> |"
    echo "|------------------------------------------------------------|"
    echo "|                                          https://fansh.org |"
    echo "+============================================================+"
	echo ""

	check_env
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

welcome(){

	header
	echo " 1. Install"
	echo " 2. Uninstall"
	echo " 3. Edit Config"
	echo " 4. Show Config"
	echo " 0. Exit"
	echo ""

	read num
	case "$num" in
		[1] )
			do_install
		;;
		[2] )
			do_uninstall
		;;
		[3] )
			do_cofig
		;;
		[4] )
			do_status
		;;
		[0] )
			exit 0
		;;
		*) 
			welcome
		;;
	esac

	exit 0
}


arg1=${1}
arg2=${2}
[  -z ${arg1} ]
case "${arg1}" in
    install|uninstall|start|stop|restart|config|status)
        do_${arg1} ${arg2}
    ;;
    *)
        echo -ne "Usage:\n     $0 [ install | uninstall | start | stop | restart | config | status ]\n\n"

    ;;
esac