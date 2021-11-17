#!/bin/sh

UA='JD4iPhone/10.2.2 CFNetwork/1312 Darwin/21.0.0'
JD_COOKIE=''
SCORE=4,5	#商品符合度(逗号隔开不要有空格, 脚本会自动取介于前后之间的随机数)
DSR1=4,5	#店铺服务态度(逗号隔开不要有空格, 脚本会自动取介于前后之间的随机数)
DSR2=4,5	#物流发货速度(逗号隔开不要有空格, 脚本会自动取介于前后之间的随机数)
DSR3=4,5	#配送员服务(逗号隔开不要有空格, 脚本会自动取介于前后之间的随机数)
WAIT=15		#评论间隔时间，默认15秒

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

function get_random() {
	local MIN=4
	local MAX=5
	echo $(( ${MIN} + ${RANDOM} % ((${MAX}-${MIN} + 1)) ))
}
function get_order_list() {
	local RESP_HEADER=$1
	local RESP_BODY=$2
	local START_PAGE=$3

	curl -sS -D - \
		"https://wq.jd.com/bases/orderlist/list?&start_page=${START_PAGE}&page_size=10&order_type=6" \
		-A "${UA}" \
		-H 'pragma: no-cache' \
		-H 'cache-control: no-cache' \
		-H 'accept: */*' \
		-H 'referer: https://wqs.jd.com/' \
		-H "cookie: ${JD_COOKIE}" \
		-H 'jtzs-version: 1.0.8' \
		--compressed \
		-o "${RESP_BODY}"  \
		| tr -d '\r' \
		>"${RESP_HEADER}"
}

function get_order_status() {
	local RESP_HEADER=$1
	local RESP_BODY=$2

	curl -sS -D - \
		-A "${UA}" \
		-H "Cookie: ${JD_COOKIE}" \
		-H "pragma: no-cache" \
		-H "cache-control: no-cache" \
		-H "accept: */*" \
		-H "referer: https://wqs.jd.com/" \
		-H "accept-language: en-US,en;q=0.9,zh;q=0.8" \
		-H "jtzs-version: 1.0.8" \
		--compressed "https://wq.jd.com/bases/orderlist/GetOrderSiteCount?callersource=mainorder&g_login_type=1" \
		-o "${RESP_BODY}"  \
		| tr -d '\r' \
		>"${RESP_HEADER}"
}

function jd_append_comment() {
	local RESP_HEADER=$1
	local RESP_BODY=$2
	local PRODUCT_ID=$3
	local ORDER_ID=$4
	local COMMENT=$(urlencode "$5")

	curl -sS -D - \
		-A "${UA}" \
		-H "cookie: ${JD_COOKIE}" \
		-H "pragma: no-cache" \
		-H "cache-control: no-cache" \
		-H "accept: application/json" \
		-H "content-type: application/x-www-form-urlencoded" \
		-H "referer: https://comment.m.jd.com/" \
		-d "productId=${PRODUCT_ID}&orderId=${ORDER_ID}&content=${COMMENT}&userclient=29&imageJson=&videoid=" \
		--compressed "https://comment-api.jd.com/comment/appendComment?sceneval=2&g_login_type=1&g_ty=ajax" \
		-o "${RESP_BODY}"  \
		| tr -d '\r' \
		>"${RESP_HEADER}"
}

function fenci() {
	local MSG=$(urlencode "$1")

	curl -sS -D - \
		"http://www.pullwave.com:50001/get.php?source=${MSG}&param1=0.7&param2=2" \
		-A "${UA}" \
		-H 'Pragma: no-cache' \
		-H 'Cache-Control: no-cache' \
		-H 'Accept: application/json, text/plain, */*' \
		--compressed \
		--insecure \
		-o '/tmp/response_body_prod_fenci_cat' \
		>'/tmp/response_header_prod_fenci_cat'
	
	sleep 1

	curl -sS -D - \
		"http://api.pullword.com/get.php?source=${MSG}&param1=0.5&param2=2" \
		-A "${UA}" \
		-H 'Pragma: no-cache' \
		-H 'Cache-Control: no-cache' \
		-H 'Accept: application/json, text/plain, */*' \
		--compressed \
		--insecure \
		-o '/tmp/response_body_prod_fenci' \
		>'/tmp/response_header_prod_fenci'
}

