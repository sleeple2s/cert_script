#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
NC='\033[0m'

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

#安装/更行sing-box
select_sing_box_install_option() {
    echo ""
    echo "请选择 sing-box 的安装版本(默认1)： "
    echo -e "${GREEN}1 ${NC} 下载安装 sing-box(Latest 版本)"
    echo -e "${GREEN}2 ${NC} 下载安装 sing-box(Beta 版本)"
    echo -e "${GREEN}0 ${NC} 退出 "

    read -p "请选择 [0-2]: " install_option
    install_option="${install_option:-1}"
    case $install_option in
        1)
            install_latest_sing_box
            exit 0
            ;;
        2)
            install_Pre_release_sing_box
            exit 0
            ;;
        0)
            menu
            exit 0
            ;;            
        *)
            echo -e " ${RED}无效的选择,请重新输入！${NC} "
            select_sing_box_install_option
            ;;
    esac
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
        check_install_type
        echo "Sing-Box installed successfully"
    else
        echo -e "${RED}Unable to retrieve the download URL for Sing-Box${NC}"
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
        check_install_type
        echo "Sing-Box installed successfully"
    else
        echo -e "${RED}Unable to get pre-release download link for Sing-Box${NC}"
        return 1
    fi
}

check_install_type() {
    local folder="/usr/local/etc/sing-box"
    if [ -d "$folder" ]; then
        rm "/usr/local/etc/sing-box/version.txt"
        systemctl daemon-reload   
        systemctl enable sing-box
        systemctl start sing-box
        systemctl restart sing-box
    else
        mkdir -p "$folder" && touch "$folder/config.json"
        configure_sing_box_service
        systemctl daemon-reload   
        systemctl enable sing-box
    fi
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
    echo "sing-box startup service has been configured"
}

#安装/管理warp
install_warp() {
    local config_file="/etc/wireguard/warp.conf"
    if [ -e "$config_file" ]; then
        read -p "warp已安装在 $config_file ,进入管理面板？ (y/n, 默认为 n): " choice
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            warp
        else
            exit 0
        fi
    else
        read -p "warp未安装,现在安装？ (y/n, 默认为 n): " choic
        if [[ "$choic" == "y" || "$choic" == "Y" ]]; then
            wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh
            echo "warp已安装在 $config_file"
        else
            exit 0
        fi
    fi

}

#申请/管理证书(acme.sh)
acme_cert_apply() {
    if [[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]]; then
        read -p "acme.sh尚未安装,是否现在安装？(y/n,默认y) " answer
        answer="${answer:-y}"
        if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
            local acme_folder="/usr/local/etc/acme"
            mkdir -p "$acme_folder"
            install_acme
            acme_cert_apply
        else
            exit 1
        fi
    else
        echo ""
        echo -e "${GREEN}1 ${NC} 申请新证书"
        echo -e "${GREEN}2 ${NC} 查看/撤销/删除已申请的证书"
        echo -e "${GREEN}3 ${NC} 手动续期已申请的证书"
        echo -e "${GREEN}4 ${NC} 切换证书颁发机构"
        echo -e "${RED}5  卸载acme.sh${NC}"
        echo -e "${GREEN}0 ${NC} 退出"

        read -p "acme.sh已安装,选择执行选项[0-5]: " chioce
        chioce="${chioce:-0}"

        case $chioce in
            1)
                acme_standalone
                exit 0
                ;;
            2)
                revoke_cert
                exit 0
                ;;
            3)
                renew_cert
                exit 0
                ;;
            4)
                switch_provider
                exit 0
                ;;
            5)
                uninstall_acme
                exit 0
                ;;
            0)
                menu
                exit 0
                ;;
            *)
                echo -e "${RED}无效的选择,请重新输入！${NC}"
                acme_cert_apply
                ;;
        esac
    fi
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
    
    # switch_provider

    if [[ -n $(~/.acme.sh/acme.sh -v 2>/dev/null) ]]; then
        green "acme.sh 证书一键申请脚本安装成功!"
    else
        red "acme.sh 证书一键申请脚本安装失败"
    fi
}

# acme_standalone(){
    
#     check_80_port

