#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN='\033[0m'

red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}

green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}

REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'" "fedora")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Fedora")
PACKAGE_UPDATE=("apt-get update" "apt-get update" "yum -y update" "yum -y update" "yum -y update")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "yum -y install")
PACKAGE_REMOVE=("apt -y remove" "apt -y remove" "yum -y remove" "yum -y remove" "yum -y remove")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove" "yum -y autoremove")

CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
    SYS="$i"
    if [[ -n $SYS ]]; then
        break
    fi
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
    if [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]]; then
        SYSTEM="${RELEASE[int]}" && [[ -n $SYSTEM ]] && break
    fi
done

[[ -z $SYSTEM ]] && red "不支持当前VPS系统, 请使用主流的操作系统" && exit 1

check_ip(){
    ipv4=$(curl -s4m8 ip.sb -k | sed -n 1p)
    ipv6=$(curl -s6m8 ip.sb -k | sed -n 1p)
}

install_acme(){
    if [[ ! $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_UPDATE[int]}
    fi
    ${PACKAGE_INSTALL[int]} curl wget sudo socat openssl

    if [[ $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_INSTALL[int]} cronie
        systemctl start crond
        systemctl enable crond
    else
        ${PACKAGE_INSTALL[int]} cron
        systemctl start cron
        systemctl enable cron
    fi

    read -rp "请输入注册邮箱 (例: admin@gmail.com, 或留空自动生成一个gmail邮箱): " email
    if [[ -z $email ]]; then
        automail=$(date +%s%N | md5sum | cut -c 1-16)
        email=$automail@gmail.com
        yellow "已取消设置邮箱, 使用自动生成的gmail邮箱: $email"
    fi

    curl https://get.acme.sh | sh -s email=$email
    source ~/.bashrc
    bash ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    
    switch_provider

    if [[ -n $(~/.acme.sh/acme.sh -v 2>/dev/null) ]]; then
        green "acme.sh 证书一键申请脚本安装成功!"
    else
        red "抱歉, acme.sh 证书一键申请脚本安装失败"
        green "建议如下："
        yellow "1. 检查 VPS 的网络环境"
        yellow "2. 脚本可能跟不上时代, 建议截图发布到 GitHub Issues 询问"
    fi
}

uninstall_acme() {
    ~/.acme.sh/acme.sh --uninstall
    sed -i '/--cron/d' /etc/crontab >/dev/null 2>&1
    rm -rf ~/.acme.sh
    green "acme.sh 证书一键申请脚本已彻底卸载!"
}

check_80(){
    if [[ -z $(type -P lsof) ]]; then
        if [[ ! $SYSTEM == "CentOS" ]]; then
            ${PACKAGE_UPDATE[int]}
        fi
        ${PACKAGE_INSTALL[int]} lsof
    fi
    
    yellow "正在检测 80 端口是否占用..."
    sleep 1
    
    if [[  $(lsof -i:"80" | grep -i -c "listen") -eq 0 ]]; then
        green "检测到目前 80 端口未被占用"
        sleep 1
    else
        red "检测到目前 80 端口被其他程序被占用，以下为占用程序信息"
        lsof -i:"80"
        read -rp "如需结束占用进程请按Y，按其他键则退出 [Y/N]: " yn
        if [[ $yn =~ "Y"|"y" ]]; then
            lsof -i:"80" | awk '{print $2}' | grep -v "PID" | xargs kill -9
            sleep 1
        else
            exit 1
        fi
    fi
}

checktls() {
    local cert_path="/usr/local/etc/acme" 
    if [[ -f /usr/local/etc/acme/$domain.crt && -f /usr/local/etc/acme/$domain.key ]]; then
        if [[ -s /usr/local/etc/acme/$domain.crt && -s /usr/local/etc/acme/$domain.key ]]; then
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                wg-quick up wgcf >/dev/null 2>&1
            fi
            if [[ -a "/opt/warp-go/warp-go" ]]; then
                systemctl start warp-go 
            fi

            echo $domain > /usr/local/etc/acme/ca.log
            sed -i '/--cron/d' /etc/crontab >/dev/null 2>&1
            echo "0 0 * * * root bash /root/.acme.sh/acme.sh --cron -f >/dev/null 2>&1" >> /etc/crontab
            echo "证书申请成功!"
            yellow "crt文件路径: $cert_path/$domain.crt"
            yellow "key文件路径: $cert_path/$domain.key"
        else
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                wg-quick up wgcf >/dev/null 2>&1
            fi
            if [[ -a "/opt/warp-go/warp-go" ]]; then
                systemctl start warp-go 
            fi

            red "证书申请失败"
            green "建议如下: "
            yellow "1. 自行检测防火墙是否打开, 如使用 80 端口申请模式时, 请关闭防火墙或放行 80 端口并检测是否关闭小黄云"
            yellow "2. 同一域名多次申请可能会触发 Let's Encrypt 官方风控, 请尝试使用脚本菜单的 9 选项更换证书颁发机构, 再重试申请证书, 或更换域名、或等待 7 天后再尝试执行脚本"
        fi
    fi
}

acme_cert_apply() {
  local acme_folder="/usr/local/etc/acme"      
  [[ ! -d "$acme_folder" ]] && mkdir -p "$acme_folder"
  [[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && install_acme
  acme_standalone
}

acme_standalone(){
    check_80
    WARPv4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    WARPv6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    if [[ $WARPv4Status =~ on|plus ]] || [[ $WARPv6Status =~ on|plus ]]; then
        wg-quick down wgcf >/dev/null 2>&1
        systemctl stop warp-go >/dev/null 2>&1
    fi
    
    check_ip
    
    echo ""
    yellow "在使用80端口申请模式时, 请先将您的域名解析至你的VPS的真实IP地址, 否则会导致证书申请失败"
    echo ""
    if [[ -n $ipv4 && -n $ipv6 ]]; then
        echo -e "VPS的真实IPv4地址为: ${GREEN}$ipv4${PLAIN}"
        echo -e "VPS的真实IPv6地址为: ${GREEN}$ipv6${PLAIN}"
    elif [[ -n $ipv4 && -z $ipv6 ]]; then
        echo -e "VPS的真实IPv4地址为: ${GREEN}$ipv4${PLAIN}"
    elif [[ -z $ipv4 && -n $ipv6 ]]; then
        echo -e "VPS的真实IPv6地址为: ${GREEN}$ipv6${PLAIN}"
    fi
    echo ""

    read -rp "请输入解析完成的域名: " domain
    [[ -z $domain ]] && red "未输入域名，无法执行操作！" && exit 1
    green "已输入的域名：$domain" && sleep 1

    domainIP=$(curl -sm8 ipget.net/?ip="${domain}")
    
    if [[ $domainIP == $ipv6 ]]; then
        bash ~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-256 --listen-v6 --insecure
    fi
    if [[ $domainIP == $ipv4 ]]; then
        bash ~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-256 --insecure
    fi
    
    if [[ -n $(echo $domainIP | grep nginx) ]]; then
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            wg-quick up wgcf >/dev/null 2>&1
        fi
        if [[ -a "/opt/warp-go/warp-go" ]]; then
            systemctl start warp-go 
        fi
        yellow "域名解析失败, 请检查域名是否正确填写或等待解析完成再执行脚本"
        exit 1
    elif [[ -n $(echo $domainIP | grep ":") || -n $(echo $domainIP | grep ".") ]]; then
        if [[ $domainIP != $ipv4 ]] && [[ $domainIP != $ipv6 ]]; then
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                wg-quick up wgcf >/dev/null 2>&1
            fi
            if [[ -a "/opt/warp-go/warp-go" ]]; then
                systemctl start warp-go 
            fi
            green "域名 ${domain} 目前解析的IP: ($domainIP)"
            red "当前域名解析的 IP 与当前 VPS 使用的真实IP不匹配"
            green "建议如下："
            yellow "1. 请确保 CloudFlare 小云朵为关闭状态 (仅限DNS), 其他域名解析或 CDN 网站设置同理"
            yellow "2. 请检查 DNS 解析设置的 IP 是否为 VPS 的真实 IP"
            yellow "3. 脚本可能跟不上时代, 建议截图发布到 GitHub Issues、GitLab Issues、论坛或 TG 群询问"
            exit 1
        fi
    fi
    
    bash ~/.acme.sh/acme.sh --install-cert -d ${domain} --key-file /usr/local/etc/acme/$domain.key --fullchain-file /usr/local/etc/acme/$domain.crt --ecc
    checktls
}

check_cert(){
    bash ~/.acme.sh/acme.sh --list
}

revoke_cert() {
    bash ~/.acme.sh/acme.sh --list
    read -rp "请输入要撤销的域名证书 (复制 Main_Domain 下显示的域名): " domain
    [[ -z $domain ]] && red "未输入域名，无法执行操作!" && exit 1

    if [[ -n $(bash ~/.acme.sh/acme.sh --list | grep $domain) ]]; then
        bash ~/.acme.sh/acme.sh --revoke -d ${domain} --ecc
        bash ~/.acme.sh/acme.sh --remove -d ${domain} --ecc

        rm -rf ~/.acme.sh/${domain}_ecc
        rm -f /usr/local/etc/acme/$domain.crt /usr/local/etc/acme/$domain.key

        green "撤销 ${domain} 的域名证书成功"
    else
        red "未找到 ${domain} 的域名证书, 请检查后重新运行!"
    fi
}

renew_cert() {
    bash ~/.acme.sh/acme.sh --cron -f
}

switch_provider(){
    yellow "请选择证书提供商, 默认通过 Letsencrypt.org 来申请证书 "
    yellow "如果证书申请失败, 例如一天内通过 Letsencrypt.org 申请次数过多, 可选 BuyPass.com 或 ZeroSSL.com 来申请."
    echo -e " ${GREEN}1.${PLAIN} Letsencrypt.org ${YELLOW}(默认)${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} BuyPass.com"
    echo -e " ${GREEN}3.${PLAIN} ZeroSSL.com"
    read -rp "请选择证书提供商 [1-3]: " provider
    case $provider in
        2) bash ~/.acme.sh/acme.sh --set-default-ca --server buypass && green "切换证书提供商为 BuyPass.com 成功！" ;;
        3) bash ~/.acme.sh/acme.sh --set-default-ca --server zerossl && green "切换证书提供商为 ZeroSSL.com 成功！" ;;
        *) bash ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt && green "切换证书提供商为 Letsencrypt.org 成功！" ;;
    esac
}

select_sing_box_install_option() {
    create_sing_box_folder

    while true; do
        echo "请选择 sing-box 的安装方式（默认1）："
        echo "1). 下载安装 sing-box（Latest 版本）"
        echo "2). 下载安装 sing-box（Beta 版本）"

        local install_option
        read -p "请选择 [1-2]: " install_option
        install_option="${install_option:-1}"

        case $install_option in
            1)
                install_latest_sing_box
                break
                ;;
            2)
                install_Pre_release_sing_box
                break
                ;;                
            *)
                echo -e "${RED}无效的选择，请重新输入！${NC}"
                ;;
        esac
    done
}