function merge_comments() {
	local COMMENTS="$1"
	local PRODUCT="$2"
	local PRODUCT_CAT="$3"

	cat >"${COMMENTS}"<<EOF
评价晒单	考虑买这个${PRODUCT}之前我是有担心过的，因为我不知道${PRODUCT}的质量和品质怎么样，但是看了评论后我就放心了,	收到货后我非常的开心，因为${PRODUCT}的质量和品质真的非常的好！,	经过了这次愉快的购物，我决定如果下次我还要买${PRODUCT_CAT}的话，我一定会再来这家店买的。
评价晒单	买这个${PRODUCT}之前我是有看过好几家店，最后看到这家店的评价不错就决定在这家店买,	拆开包装后惊艳到我了，这就是我想要的${PRODUCT},	不错不错！。
评价晒单	看了好几家店，也对比了好几家店，最后发现还是这一家的${PRODUCT}评价最好,	快递超快！包装的很好！！很喜欢！！！,	我会推荐想买${PRODUCT}的朋友也来这家店里买。
评价晒单	看来看去最后还是选择了这家,	包装的很精美！${PRODUCT}的质量和品质非常不错！,	真是一次愉快的购物！
评价晒单	之前在这家店也买过其他东西，感觉不错，这次又来啦,	收到快递后迫不及待的拆了包装。${PRODUCT}我真的是非常喜欢,	大大的好评!以后买${PRODUCT_CAT}再来你们店！(￣▽￣)。
评价晒单	这家的${PRODUCT}真是太好用了，用了第一次就还想再用一次。	真是一次难忘的购物，这辈子没见过这么好用的东西！！	大家可以买来试一试，真的是太爽了，一晚上都沉浸在爽之中。
追加评价	用了这么久的${PRODUCT}, 东西是真的好用，真的难忘上一次购买时使用的激动，	东西还行,	推荐大家来尝试。
追加评价	使用了几天${PRODUCT},	确实是好东西，推荐大家购买,	这家店给我对于${PRODUCT}能做成这样刷新了世界观!。
追加评价	这是我买到的最好用的${PRODUCT},	${PRODUCT}的质量真的非常不错！,	真是一次愉快的购物！。
追加评价	我草，${PRODUCT}是真的好用啊，几天的体验下来，真是怀恋当初购买时下单的那一刻的激动!!!!!!!!!,	${PRODUCT}真是太好用了，真是个宝贝，难忘的宝贝!!,	以后买${PRODUCT_CAT}还来这家店，就没见过这么好用的东西！。
追加评价	我草，用了几天下来，${PRODUCT}变得好大好大，这精致的外观，这细腻的皮肤，摸上去，真是令人激动！,	${PRODUCT}短短几天的体验，令人一生难忘,	下次还来这家店买${PRODUCT_CAT}，就没见过这么牛逼的东西。
追加评价	${PRODUCT}这小家伙，真是太令人愉悦了，用了都说好好好好！	${PRODUCT}用了这么久了，它长的真是太可爱了,	东西很好，孩子很喜欢。
追加评价	不用睡不着觉，这家店的${PRODUCT}真是太好用了。	这可真是个小宝贝！,	现在睡觉都抱着${PRODUCT}睡觉，真是太好用了。
追加评价	真是牛逼啊，一天不用${PRODUCT}难受一天，用了${PRODUCT}一天难受一年！	五星好评，安排上，太好用拉！！！	令人难玩的一次购物。
EOF
}

function send_eval() {
	local RESP_HEADER=$1
	local RESP_BODY=$2
	local PRODUCT_ID=$3
	local ORDER_ID=$4
	local SCORE=$5
	local COMMENT=$(urlencode "$6")

	curl -sS -D - \
		-H "Cookie: ${JD_COOKIE}" \
		-A "${UA}" \
		-H "pragma: no-cache" \
		-H "cache-control: no-cache" \
		-H "accept: application/json" \
		-H "content-type: application/x-www-form-urlencoded" \
		-d "productId=${PRODUCT_ID}&orderId=${ORDER_ID}&score=${SCORE}&content=${COMMENT}&commentTagStr=1&userclient=29&imageJson=&anonymous=1&syncsg=0&scence=101100000&videoid=&URL=" \
		--compressed "https://comment-api.jd.com/comment/sendEval?sceneval=2&g_login_type=1&g_ty=ajax" \
		-o "${RESP_BODY}"  \
		| tr -d '\r' \
		>"${RESP_HEADER}"

}

