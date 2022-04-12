#!/bin/bash

# 字体颜色配置
Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
Blue="\033[36m"
Font="\033[0m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
OK="${Green}[OK]${Font}"
ERROR="${Red}[ERROR]${Font}"

function print_ok() {
  echo
  echo -e " ${OK} ${Blue} $1 ${Font}"
  echo
}
function print_error() {
  echo
  echo -e "${ERROR} ${RedBG} $1 ${Font}"
  echo
}
function ECHOY()
{
  echo
  echo -e "${Yellow} $1 ${Font}"
  echo
}
function ECHOG()
{
  echo
  echo -e "${Green} $1 ${Font}"
  echo
}
judge() {
  if [[ 0 -eq $? ]]; then
    print_ok "$1 完成"
    sleep 1
  else
    print_error "$1 失败"
    exit 1
  fi
}

if [[ ! "$USER" == "root" ]]; then
  print_error "警告：请使用root用户操作!~~"
  exit 1
fi

function system_check() {
  clear
  echo
  echo -e "\033[33m 请输入您的域名或当前服务器IP \033[0m"
  read -p " 您当前域名/服务器IP：" wzym
  export wzym="${wzym}"
  echo -e "\033[32m 您当前域名/服务器IP为：${wzym} \033[0m"
  echo

  ECHOY "正在安装各种必须依赖"
  echo
  if [[ "$(. /etc/os-release && echo "$ID")" == "centos" ]]; then
    yum install -y nodejs wget sudo git npm lsof
    wget -N -P /etc/yum.repos.d/ https://ghproxy.com/https://raw.githubusercontent.com/281677160/agent/main/xray/nginx.repo
    curl -sL https://rpm.nodesource.com/setup_12.x | bash -
    npm install -g yarn
  elif [[ "$(. /etc/os-release && echo "$ID")" == "alpine" ]]; then
    apk update
    apk del yarn nginx nodejs
    apk add git yarn sudo wget nginx lsof
    apk add  --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/v3.10/main/ nodejs
  elif [[ "$(. /etc/os-release && echo "$ID")" == "ubuntu" ]]; then
    export INS="apt-get install -y"
    export UNINS="apt-get remove -y"
    export PUBKEY="ubuntu"
    nodejs_install
  elif [[ "$(. /etc/os-release && echo "$ID")" == "debian" ]]; then
    export INS="apt install -y"
    export UNINS="apt remove -y"
    export PUBKEY="debian"
    nodejs_install
  else
    echo -e "\033[31m 不支持该系统 \033[0m"
    exit 1
  fi
}

function nodejs_install() {
    apt update
    ${INS} curl wget sudo git lsof lsb-release gnupg2
    ${UNINS} --purge npm
    ${UNINS} --purge nodejs
    ${UNINS} --purge nodejs-legacy
    apt autoremove -y
    curl -sL https://deb.nodesource.com/setup_12.x | sudo bash -
    ${UNINS} cmdtest
    ${UNINS} yarn
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
    rm -f /etc/apt/sources.list.d/nginx.list
    echo "deb http://nginx.org/packages/${PUBKEY} $(lsb_release -cs) nginx" >/etc/apt/sources.list.d/nginx.list
    curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add -
    apt-get update
    ${INS} nodejs yarn
}

function nginx_install() {
  if ! command -v nginx >/dev/null 2>&1; then
    ${INS} nginx
    judge "Nginx 安装"
  else
    print_ok "Nginx 已存在"
    ${INS} nginx
  fi
  
  if [[ -d /etc/nginx/sites-available ]]; then
    sub_path="/etc/nginx/sites-available/${wzym}.conf"
  elif [[ -d /etc/nginx/http.d ]]; then  
    sub_path="/etc/nginx/http.d/${wzym}.conf"
  else
    mkdir -p /etc/nginx/conf.d >/dev/null 2>&1
    sub_path="/etc/nginx/conf.d/${wzym}.conf"
  fi
cat >"${sub_path}" <<-EOF
server {
    listen 80;
    server_name ${wzym};

    root /www/dist;
    index index.html index.htm;

    error_page 404 /index.html;

    gzip on; #开启gzip压缩
    gzip_min_length 1k; #设置对数据启用压缩的最少字节数
    gzip_buffers 4 16k;
    gzip_http_version 1.0;
    gzip_comp_level 6; #设置数据的压缩等级,等级为1-9，压缩比从小到大
    gzip_types text/plain text/css text/javascript application/json application/javascript application/x-javascript application/xml; #设置需要压缩的数据格式
    gzip_vary on;

    location ~* \.(css|js|png|jpg|jpeg|gif|gz|svg|mp4|ogg|ogv|webm|htc|xml|woff)$ {
        access_log off;
        add_header Cache-Control "public,max-age=30*24*3600";
    }
}
EOF
  service nginx restart
}

function command_Version() {
  if [[ ! -x "$(command -v node)" ]]; then
    print_error "node安装失败!"
    exit 1
  else
    node_version="$(node --version |egrep -o 'v[0-9]+\.[0-9]+\.[0-9]+')"
    print_ok "node版本号为：${node_version}"
  fi
  if [[ ! -x "$(command -v yarn)" ]]; then
    print_error "yarn安装失败!"
    exit 1
  else
    yarn_version="$(yarn --version |egrep -o '[0-9]+\.[0-9]+\.[0-9]+')"
    echo "yarn版本号为：${yarn_version}"
  fi
  nginxVersion="$(nginx -v 2>&1)" && NGINX_VERSION="$(echo ${nginxVersion#*/})"
  print_ok "Nginx版本号为：${NGINX_VERSION}"
}