install_latest_sing_box() {
    local arch=$(uname -m)
    echo "arc $arch"
    local url="https://api.github.com/repos/SagerNet/sing-box/releases/latest"
    local download_url

    case $arch in
        x86_64|amd64)
            download_url=$(curl -s $url | grep -o "https://github.com[^\"']*linux-amd64.tar.gz")
            ;;
        armv7l)
            download_url=$(curl -s $url | grep -o "https://github.com[^\"']*linux-armv7.tar.gz")
            ;;
        aarch64|arm64)
            download_url=$(curl -s $url | grep -o "https://github.com[^\"']*linux-arm64.tar.gz")
            ;;
        amd64v3)
            download_url=$(curl -s $url | grep -o "https://github.com[^\"']*linux-amd64v3.tar.gz")
            ;;
        s390x)
            download_url=$(curl -s $url | grep -o "https://github.com[^\"']*linux-s390x.tar.gz")
            ;;            
        *)
            echo -e "${RED}不支持的架构：$arch${NC}"
            return 1
            ;;
    esac

    if [ -n "$download_url" ]; then
        echo "Downloading Sing-Box..."
        wget -qO sing-box.tar.gz "$download_url" 2>&1 >/dev/null
        tar -xzf sing-box.tar.gz -C /usr/local/bin --strip-components=1
        rm sing-box.tar.gz
        chmod +x /usr/local/bin/sing-box
        configure_sing_box_service
        echo "Sing-Box installed successfully."
    else
        echo -e "${RED}Unable to retrieve the download URL for Sing-Box.${NC}"
        return 1
    fi
}

