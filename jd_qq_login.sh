#!/bin/bash

UA="Mozilla/5.0 (iPhone; CPU iPhone OS 15_0_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1"
UA2="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.1047.2 Safari/537.36 Edg/96.0.1047.2"
DEBUG=0

HOME_URL="https://home.m.jd.com/myJd/newhome.action"
ENTRANCE_URL="https://plogin.m.jd.com/cgi-bin/mm/new_login_entrance?lang=chs&appid=300"
QQ_ENTRANCE_URL="https://plogin.m.jd.com/cgi-bin/m/qqlogin?appid=300"

function urlencode() {
   local data
   if [ "$#" -eq 1 ]; then
      data=$(curl -s -o /dev/null -w %{url_effective} --get --data-urlencode "$1" "")
      if [ ! -z "$data" ]; then
         echo "$(echo ${data##/?} |sed 's/\//%2f/g' |sed 's/:/%3a/g' |sed 's/?/%3f/g' \
		|sed 's/(/%28/g' |sed 's/)/%29/g' |sed 's/\^/%5e/g' |sed 's/=/%3d/g' \
		|sed 's/|/%7c/g' |sed 's/+/%20/g')"
      fi
   fi
}

function urldecode() {
  printf $(echo -n "$1" | sed 's/\\/\\\\/g;s/\(%\)\([0-9a-fA-F][0-9a-fA-F]\)/\\x\2/g')"\n"
}

function initiate_depends() {
	local PKG_INSTALL

	which apt 2>/dev/null >/dev/null
	if [[ $? -eq 0 ]]; then
		PKG_INSTALL=apt-get
	else
		which dnf  2>/dev/null >/dev/null
		if [[ $? -eq 0 ]]; then
			PKG_INSTALL=dnf
		else
			which yum  2>/dev/null >/dev/null
			if [[ $? -eq 0 ]]; then
				PKG_INSTALL=yum
			fi
		fi
	fi

	if [[ -z "${PKG_INSTALL}" ]]; then
		echo "未找到dnf/yum/apt-get任何一种包管理工具，请手工检查依赖包"
	fi

	#jq
	which jq  2>/dev/null >/dev/null
	if [[ $? -ne 0 ]]; then
		echo "开始安装jq"
		sudo "${PKG_INSTALL}" install -y jq 2>/dev/null
	fi

	#zbarimg
	which zbarimg  2>/dev/null >/dev/null
	if [[ $? -ne 0 ]]; then
		echo "开始安装zbar"
		sudo "${PKG_INSTALL}" install -y zbar 2>/dev/null
	fi

	#qrencode
	which qrencode 2>/dev/null >/dev/null
	if [[ $? -ne 0 ]]; then
		echo "开始安装qrencode"
		sudo "${PKG_INSTALL}" install -y qrencode 2>/dev/null
	fi
}

function get_home_jump() {
	local RESP_HEADER=$1
	local RESP_BODY=$2

	curl -sSL -D - \
		"${HOME_URL}" \
		-A "${UA}" \
		-H "pragma: no-cache" \
		-H "cache-control: no-cache" \
		--compressed \
		-o "${RESP_BODY}"  \
		| tr -d '\r' \
		>"${RESP_HEADER}"
}

function get_stoken() {
	local RESP_HEADER=$1
	local RESP_BODY=$2

	local RISK_JD=$(head /dev/urandom |cksum | md5sum | awk '{print $1}' | tr -d '\r|\n')

	curl -sS -D - \
		"${ENTRANCE_URL}&returnurl=$(urlencode ${RETURN_URL1})&returnurl=$(urlencode ${RETURN_URL2})" \
		-A "${UA2}" \
		-H "Host: plogin.m.jd.com" \
		-H "Cookie: guid=${GUID}; lang=${LANG}; lsid=${LS_ID}" \
		-H "accept: application/json, text/plain, */*" \
		-H "content-type: application/x-www-form-urlencoded" \
		-H "referer: ${DEST_URL}" \
		-H "pragma: no-cache" \
		-H "cache-control: no-cache" \
		-G \
		-d "risk_jd[fp]=${RISK_JD}" \
		--compressed \
		-o "${RESP_BODY}"  \
		| tr -d '\r' \
		>"${RESP_HEADER}"
}

