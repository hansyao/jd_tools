# QQ扫码获取京东cookie

>一个简单的纯shell脚本实现的QQ扫码获取京东cookie的小工具


## 食用方法

```bash
curl -sOL https://raw.githubusercontent.com/hansyao/jd_tools/master/jd_qq_login.sh
bash jd_qq_login.sh	#运行后显示二维码后用手机/平板的QQ客户端扫码即可
```

## 必须条件
需要京东账号绑定了QQ才能用

## 限制条件
1. cookie有效期： 一个月
2. 暂不支持手机验证，如果碰见触发京东安全检测需要二次验证的情况，请稍后重试
3. 支持远程验证，实测即使部署在海外VPS上也可在国内本地QQ扫码登录正确拿到cookie

## 安全性
代码全部开源，脚本除了验证需要向腾讯和京东发送必要信息外，不会向第三方提交任何数据。但脚本写入到临时文件夹/tmp/的数据为了调试需要因此没有自动删除，建议使用完毕后自己手动清空一下`rm -rf /tmp/*`。

## 依赖环境

1. jq
2. zbar
3. qrencode

如果系统缺少依赖，脚本会自动安装，支持apt/yum/dnf自动安装依赖环境，如果没有这几个包管理环境，需要手动安装以上依赖。