install_Pre_release_sing_box() {
    local arch=$(uname -m)
    local url="https://api.github.com/repos/SagerNet/sing-box/releases"
    local download_url

    case $arch in
        x86_64|amd64)
            download_url=$(curl -s "$url" | jq -r '.[] | select(.prerelease == true) | .assets[] | select(.browser_download_url | contains("linux-amd64.tar.gz")) | .browser_download_url' | head -n 1)
            ;;
        armv7l)
            download_url=$(curl -s "$url" | jq -r '.[] | select(.prerelease == true) | .assets[] | select(.browser_download_url | contains("linux-armv7.tar.gz")) | .browser_download_url' | head -n 1)
            ;;
        aarch64|arm64)
            download_url=$(curl -s "$url" | jq -r '.[] | select(.prerelease == true) | .assets[] | select(.browser_download_url | contains("linux-arm64.tar.gz")) | .browser_download_url' | head -n 1)
            ;;
        amd64v3)
            download_url=$(curl -s "$url" | jq -r '.[] | select(.prerelease == true) | .assets[] | select(.browser_download_url | contains("linux-amd64v3.tar.gz")) | .browser_download_url' | head -n 1)
            ;;
        s390x)
            download_url=$(curl -s "$url" | jq -r '.[] | select(.prerelease == true) | .assets[] | select(.browser_download_url | contains("linux-s390x.tar.gz")) | .browser_download_url' | head -n 1)
            ;;            
        *)
            echo -e "${RED}不支持的架构：$arch${NC}"
            return 1
            ;;
    esac

    if [ -n "$download_url" ]; then
        echo "Downloading Sing-Box..."
        wget -qO sing-box.tar.gz "$download_url" 2>&1 >/dev/null
        tar -xzf sing-box.tar.gz -C /usr/local/bin --strip-components=1
        rm sing-box.tar.gz
        chmod +x /usr/local/bin/sing-box
        configure_sing_box_service
        echo "Sing-Box installed successfully."
    else
        echo -e "${RED}Unable to get pre-release download link for Sing-Box.${NC}"
        return 1
    fi
}