function get_qq_login_url() {
	local RESP_HEADER=$1
	local RESP_BODY=$2

	curl -sSL -D - \
		"${QQ_ENTRANCE_URL}&returnurl=$(urlencode ${RETURN_URL1})&returnurl=$(urlencode ${RETURN_URL2})" \
		-A "${UA2}" \
		-H "Host: plogin.m.jd.com" \
		-H "Cookie: __jd_ref_cls=MLoginRegister_SMSQQLogin; guid=${GUID}; lang=${LANG}; lsid=${LS_ID}; lstoken=${LS_TOKEN}" \
		-H "accept: application/json, text/plain, */*" \
		-H "content-type: application/x-www-form-urlencoded" \
		-H "referer: ${DEST_URL}" \
		-H "pragma: no-cache" \
		-H "cache-control: no-cache" \
		-G \
		-d "risk_jd[fp]=960ccf37084be65f418c4daeaf58c5da" \
		--compressed \
		-o "${RESP_BODY}"  \
		| tr -d '\r' \
		>"${RESP_HEADER}"
}

function get_redir_url_qrcode_req() {
	local BODY_QQ_AUTH2=$1
	local CLIENT_ID=$2

	local DM_HOST=$(cat "${BODY_QQ_AUTH2}" | grep 'Q.crtDomain =' | sed "s/^.*http:\/\///g" | awk -F \' '{print $1}')
	local S_URL1=$(cat "${BODY_QQ_AUTH2}" | grep "^[ ][ ].*s_url =" | sed -n "1p" | awk -F \' '{print $2}')
	local S_URL2=$(cat "${BODY_QQ_AUTH2}" | grep "^[ ][ ].*s_url =" | sed -n "2p" | awk -F \' '{print $2}')
	local FEED_BACK_LINK="$(cat "${BODY_QQ_AUTH2}" | grep "var feed_back_link" \
		| sed -n "1p" | awk -F \' '{print $2}')$(urlencode ${DM_HOST}).appid${CLIENT_ID}"
	local S_URL="${S_URL2}$(urlencode "${S_URL1}")&pt_3rd_aid=$(urlencode "${CLIENT_ID}")&&pt_feedback_link=$(urlencode "${FEED_BACK_LINK}")"
	echo -n ${S_URL}
}

function get_qq_req_post() {
	local RESP_HEADER=$1
	local RESP_BODY=$2
	local QQ_REQEST_URL=$3

	curl -sS -D - \
		"${QQ_REQEST_URL}" \
		-H "Host: xui.ptlogin2.qq.com" \
		-A "${UA2}" \
		-H "accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9" \
		-H "referer: https://graph.qq.com/" \
		-H "pragma: no-cache" \
		-H "cache-control: no-cache" \
		--compressed \
		-o "${RESP_BODY}"  \
		| tr -d '\r' \
		>"${RESP_HEADER}"
}

function get_qq_qrcode() {
	local RESP_HEADER=$1
	local RESP_BODY=$2

	#获取二维码
	curl -sS -D - \
		"https://ssl.ptlogin2.qq.com/ptqrshow?appid=${APP_ID}&daid=${DAID}&pt_3rd_aid=${PT_3RD_AID}" \
		-A "${UA2}" \
		-H 'Referer: https://xui.ptlogin2.qq.com/' \
		-H "Cookie: ${QQ_COOKIE}" \
		-H "accept-encoding: gzip, deflate, br" \
		--compressed \
		-o "${RESP_BODY}" \
		| tr -d '\r' \
		>"${RESP_HEADER}"

	# cat "${RESP_HEADER}"
	zbarimg --raw -q "${RESP_BODY}" | tr -d '\n|\r' | qrencode -t ANSIUTF8
}

function hash33() {
	local PRQR_SIGN=$1
	local LEN=${#PRQR_SIGN}
	local i=0
	local e=0
	local CHAR
	local CHAR_CODE

	while [[ ${i} -lt ${LEN} ]]
	do
		let ++i
		CHAR=$(echo -n "${PRQR_SIGN}" | cut -b ${i})
		CHAR_CODE=$(printf "%d" "'${CHAR}")
		e=$((${e} + ((${e} << 5)) + ${CHAR_CODE}))
	done
	echo $(( 2147483647 & ${e} ))
}

function hash_g_tk() {
	local P_SKEY=$1
	local LEN=${#P_SKEY}
	local i=0
	local CHAR
	local CHAR_CODE
	local HASH=5381

	if [[ -z "${P_SKEY}" ]]; then P_SKEY=''; fi

	while [[ ${i} -lt ${LEN} ]]
	do
		let ++i
		CHAR=$(echo -n "${P_SKEY}" | cut -b ${i})
		CHAR_CODE=$(printf "%d" "'${CHAR}")
		HASH=$((${HASH} + ((${HASH} << 5)) + ${CHAR_CODE}))
	done
	echo $(( ${HASH} & 0x7fffffff ))
}

function qq_ptqr_login() {
	local RESP_HEADER=$1
	local RESP_BODY=$2
	local ACTION="0-0-$(date +%s%3N)"

	curl -sS -D - \
		"https://ssl.ptlogin2.qq.com/ptqrlogin?u1=https%3A%2F%2Fgraph.qq.com%2Foauth2.0%2Flogin_jump&ptqrtoken=${PTQR_TOKEN}&ptredirect=0&h=1&t=1&g=1&from_ui=1&ptlang=${PT_LANG}&action=${ACTION}&js_ver=${JS_VER}&js_type=1&login_sig=${PT_LOGIN_SIG}&pt_uistyle=40&aid=${APP_ID}&daid=${DAID}&pt_3rd_aid=${PT_3RD_AID}&" \
		-H "Host: ssl.ptlogin2.qq.com" \
		-A "${UA2}" \
		-H "Accept: */*" \
		-H "Referer: https://xui.ptlogin2.qq.com/" \
		-H "Cookie: ${QQ_COOKIE}; qrsig=${QR_SIGN}" \
		-H "Pragma: no-cache" \
		-H "Cache-Control: no-cache" \
		--compressed \
		-o "${RESP_BODY}"  \
		| tr -d '\r' \
		>"${RESP_HEADER}"
}

function qq_check_sig() {
	local RESP_HEADER=$1
	local RESP_BODY=$2
	local CHECK_SIG_URL=$3
	curl -sS -D - \
		"${CHECK_SIG_URL}" \
		-H "Cookie: ui=${UUID}; RK=${RK}; ptcz=${PTCZ}" \
		-A "${UA2}" \
		-H "accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9" \
		-H "referer: https://xui.ptlogin2.qq.com/" \
		-H "pragma: no-cache" \
		-H "cache-control: no-cache" \
		--compressed \
		-o "${RESP_BODY}"  \
		| tr -d '\r' \
		>"${RESP_HEADER}"
}

function qq_auth() {
	local RESP_HEADER=$1
	local RESP_BODY=$2
	local POST_BODY=$(echo "${QQ_JUMP_URL}" | sed "s/^.*which=Login&display=pc&//g")
	local AUTH_TIME=$(date +%s%3N)

	curl -sS -D - \
		"https://graph.qq.com/oauth2.0/authorize" \
		-A "${UA2}" \
		-H "Cookie: ui=${UUID}; RK=${RK}; ptcz=${PTCZ}; p_uin=${P_UIN}; pt4_token=${PT4_TOKEN}; p_skey=${P_SKEY}; pt_oauth_token=${PT_OAUTH_TOKEN}; pt_login_type=${PT_LOGIN_TYPE}" \
		-H "origin: https://graph.qq.com" \
		-H "content-type: application/x-www-form-urlencoded" \
		-H "accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9" \
		-H "referer: ${QQ_JUMP_URL}" \
		-H "pragma: no-cache" \
		-H "cache-control: no-cache" \
		-d "${POST_BODY}&switch=&from_ptlogin=1&src=1&update_auth=1&openapi=80901010&g_tk=${G_TK}&auth_time=${AUTH_TIME}&ui=${UUID}" \
		--compressed \
		-o "${RESP_BODY}"  \
		| tr -d '\r' \
		>"${RESP_HEADER}"
}

function jd_qqcallback() {
	local RESP_HEADER=$1
	local RESP_BODY=$2
	curl -sS -D - \
		"${JD_QQ_CALLBACK_URL}" \
		-H "Host: plogin.m.jd.com" \
		-A "${UA2}" \
		-H "Cookie: guid=${GUID}; lang=${LANG}; lstoken=${LS_TOKEN}; __jd_ref_cls=MLoginRegister_SMSQQLogin; lsid=${LS_ID}" \
		-H "accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9" \
		-H "referer: https://graph.qq.com/" \
		-H "pragma: no-cache" \
		-H "cache-control: no-cache" \
		--compressed \
		-o "${RESP_BODY}"  \
		| tr -d '\r' \
		>"${RESP_HEADER}"
}

function main() {
	# 检查依赖环境
	initiate_depends

	# 浏览京东触屏版首页根据UA标识获取重定向地址和原始cookie
	echo "京东COOKIE获取工具shell-QQ扫码版"
	echo "作者: Hans Yao (hansyow@gmail.com)"
	echo "github: https://github.com/hansyao/jd_tools"
	echo "website: https://hansyao.github.io"
	echo
	STATE=$(date +%s)
	get_home_jump '/tmp/response_header_home_jump' '/tmp/response_body_home_jump'
	DEST_URL=$(cat /tmp/response_header_home_jump | grep -i "^location:" | awk '{print $2}' | tail -n 1)
	DEST_MAIN_URL=$(echo "${DEST_URL}" | awk -F '&' '{print $1}')
	RETURN_URL=$(urldecode $(echo "${DEST_URL}" | awk -F "returnurl=" '{print $(NF)}'))
	RETURN_URL1=$(echo "${RETURN_URL}" | awk -F "returnurl=" '{print $1}' | sed "s/\&$//g")
	RETURN_URL2=$(urldecode $(echo "${RETURN_URL}" | awk -F "returnurl=" '{print $2}' | sed "s/\&$//g"))
if [[ ${DEBUG} -eq 1 ]]; then
	echo DEST_URL: ${DEST_URL}
	echo DEST_MAIN_URL: ${DEST_MAIN_URL}
	echo RETURN_URL1: ${RETURN_URL1}
	echo RETURN_URL2: ${RETURN_URL2}
fi

	HOME_JUMP_HEADER=$(cat /tmp/response_header_home_jump | grep -i "^set-cookie:")
	GUID=$(echo -e "${HOME_JUMP_HEADER}" | grep "guid=" |grep -v "guid=;"\
		| awk '{print $2}' | cut -d '=' -f2 | sed "s/;$//g")
	LANG=$(echo -e "${HOME_JUMP_HEADER}" | grep "lang=" | grep -v "lang=;" \
		| awk '{print $2}' | cut -d '=' -f2 | sed "s/;$//g")
	LS_ID=$(echo -e "${HOME_JUMP_HEADER}" | grep "lsid=" |grep -v "lsid=;" \
		| awk '{print $2}' | cut -d '=' -f2 | sed "s/;$//g")

	COOKIE="guid=${GUID}; lang=${LANG}; lsid=${LS_ID}"
if [[ ${DEBUG} -eq 1 ]]; then
	echo -e "jd_cookie: ${COOKIE}"
fi

	# 获取stoken密钥合并到lstoken cookie
	get_stoken '/tmp/response_header_stoken' '/tmp/response_body_stoken'
	LS_TOKEN=$(cat '/tmp/response_header_stoken' | grep -i "^set-cookie" \
		| grep "lstoken=" |grep -v "lstoken=;"| awk '{print $2}' | cut -d '=' -f2 | sed "s/;$//g")
	COOKIE="guid=${GUID}; lang=${LANG}; lsid=${LS_ID}; lstoken=${LS_TOKEN}"
if [[ ${DEBUG} -eq 1 ]]; then
	echo -e "jd_cookie: ${COOKIE}"
fi

	# 获取京东的QQ登录接口路径和参数
	get_qq_login_url '/tmp/response_header_qq_login' '/tmp/response_body_qq_login'
	LS_ID_QQ=$(cat '/tmp/response_header_qq_login' | grep -i "^set-cookie" \
		| grep "lsid=" |grep -v "lsid=;"| awk '{print $2}' | cut -d '=' -f2 | sed "s/;$//g")
	QQ_JUMP_URL=$(cat /tmp/response_header_qq_login | grep -i "^location:" | awk '{print $2}' | tail -n 1)
	QQ_CALLBACK_URL=$(urldecode "${QQ_JUMP_URL}" | awk -F "redirect_uri=" '{print $(NF)}')
	CLIENT_ID=$(echo "${QQ_JUMP_URL}" | sed "s/^.*client_id=//g" | sed "s/&.*$//g")
if [[ ${DEBUG} -eq 1 ]]; then
	echo QQ_JUMP_URL: ${QQ_JUMP_URL}
	echo -e "lsid for QQ: ${LS_ID_QQ}"
fi

	# 获取腾讯QQ接口参数
	QQ_REQEST_URL=$(get_redir_url_qrcode_req '/tmp/response_body_qq_login' "${CLIENT_ID}")
if [[ ${DEBUG} -eq 1 ]]; then
	echo QQ_REQEST_URL: ${QQ_REQEST_URL}
fi

	DAID=$(echo -e "${QQ_REQEST_URL}" | sed "s/^.*?//g" | sed "s/^.*\&daid=//g" | sed "s/\&.*$//g")
	PT_3RD_AID=$(echo -e "${QQ_REQEST_URL}" | sed "s/^.*?//g" | sed "s/^.*\&pt_3rd_aid=//g" | sed "s/\&.*$//g")
	APP_ID=$(echo -e "${QQ_REQEST_URL}" | sed "s/^.*?//g" | sed "s/^.*appid=//g" | sed "s/\&.*$//g")
if [[ ${DEBUG} -eq 1 ]]; then
	echo daid: $DAID
	echo pt_3rd_aid: $PT_3RD_AID
	echo app_id: $APP_ID
fi
	# 提交QQ登录请求获取QQ cookie
	get_qq_req_post '/tmp/response_header_qq_req' '/tmp/response_body_qq_req' "${QQ_REQEST_URL}"
	QQ_COOKIE=$(cat /tmp/response_header_qq_req | grep -i "^set-cookie:" \
		| grep -iv "pt_user_id=\|ptui_identifier=" |  awk '{print $2}' | tr -d '\n' | sed "s/;$//g")
	JS_VER=$(cat /tmp/response_body_qq_req | tr -d "\n" \
		| sed "s/.*ptui_version:encodeURIComponent(//g" | awk -F \" '{print $2}')
	PT_LANG=$(cat /tmp/response_body_qq_req |  tr -d "\n" \
		| sed "s/.*lang:encodeURIComponent(//g" | awk -F \" '{print $2}')
	PT_LOGIN_SIG=$(echo -e "${QQ_COOKIE}" | sed "s/^.*pt_login_sig=//g" | sed "s/;.*$//g")
if [[ ${DEBUG} -eq 1 ]]; then
	echo pt_login_sig: $PT_LOGIN_SIG
	echo ptlang: $PT_LANG
	echo js_ver: ${JS_VER}
	echo -e "QQ_COOKIE: ${QQ_COOKIE}"
fi

	# 获取QQ二维码接口参数
	get_qq_qrcode '/tmp/response_header_qq_barcode'  '/tmp/response_body_qq_barcode'
	QR_SIGN=$(cat /tmp/response_header_qq_barcode | grep -i "^set-cookie:" \
		| awk '{print $2}' | awk -F ';' '{print $1}' | cut -d "=" -f2)

	# 解密ptpr_token密钥
	PTQR_TOKEN=$(hash33 "${QR_SIGN}")
if [[ ${DEBUG} -eq 1 ]]; then
	echo -e "qrsig: ${QR_SIGN}"
	echo -e "ptqr_token: $PTQR_TOKEN"
fi

	# 轮询等待扫码成功，或者超时退出
	echo -e "等待QQ客户端扫码登录\\c"
	i=0
	while [[ ${i} -le 300 ]]
	do
		qq_ptqr_login '/tmp/response_header_qq_ptqr_login' '/tmp/response_body_qq_ptqr_login'
		QR_STATUS=$(cat /tmp/response_body_qq_ptqr_login 2>/dev/null | awk -F ',' '{print $1}' | awk -F \' '{print $2}')
		case ${QR_STATUS} in
			0)
				cat /tmp/response_body_qq_ptqr_login 2>/dev/null | awk -F ',' '{print $5, $6}' | sed "s/)$//g"
				break;;
			65)
				cat /tmp/response_body_qq_ptqr_login 2>/dev/null | awk -F ',' '{print $5}'
				echo "请重新运行" return 1
				;;
			67)
				cat /tmp/response_body_qq_ptqr_login 2>/dev/null | awk -F ',' '{print $5}'
				;;
			*)
				echo -e ".\\c"
		esac
		let i++
		sleep 1
	done
	CHECK_SIG_URL=$(cat /tmp/response_body_qq_ptqr_login 2>/dev/null \
		| awk -F ',' '{print $3}' | sed "s/^'//g" | sed "s/'$//g")
	QQ_COOKIE_RESP_PTQR=$(cat /tmp/response_header_qq_ptqr_login | grep -i "^set-cookie:" \
		| awk  '$2!~"=;" {print $2}' | awk -F ';' '{print $1}')
	UUID=$(cat /proc/sys/kernel/random/uuid | tr 'a-z' 'A-Z')
	RK=$(echo -e "${QQ_COOKIE_RESP_PTQR}" | awk -F '=' '$1=="RK" {print $(NF)}')
	PTCZ=$(echo -e "${QQ_COOKIE_RESP_PTQR}" | awk -F '=' '$1=="ptcz" {print $(NF)}')
	unset i

	# 验证qq登录状态，得到握手密钥
	qq_check_sig '/tmp/response_header_qq_check_sig' '/tmp/response_body_qq_check_sig' "${CHECK_SIG_URL}"
	QQ_COOKIE_RESP_CHECKSIG=$(cat /tmp/response_header_qq_check_sig | grep -i "^set-cookie:" \
		| awk  '$2!~"=;" {print $2}' | awk -F ';' '{print $1}')
	PT2GGUIN=$(echo -e "${QQ_COOKIE_RESP_CHECKSIG}" | awk -F '=' '$1=="pt2gguin" {print $(NF)}')
	P_UIN=$(echo -e "${QQ_COOKIE_RESP_CHECKSIG}" | awk -F '=' '$1=="p_uin" {print $(NF)}')
	PT4_TOKEN=$(echo -e "${QQ_COOKIE_RESP_CHECKSIG}" | awk -F '=' '$1=="pt4_token" {print $(NF)}')
	P_SKEY=$(echo -e "${QQ_COOKIE_RESP_CHECKSIG}" | awk -F '=' '$1=="p_skey" {print $(NF)}')
	PT_OAUTH_TOKEN=$(echo -e "${QQ_COOKIE_RESP_CHECKSIG}" | awk -F '=' '$1=="pt_oauth_token" {print $(NF)}')
	PT_LOGIN_TYPE=$(echo -e "${QQ_COOKIE_RESP_CHECKSIG}" | awk -F '=' '$1=="pt_login_type" {print $(NF)}')

	# 解密g_tk密钥以获取京东qqcallcak回调地址
	G_TK=$(hash_g_tk "${P_SKEY}")
	qq_auth '/tmp/response_header_qq_auth' '/tmp/response_body_qq_auth'
	JD_QQ_CALLBACK_URL=$(cat '/tmp/response_header_qq_auth' | grep -i "^location:" | awk '{print $(NF)}')

	# 登录京东获取最终cookie
	jd_qqcallback '/tmp/response_header_jd_qqcallback' '/tmp/response_body_jd_qqcallback'
	JD_COOKIE_FINAL=$(cat /tmp/response_header_jd_qqcallback | grep -i "^set-cookie:" \
		| awk  '$2!~"=;" {print $2}' | awk -F ';' '{print $1}')
	echo
	RISK_RETURN=$(cat /tmp/response_header_jd_qqcallback | grep -i "^location:" | grep risk | awk '{print $(NF)}')
	if [[ -n "${RISK_RETURN}" ]]; then
		echo "触发京东安全检测，需要扫描以下链接做二次验证, 但本脚本手机验证功能暂未实现"
		echo "请稍后重试..."
		echo "${RISK_RETURN}" | qrencode -t ANSIUTF8
		return 1
	fi
	echo "京东cookie获取成功:"
	echo -e "${JD_COOKIE_FINAL}"
}

main