#     WARPv4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
#     WARPv6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
#     if [[ $WARPv4Status =~ on|plus ]] || [[ $WARPv6Status =~ on|plus ]]; then
#         wg-quick down wgcf >/dev/null 2>&1
#         systemctl stop warp-go >/dev/null 2>&1
#     fi
    
#     check_ip
    
#     echo ""
#     yellow "使用80端口申请模式时, 请先将您的域名解析至你的VPS的真实IP地址并关闭小黄云, 否则会导致证书申请失败"
#     echo ""
#     if [[ -n $ipv4 && -n $ipv6 ]]; then
#         echo -e "VPS的真实IPv4地址为: ${GREEN}$ipv4${NC}"
#         echo -e "VPS的真实IPv6地址为: ${GREEN}$ipv6${NC}"
#     elif [[ -n $ipv4 && -z $ipv6 ]]; then
#         echo -e "VPS的真实IPv4地址为: ${GREEN}$ipv4${NC}"
#     elif [[ -z $ipv4 && -n $ipv6 ]]; then
#         echo -e "VPS的真实IPv6地址为: ${GREEN}$ipv6${NC}"
#     fi
#     echo ""

#     read -rp "请输入解析完成的域名: " domain
#     [[ -z $domain ]] && red "未输入域名,无法执行操作！" && exit 1
#     green "已输入的域名：$domain" && sleep 1

#     domainIP=$(curl -sm8 ipget.net/?ip="${domain}")
    
#     if [[ $domainIP == $ipv6 ]]; then
#         bash ~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-256 --listen-v6 --insecure
#     fi
#     if [[ $domainIP == $ipv4 ]]; then
#         bash ~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-256 --insecure
#     fi
    
#     if [[ -n $(echo $domainIP | grep nginx) ]]; then
#         if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
#             wg-quick up wgcf >/dev/null 2>&1
#         fi
#         if [[ -a "/opt/warp-go/warp-go" ]]; then
#             systemctl start warp-go 
#         fi
#         yellow "域名解析失败, 请检查域名是否正确填写或等待解析完成再执行脚本"
#         exit 1
#     elif [[ -n $(echo $domainIP | grep ":") || -n $(echo $domainIP | grep ".") ]]; then
#         if [[ $domainIP != $ipv4 ]] && [[ $domainIP != $ipv6 ]]; then
#             if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
#                 wg-quick up wgcf >/dev/null 2>&1
#             fi
#             if [[ -a "/opt/warp-go/warp-go" ]]; then
#                 systemctl start warp-go 
#             fi
#             green "域名 ${domain} 目前解析的IP: ($domainIP)"
#             red "当前域名解析的 IP 与当前 VPS 使用的真实IP不匹配"
#             exit 1
#         fi
#     fi
    
#     bash ~/.acme.sh/acme.sh --install-cert -d ${domain} --key-file /usr/local/etc/acme/$domain.key --fullchain-file /usr/local/etc/acme/$domain.crt --ecc
    
#     apply_cert
# }

acme_standalone(){
    #检查/释放80端口
    check_80_port

    #检查/关闭warp
    check_warp
    
    #检查本机ip
    check_ip
    
    #检查域名解析ip与本机ip是否一致
    check_domain

    #设置证书存储路径
    cert_path="/usr/local/etc/acme" 
    bash ~/.acme.sh/acme.sh --install-cert -d ${domain} --key-file $cert_path/$domain.key --fullchain-file $ert_path/$domain.crt --ecc
    
    #申请证书并记录到ca.log
    apply_cert
}

revoke_cert() {
    bash ~/.acme.sh/acme.sh --list
    read -rp "请输入要撤销的域名证书 (复制 Main_Domain 下显示的域名): " domain
    [[ -z $domain ]] && red "未输入域名,无法执行操作!" && exit 1

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
    echo ""
    yellow "请选择证书提供商, 默认通过 Letsencrypt.org 来申请证书"
    yellow "如果证书申请失败, 例如一天内通过 Letsencrypt.org 申请次数过多, 可选 BuyPass.com 或 ZeroSSL.com 来申请"
    echo -e "${GREEN}1 ${NC} Letsencrypt.org ${YELLOW}(默认)${NC} "
    echo -e "${GREEN}2 ${NC} BuyPass.com"
    echo -e "${GREEN}3 ${NC} ZeroSSL.com"
    echo -e "${GREEN}0 ${NC} 退出"

    read -p "请选择证书提供商 [0-3]: " provider
    case $provider in
        1)
            bash ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt && green "切换证书提供商为 Letsencrypt.org 成功！"
            exit 0
            ;;
        2)
            bash ~/.acme.sh/acme.sh --set-default-ca --server buypass && green "切换证书提供商为 BuyPass.com 成功！"
            exit 0
            ;;
        3)
            bash ~/.acme.sh/acme.sh --set-default-ca --server zerossl && green "切换证书提供商为 ZeroSSL.com 成功！"
            exit 0
            ;;
        0)
            menu
            exit 0
            ;;
        *)
            echo -e " ${RED}无效的选择,请重新输入${NC} "
            switch_provider
            ;;
    esac
}