create_sing_box_folder() {
    local folder="/usr/local/etc/sing-box"
    [[ ! -d "$folder" ]] && mkdir -p "$folder"
    [[ ! -f "$folder/config.json" ]] && touch "$folder/config.json"
}

acme_cert_manage() {
    [[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && yellow "未安装acme.sh" && exit 1
    echo -e " ${GREEN}1.${PLAIN} 查看已申请的证书"
    echo -e " ${GREEN}2.${PLAIN} 撤销并删除已申请的证书"
    echo -e " ${GREEN}3.${PLAIN} 手动续期已申请的证书"
    echo -e " ${GREEN}4.${PLAIN} 切换证书颁发机构"
    echo -e " ${RED}5. 卸载acme.sh${PLAIN}"
    read -rp "请输入选项 [1-5]: " choice
    case "$choice" in
        1 ) check_cert ;;
        2 ) revoke_cert ;;
        3 ) renew_cert ;;
        4 ) switch_provider ;;
        5 ) uninstall_acme ;;
        * ) echo -e "${RED}无效的选择，请重新输入！${PLAIN}" ;;
    esac
}

self_sign_cert() {
    read -p "请输入要签证的域名 (例如: example.com): " DOMAIN_NAME
    if [ -z "$DOMAIN_NAME" ]; then
        echo "错误：域名不能为空。"
        exit 1
    fi
    CERT_PATH=""
    while [ -z "$CERT_PATH" ] || [ ! -d "$CERT_PATH" ]; do
        read -p "请输入证书保存路径（必须为已存在的目录，按回车键确认，默认路径为 /usr/local/etc/cert）: " CERT_PATH
        if [ -z "$CERT_PATH" ]; then
            mkdir -p /usr/local/etc/cert
            CERT_PATH="/usr/local/etc/cert"
        fi
        if [ ! -d "$CERT_PATH" ]; then
            echo "错误：指定的路径 '$CERT_PATH' 不存在，请重新输入。"
        fi
    done
    openssl ecparam -genkey -name prime256v1 -out "$CERT_PATH/$DOMAIN_NAME.key"
    openssl req -new -x509 -days 3650 -key "$CERT_PATH/$DOMAIN_NAME.key" -out "$CERT_PATH/$DOMAIN_NAME.crt" -subj "/CN=$DOMAIN_NAME"

    echo "SSL证书和私钥已生成并保存在 $CERT_PATH 目录下"
    yellow "crt文件路径如下: $CERT_PATH/$DOMAIN_NAME.crt"
    yellow "key文件路径如下: $CERT_PATH/$DOMAIN_NAME.key"
}