function send_dsr() {
	local RESP_HEADER=$1
	local RESP_BODY=$2
	local PRODUCT_ID=$3
	local ORDER_ID=$4
	local O_TYPE=$5
	local DSR1=$6
	local DSR2=$7
	local DSR3=$8
	local TIME=$(date +%s%3N | tr -d '\n')

	curl -sS -D - \
		-A "${UA}" \
		-H "Cookie: ${JD_COOKIE}" \
		-H "pragma: no-cache" \
		-H "cache-control: no-cache" \
		--compressed "https://comment-api.jd.com/comment/sendDSR?pin=&userclient=29&orderId=${ORDER_ID}&otype=${O_TYPE}&DSR1=${DSR1}&DSR2=${DSR2}&DSR3=${DSR3}&_=${TIME}&sceneval=2&g_login_type=1" \
		-o "${RESP_BODY}"  \
		| tr -d '\r' \
		>"${RESP_HEADER}"
}

function ret_comment() {
	local COMMENT_RET_FILE="$1"
	local SKU_ID=$2

	local ERR=$(jq -r '.errMsg' 2>/dev/null <"${COMMENT_RET_FILE}")

	if [[ "${ERR}" == 'success' ]]; then
		echo "产品${SKU_ID}: $3成功!"
	else
		echo "产品${SKU_ID}: $3失败!"
		jq -r '.errMsg' 2>/dev/null <"${COMMENT_RET_FILE}"
	fi
}