uninstall_acme() {
    read -p "确定要删除 acme.sh 吗？(y/n,默认n) " answer
    answer="${answer:-n}"
    if [[ "$answer" == "y" ]]; then
        ~/.acme.sh/acme.sh --uninstall
        sed -i '/--cron/d' /etc/crontab >/dev/null 2>&1
        rm -rf ~/.acme.sh
        green "acme.sh 证书一键申请脚本已彻底卸载!"
    else
        echo "取消卸载操作"
    fi
}

check_80_port(){
    if [[ -z $(type -P lsof) ]]; then
        if [[ ! $SYSTEM == "CentOS" ]]; then
            ${PACKAGE_UPDATE[int]}
        fi
        ${PACKAGE_INSTALL[int]} lsof
    fi
    
    yellow "正在检测 80 端口是否占用..."
    # sleep 1
    
    if [[  $(lsof -i:"80" | grep -i -c "listen") -eq 0 ]]; then
        green "检测到目前 80 端口未被占用"
        yellow "使用80端口申请证书时, 请先将您的域名解析至你的VPS的真实IP地址并关闭小黄云, 否则会导致证书申请失败"
        # sleep 1
    else
        red "检测到目前 80 端口被其他程序被占用,以下为占用程序信息"
        lsof -i:"80"
        read -rp "如需结束占用进程请按Y,按其他键则退出 [Y/N]: " yn
        if [[ $yn =~ "Y"|"y" ]]; then
            lsof -i:"80" | awk '{print $2}' | grep -v "PID" | xargs kill -9
            sleep 1
            check_80_port
        else
            exit 1
        fi
    fi
}

check_warp() {
    WARPv4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    WARPv6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    if [[ $WARPv4Status =~ on|plus ]] || [[ $WARPv6Status =~ on|plus ]]; then
        read -p "检测到warp已开启,将影响acme.sh成功申请证书,是否关闭warp?(y/n,默认y)" chioce
        chioce="${chioce:-y}"
        if [[ "$chioce" == "y" ]]; then
            warp o
        else
            exit 0
        fi
    else
        exit 0
    fi
}

check_ip(){
    ipv4=$(curl -s4m8 ip.sb -k | sed -n 1p)
    ipv6=$(curl -s6m8 ip.sb -k | sed -n 1p)
    [[ "$ipv4" ]] && yellow "服务器ipv4为: ${ipv4}"
    [[ "$ipv6" ]] && yellow "服务器ipv6为: ${ipv6}"
}

check_domain() {
    read -rp "请输入解析完成的域名: " domain
    [[ -z $domain ]] && red "未输入域名,无法执行操作！" && exit 1
    green "已输入的域名：$domain"
    # green "已输入的域名：$domain" && sleep 1

    domainIP=$(curl -sm8 ipget.net/?ip="${domain}")
    
    if [[ $domainIP == $ipv6 ]]; then
        bash ~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-256 --listen-v6 --insecure
    elif [[ $domainIP == $ipv4 ]]; then
        bash ~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-256 --insecure
    else
        red "域名未完成解析或域名解析的IP与服务器当前的真实IP不匹配"
        exit 1
    fi
}