uninstall_sing_box() {
    echo "开始卸载 sing-box..."
    systemctl stop sing-box
    systemctl disable sing-box
    rm -rf /usr/local/bin/sing-box
    rm -rf /usr/local/etc/sing-box
    rm -rf /etc/systemd/system/sing-box.service
    systemctl daemon-reload
    echo "sing-box 卸载完成。"
}

update_script() {
    wget -O /root/singbox.sh https://raw.githubusercontent.com/TinrLin/script_installation/main/Install.sh
    chmod +x /root/singbox.sh 
}

get_sing_box_version() {
    local folder="/usr/local/etc/sing-box"
    local version_file="$folder/version.txt"
    [[ ! -d "$folder" ]] && mkdir -p "$folder"
    if [[ ! -f "$version_file" ]]; then
        sing-box version > "$version_file"
    fi
    sed -i '1s/.*/'"$(yellow "$(head -n 1 "$version_file")")"'/g' "$version_file"
    cat "$version_file"
}

configure_sing_box_service() {
    echo "Configuring sing-box startup service..."
    local service_file="/etc/systemd/system/sing-box.service"

    if [[ -f $service_file ]]; then
        rm "$service_file"
    fi
    
    local service_config='[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=/usr/local/bin/sing-box run -c /usr/local/etc/sing-box/config.json
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target'

    echo "$service_config" >"$service_file"
    echo "sing-box startup service has been configured."
}

menu() {
  get_sing_box_version
  echo "---------------------------------------------------------------"
  echo -e " ${GREEN}1.${PLAIN} 安装/更新sing-box"
  echo -e " ${GREEN}2.${PLAIN} acme申请证书"
  echo -e " ${GREEN}3.${PLAIN} acme证书管理"
  echo -e " ${GREEN}4.${PLAIN} 自签证书"
  echo -e " ${RED}5. 卸载sing-box${PLAIN}"
  echo -e " ${GREEN}6.${PLAIN} 更新脚本"
  echo -e " ${GREEN}0.${PLAIN} 退出脚本"
  echo "---------------------------------------------------------------"
  read -rp "请输入选项 [0-6]: " menuInput
  case "$menuInput" in
    1 ) select_sing_box_install_option ;;
    2 ) acme_cert_apply ;;
    3 ) acme_cert_manage ;;
    4 ) self_sign_cert ;;
    5 ) uninstall_sing_box ;;
    6 ) update_script ;;
    * ) exit 0 ;;
  esac
}

menu