function run_comments() {
	local JD_COOKIE="$1"
	local COMMENT_TYPE
	local SKU_ID
	local ORDER_ID
	local i

	SCORE=$(get_random $(echo $SCORE | awk -F ',' '{print $1}') $(echo $SCORE | awk -F ',' '{print $2}'))
	DSR1=$(get_random $(echo $DSR1 | awk -F ',' '{print $1}') $(echo $DSR1 | awk -F ',' '{print $2}'))
	DSR2=$(get_random $(echo $DSR2 | awk -F ',' '{print $1}') $(echo $DSR2 | awk -F ',' '{print $2}'))
	DSR3=$(get_random $(echo $DSR3 | awk -F ',' '{print $1}') $(echo $DSR3 | awk -F ',' '{print $2}'))

	echo "获取订单状态"
	get_order_status '/tmp/response_header_order_status' '/tmp/response_body_order_status'
	ret_code=$(jq -r '.ret_code' </tmp/response_body_order_status)
	err_msg=$(jq -r '.err_msg' </tmp/response_body_order_status)
	waitPayCount=$(jq -r '.waitPayCount' </tmp/response_body_order_status)
	waitPickCount=$(jq -r '.waitPickCount' </tmp/response_body_order_status)
	waitReceiveCount=$(jq -r '.waitReceiveCount' </tmp/response_body_order_status)
	waitGroupCount=$(jq -r '.waitGroupCount' </tmp/response_body_order_status)
	waitCommentCount=$(jq -r '.waitCommentCount' </tmp/response_body_order_status)
	waitReturnCashCount=$(jq -r '.waitReturnCashCount' </tmp/response_body_order_status)
	if [[ ${ret_code} -ne 0 ]]; then
		echo -e "错误： ${err_msg}"
		return 1
	fi
	echo "待付款：${waitPayCount} 待发货：${waitPickCount} 待收货：${waitReceiveCount} 待成团：${waitGroupCount} 待评论：${waitCommentCount} 待退款:${waitReturnCashCount}"

	echo
	echo -e "开始评价......"
	echo
	echo >/tmp/order_list
	i=1
	while :
	do
		get_order_list "/tmp/response_header_order_list${i}" "/tmp/response_body_order_list${i}" ${i}
		TOTAL_DEAL=$(jq -r '.totalDeal' </tmp/response_body_order_list${i})
		if [[ ${TOTAL_DEAL} -lt 10 ]]; then
			break
		fi
		jq -r '.' <"/tmp/response_body_order_list${i}" >>'/tmp/order_list'
		let i++
	done

	while read ORDER_ID && [[ -n "${ORDER_ID}" ]]
	do
		COMMENT_TYPE=$(jq -r '.orderList[] | select(.orderId=="'${ORDER_ID}'") | .buttonList[].name' <'/tmp/order_list' | grep "评价")
		if [[ "${COMMENT_TYPE}" == '查看评价' ]]; then continue; fi
		echo -e "订单号${ORDER_ID}: ${COMMENT_TYPE}"
		while read SKU_ID && [[ -n "${SKU_ID}" ]]
		do
			PRODUCT=$(jq -r '.orderList[] | select(.orderId=="'${ORDER_ID}'") | .productList[] | select(.skuId=="'${SKU_ID}'") | .title' <'/tmp/order_list')
			fenci "${PRODUCT}"
			if [[ -z "$(cat '/tmp/response_body_prod_fenci' | head -n 2 | tr -d '\n|\r' | grep -i 'html')" ]]; then
				PRODUCT=$(cat '/tmp/response_body_prod_fenci' | head -n 2 | tr -d '\n|\r')
				PRODUCT_CAT=$(jq -r '.class' <'/tmp/response_body_prod_fenci_cat' 2>/dev/null)
			fi

			O_TYPE=$(cat /tmp/order_list | grep "^.*ordertype=.*" | grep "orderid=${ORDER_ID}" | awk -F 'ordertype=' '{print $(NF)}' | sed "s/\".*$//g")
			merge_comments '/tmp/jd_comments' "${PRODUCT}" "${PRODUCT_CAT}"
			COMMENT1=$(cat '/tmp/jd_comments' | grep -i "^${COMMENT_TYPE}" | awk -F "\t" '{print $2}' | shuf -n 1)
			COMMENT2=$(cat '/tmp/jd_comments' | grep -i "^${COMMENT_TYPE}" | awk -F "\t" '{print $3}' | shuf -n 1)
			COMMENT3=$(cat '/tmp/jd_comments' | grep -i "^${COMMENT_TYPE}" | awk -F "\t" '{print $4}' | shuf -n 1)
			echo "产品${SKU_ID}: ${PRODUCT_CAT} ${PRODUCT}"
			case "${COMMENT_TYPE}" in
				评价晒单)
					echo -e "准备提交评价内容： ${COMMENT1}${COMMENT2}${COMMENT3}"
					echo "开始产品评价"
					send_eval '/tmp/response_header_send_eval' '/tmp/response_body_send_eval' "${SKU_ID}" "${ORDER_ID}" "${SCORE}" "${COMMENT1}${COMMENT2}${COMMENT3}"
					ret_comment '/tmp/response_body_send_eval' "${SKU_ID}" "产品评价"
					echo "开始服务评价"
					send_dsr '/tmp/response_header_send_dsr' '/tmp/response_body_send_dsr' "${SKU_ID}" "${ORDER_ID}" "${O_TYPE}" "${DSR1}" "${DSR2}" "${DSR3}"
					ret_comment '/tmp/response_body_send_dsr' "${SKU_ID}" "服务评价"
					;;
				评价服务)
					echo "开始服务评价"
					send_dsr '/tmp/response_header_send_dsr' '/tmp/response_body_send_dsr' "${SKU_ID}" "${ORDER_ID}" "${O_TYPE}" "${DSR1}" "${DSR2}" "${DSR3}"
					ret_comment '/tmp/response_body_send_dsr' "${SKU_ID}" "服务评价"
					;;
				追加评价)
					echo -e "准备提交评价内容： ${COMMENT1}${COMMENT2}${COMMENT3}"
					echo "开始追加评价"
					jd_append_comment '/tmp/response_header_append_comment' '/tmp/response_body_append_comment' "${SKU_ID}" "${ORDER_ID}" "${COMMENT1}${COMMENT2}${COMMENT3}"
					ret_comment '/tmp/response_body_append_comment' "${SKU_ID}" "追加评价"
					;;
				查看评价) continue;;
				*) continue;;
			esac
			echo
			# echo "等待${WAIT}秒"
			sleep ${WAIT}
			PRODUCT=
			PRODUCT_CAT=
		done <<<$(jq -r '.orderList[] | select(.orderId=="'${ORDER_ID}'")  | .productList[].skuId' <'/tmp/order_list' | uniq)

	done <<< $(jq -r '.orderList[] | select (.buttonList[].name!="查看评价") | .orderId' <'/tmp/order_list' | uniq)
}

function main() {
	local LINE
	local ENV_JD_COOKIE
	local PT_PIN
	local i=1

	START_TIME=$(date +%s)
	ENV_JD_COOKIE=$(env | grep JD_COOKIE= | sed "s/^JD_COOKIE=//g")
	if [[ -n "${JD_COOKIE}" ]]; then
		ENV_JD_COOKIE="${JD_COOKIE}"
	fi

	while read LINE && [[ -n "${LINE}" ]]
	do
		PT_PIN=$(echo "${JD_COOKIE}" | sed "s/\&/\\n/g" | awk -F 'pt_pin=' '{print $(NF)}' | sed "s/;.*$//g")
		echo "$(date)	开始执行京东账号${i}: ${PT_PIN} 自动评价任务"
		run_comments "${LINE}"
		let i++
	done <<<$(echo "${ENV_JD_COOKIE}" | sed "s/\&/\\n/g")

	STOP_TIME=$(date +%s)
	echo "$(date)	任务完成, 总耗时$((${STOP_TIME} - ${START_TIME}))秒"
}

main