function system_docker() {
  if [[ ! -x "$(command -v docker)" ]]; then
    ECHOY "没检测到docker，正在安装docker"
    bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/281677160/ql@main/docker.sh)"
  fi
}

function systemctl_status() {
  echo
  ECHOG "检测docker是否在运行"
  if [[ "$(. /etc/os-release && echo "$ID")" == "alpine" ]]; then
    service docker start
    if [[ `docker version |grep -c "runc"` == '1' ]]; then
      print_ok "docker正在运行中!"
    else
      print_error "docker没有启动，请先启动docker，或者检查一下是否安装失败"
      sleep 1
      exit 1
    fi
  else  
    if [[ `systemctl status docker |grep -c "active (running) "` == '1' ]]; then
      print_ok "docker正在运行中!"
    else
      print_error "docker没有启动，请先启动docker，或者检查一下是否安装失败"
      sleep 1
      exit 1
    fi
  fi
}

function port_exist_check() {
  if [[ 0 -eq $(lsof -i:"25500" | grep -i -c "listen") ]]; then
    print_ok "25500 端口未被占用"
    sleep 1
  else
    print_error "检测到 25500 端口被占用，以下为 25500 端口占用信息"
    lsof -i:"25500"
    print_error "5s 后将尝试自动 kill 占用进程"
    sleep 5
    lsof -i:"25500" | awk '{print $2}' | grep -v "PID" | xargs kill -9
    print_ok "kill 完成"
    sleep 1
  fi
}

function install_subconverter() {
  find / -name 'subconverter' 2>&1 | xargs -i rm -rf {}
  if [[ `docker images | grep -c "subconverter"` -ge '1' ]] || [[ `docker ps -a | grep -c "subconverter"` -ge '1' ]]; then
    ECHOY "检测到subconverter服务存在，正在御载subconverter服务，请稍后..."
    dockerid="$(docker ps -a |grep 'subconverter' |awk '{print $1}')"
    imagesid="$(docker images |grep 'subconverter' |awk '{print $3}')"
    docker stop -t=5 "${dockerid}" > /dev/null 2>&1
    docker rm "${dockerid}"
    docker rmi "${imagesid}"
    if [[ `docker ps -a | grep -c "subconverter"` == '0' ]] && [[ `docker images | grep -c "qinglong"` == '0' ]]; then
      print_ok "subconverter御载完成"
    else
      print_error "subconverter御载失败"
      exit 1
    fi
  fi
  ECHOY "正在安装subconverter服务"
  docker run -d --restart=always -p 25500:25500 tindy2013/subconverter:latest
  if [[ `docker images | grep -c "subconverter"` -ge '1' ]] && [[ `docker ps -a | grep -c "subconverter"` -ge '1' ]]; then
    print_ok "subconverter安装完成"
  else
    print_error "subconverter安装失败"
    exit 1
  fi
}

function install_subweb() {
  ECHOY "正在安装sub-web服务"
  rm -fr sub-web && git clone https://ghproxy.com/https://github.com/CareyWang/sub-web.git sub-web
  if [[ $? -ne 0 ]];then
    echo -e "\033[31m sub-web下载失败! \033[0m"
    exit 1
  else
    wget -q https://ghproxy.com/https://raw.githubusercontent.com/281677160/agent/main/Subconverter.vue -O /root/sub-web/src/views/Subconverter.vue
    if [[ $? -ne 0 ]]; then
      curl -fsSL https://cdn.jsdelivr.net/gh/281677160/agent@main/Subconverter.vue > "/root/sub-web/src/views/Subconverter.vue"
    fi
    wget -q https://ghproxy.com/https://raw.githubusercontent.com/281677160/agent/main/xray/clsah.env -O /root/sub-web/.env
    if [[ $? -ne 0 ]]; then
      curl -fsSL https://cdn.jsdelivr.net/gh/281677160/agent@main/xray/clsah.env > "/root/sub-web/.env"
    fi
    cd sub-web
    sed -i "s?http://127.0.0.1:25500?http://${wzym}:25500?g" "/root/sub-web/.env"
    sed -i "s?http://127.0.0.1:25500/sub?http://${wzym}:25500/sub?g" "/root/sub-web/src/views/Subconverter.vue"
    yarn install
    yarn build
    if [[ -d /root/sub-web/dist ]]; then
      [[ ! -d /www/dist ]] && mkdir -p /www/dist || rm -rf /www/dist/*
      cp -R /root/sub-web/dist/* /www/dist/
    else
      print_error "生成页面文件失败"
      exit 1
    fi
  fi

  print_ok "sub-web安装完成"
  
  if [[ `service docker status |grep -c "status"` == '1' ]]; then
    print_ok "docker正在运行"
  else
    print_error "docker没有运行，安装失败"
    exit 1
  fi
  
  if [[ `service nginx status |grep -c "status"` == '1' ]]; then
    print_ok "nginx正在运行"
  else
    print_error "nginx没有运行，安装失败"
    exit 1
  fi
    
  if [[ $(lsof -i:"25500" | grep -i -c "listen") -ge "1" ]]; then
    print_ok "subconverter服务正在运行"
  else
    print_error "subconverter服务没有运行，安装失败"
    exit 1
  fi
    
  ECHOY "全部服务安装完毕,请登录 http://${wzym} 进行使用"
}

menu() {
  system_check
  nginx_install
  command_Version
  system_docker
  systemctl_status
  port_exist_check
  install_subconverter
  install_subweb
}
menu "$@"