apply_cert() {
    cert_path="/usr/local/etc/acme" 
    if [[ -f $cert_path/$domain.crt && -f $cert_path/$domain.key && -s $cert_path/$domain.crt && -s $cert_path/$domain.key ]]; then
        echo $domain > $cert_path/ca.log
        sed -i '/--cron/d' /etc/crontab >/dev/null 2>&1
        echo "0 0 * * * root bash /root/.acme.sh/acme.sh --cron -f >/dev/null 2>&1" >> /etc/crontab
        echo "证书申请成功!"
        yellow "crt文件路径: $cert_path/$domain.crt"
        yellow "key文件路径: $cert_path/$domain.key"
    else
        red "证书申请失败"
        exit 1        
    fi
}

#自签证书
self_sign_cert() {
    read -p "请输入要签证的域名 (例如: example.com): " domain
    if [ -z "$domain" ]; then
        echo "错误：域名不能为空"
        exit 1
    fi
    cert_path=""
    while [ -z "$cert_path" ] || [ ! -d "$cert_path" ]; do
        read -rp "请输入证书保存路径(必须为已存在的目录,按回车键确认,默认路径为 /usr/local/etc/cert): " cert_path
        if [ -z "$cert_path" ]; then
            mkdir -p /usr/local/etc/cert
            cert_path="/usr/local/etc/cert"
        fi
        if [ ! -d "$cert_path" ]; then
            echo "错误：指定的路径 '$cert_path' 不存在,请重新输入"
        fi
    done
    openssl ecparam -genkey -name prime256v1 -out "$cert_path/$domain.key"
    openssl req -new -x509 -days 3650 -key "$cert_path/$domain.key" -out "$cert_path/$domain.crt" -subj "/CN=$domain"

    echo "SSL证书和私钥已生成!"
    yellow "crt文件路径: $cert_path/$domain.crt"
    yellow "key文件路径: $cert_path/$domain.key"
}

#更新脚本
update_script() {
    wget -O /root/sb.sh https://raw.githubusercontent.com/sleeple2s/sing_box/main/sing_box.sh
    chmod +x /root/sb.sh 
}

#卸载sing-box
uninstall_sing_box() {
    read -p "确定要删除 sing-box 吗？(y/n,默认n) " answer
    answer="${answer:-n}"
    if [ "$answer" == "y" || "$answer" == "Y" ]; then
        echo "开始卸载 sing-box..."
        systemctl disable sing-box
        rm -rf /usr/local/bin/sing-box
        rm -rf /usr/local/etc/sing-box
        rm -rf /etc/systemd/system/sing-box.service
        systemctl daemon-reload
        echo "sing-box 卸载完成"
    else
        echo "取消卸载操作"
    fi
}

show_sing_box_version() {
    local version_file="/usr/local/etc/sing-box/version.txt"
    local sing_box_status=$(systemctl is-active "sing-box")
    if [ -e "$version_file" ]; then
        cat "$version_file"
    elif [ "$sing_box_status" = "active" ]; then
        sing-box version > "$version_file"
        sed -i '1s/.*/'"$(yellow "$(head -n 1 "$version_file")")"'/g' "$version_file"
        cat "$version_file"
    else 
        exit 0
    fi
}

menu() {
    echo ""
    echo -e "${YELLOW}script-version v1.52${NC}"
    show_sing_box_version
    echo "---------------------------------------------------------------"
    echo -e "${GREEN}1 ${NC} 安装/更新sing-box"
    echo -e "${GREEN}2 ${NC} 安装/管理warp"
    echo -e "${GREEN}3 ${NC} 申请/管理证书(acme.sh)"
    echo -e "${GREEN}4 ${NC} 自签证书"
    echo -e "${GREEN}5 ${NC} 更新脚本"
    echo -e "${RED}10 卸载sing-box${NC}"
    echo -e "${GREEN}0 ${NC} 退出脚本"
    echo "---------------------------------------------------------------"
    read -rp "请输入选项: " menuInput
    case "$menuInput" in
        1)
            select_sing_box_install_option
            exit 0
            ;;
        2)
            install_warp
            exit 0
            ;;
        3)
            acme_cert_apply
            exit 0
            ;;
        4)
            self_sign_cert
            exit 0
            ;;

        5)
            update_script
            exit 0
            ;;
        10)
            uninstall_sing_box
            exit 0
            ;;
        0)
            exit 0
            ;;
        *) 
            echo -e "${RED}无效的选择,请重新输入${NC}"
            menu
            ;;
    esac
}

menu


