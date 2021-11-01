#!/bin/bash

echo
echo "请输入您的前端网址域名[比如：sub.v2rayssr.com]"
read -p " 请输入您的前端网址域名：" wzym
export wzym=${wzym}
echo "您的前端网址域名为：${wzym}"
echo
echo
echo "请输入您的后端服务地址域名[比如：suc.v2rayssr.com]"
read -p " 请输入您的后端服务地址域名：" fwym
export fwym=${fwym}
echo "您的后台地址为：${fwym}"
echo
cat >/root/sub_suc <<-EOF
wzym=${wzym}
fwym=${fwym}
EOF
apt-get update
apt-get install -y curl wget sudo git
curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -
sudo apt-get install -y nodejs
if [[ `node --version |egrep -o "v[0-9]+\.[0-9]+\.[0-9]+"` ]]; then
	echo ""
else
	echo "node安装失败!"
  exit 1
fi
if [[ `npm --version |egrep -o "[0-9]+\.[0-9]+\.[0-9]+"` ]]; then
	echo ""
else
	echo "npm安装失败!"
  exit 1
fi
npm install -g yarn
if [[ `yarn --version |egrep -o "[0-9]+\.[0-9]+\.[0-9]+"` ]]; then
	echo ""
else
	echo "yarn安装失败!"
  exit 1
fi
rm -fr sub-web && git clone https://github.com/CareyWang/sub-web.git
if [[ $? -ne 0 ]];then
	echo "sub-web下载失败!"
	exit 1
else
	cd sub-web
	yarn install
	yarn serve
fi
exit 0
