#!/bin/bash

###################
# 颜色定义
###################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # 无颜色

###################
# 全局变量
###################
RELAY_CONFIG="/etc/socat-relay/relay.conf"
SERVICE_DIR="/etc/systemd/system"
SCRIPT_DIR="/usr/local/bin"
SCRIPT_NAME="socat-relay"
FULL_SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_NAME"
AUTOSTART_SCRIPT="/etc/rc.local"

###################
# 辅助函数
###################
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误：此脚本需要root权限运行${NC}"
        exit 1
    fi
}

print_banner() {
    clear
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Socat端口转发管理工具              ${NC}"
    echo -e "${CYAN}Powered by Moorigin               ${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

show_menu() {
    while true; do
        print_banner
        echo -e "${YELLOW}请选择操作：${NC}"
        echo "1. 安装必要软件"
        echo "2. 添加转发规则"
        echo "3. 设置开机自启"
        echo "4. 查看转发规则"
        echo "5. 删除转发规则"
        echo "6. 启动/重启所有转发"
        echo "7. 停止所有转发"
        echo "8. 系统状态检查"
        echo "0. 退出"

        echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}请选择操作 [0-8]:${NC}"
        read -p "> " choice

        case $choice in
            1)
                install_software
                read -p "按回车继续..."
                ;;
            2)
                add_relay_rule
                read -p "按回车继续..."
                ;;
            3)
                setup_autostart
                read -p "按回车继续..."
                ;;
            4)
                list_relay_rules
                read -p "按回车继续..."
                ;;
            5)
                delete_relay_rule
                read -p "按回车继续..."
                ;;
            6)
                restart_all_relay
                read -p "按回车继续..."
                ;;
            7)
                stop_all_relay
                read -p "按回车继续..."
                ;;
            8)
                check_system_status
                read -p "按回车继续..."
                ;;
            0)
                exit 0
                ;;
            *)
                echo -e "${RED}无效的选择${NC}"
                sleep 1
                ;;
        esac
    done
}

###################
# 功能函数
###################
install_software() {
    echo -e "${YELLOW}正在安装必要软件...${NC}"
    
    if command -v apt &>/dev/null; then
        # Debian/Ubuntu
        apt update
        apt install -y socat net-tools procps psmisc iputils-ping iproute2 
    elif command -v yum &>/dev/null; then
        # CentOS/RHEL
        yum install -y socat net-tools procps-ng psmisc iputils iproute
    else
        echo -e "${RED}不支持的系统类型${NC}"
        return 1
    fi
    
    # 创建配置目录
    mkdir -p $(dirname "$RELAY_CONFIG")
    touch "$RELAY_CONFIG"
    
    # 创建辅助脚本目录
    mkdir -p "$SCRIPT_DIR"
    
    # 创建主管理脚本
    create_management_script
    
    echo -e "${GREEN}安装完成!${NC}"
}

create_management_script() {
    # 创建脚本用于管理转发规则
    cat > "$FULL_SCRIPT_PATH" << 'EOF'
#!/bin/bash

RELAY_CONFIG="/etc/socat-relay/relay.conf"
PIDFILE_DIR="/var/run/socat-relay"

start_relay() {
    local local_port=$1
    local target_ip=$2
    local target_port=$3
    local protocol=$4
    
    # 确保PID文件目录存在
    mkdir -p "$PIDFILE_DIR"
    
    # 根据协议启动相应的转发
    if [[ "$protocol" == "tcp" || "$protocol" == "both" ]]; then
        # 创建唯一的PID文件名
        local tcp_pidfile="$PIDFILE_DIR/tcp_${local_port}.pid"
        
        # 如果已存在进程，停止它
        if [ -f "$tcp_pidfile" ]; then
            local old_pid=$(cat "$tcp_pidfile")
            if kill -0 "$old_pid" 2>/dev/null; then
                kill "$old_pid"
                sleep 1
            fi
            rm -f "$tcp_pidfile"
        fi
        
        # 启动TCP转发并保存PID
        socat TCP6-LISTEN:${local_port},fork,reuseaddr TCP4:${target_ip}:${target_port} &
        echo $! > "$tcp_pidfile"
        echo "启动TCP转发: [::]:$local_port -> $target_ip:$target_port (PID: $(cat $tcp_pidfile))"
    fi
    
    if [[ "$protocol" == "udp" || "$protocol" == "both" ]]; then
        # 创建唯一的PID文件名 
        local udp_pidfile="$PIDFILE_DIR/udp_${local_port}.pid"
        
        # 如果已存在进程，停止它
        if [ -f "$udp_pidfile" ]; then
            local old_pid=$(cat "$udp_pidfile")
            if kill -0 "$old_pid" 2>/dev/null; then
                kill "$old_pid"
                sleep 1
            fi
            rm -f "$udp_pidfile"
        fi
        
        # 启动UDP转发并保存PID
        socat UDP6-LISTEN:${local_port},fork,reuseaddr UDP4:${target_ip}:${target_port} &
        echo $! > "$udp_pidfile"
        echo "启动UDP转发: [::]:$local_port -> $target_ip:$target_port (PID: $(cat $udp_pidfile))"
    fi
}

stop_relay() {
    local local_port=$1
    local protocol=$2
    
    # 根据协议停止相应的转发
    if [[ "$protocol" == "tcp" || "$protocol" == "both" ]]; then
        local tcp_pidfile="$PIDFILE_DIR/tcp_${local_port}.pid"
        if [ -f "$tcp_pidfile" ]; then
            local pid=$(cat "$tcp_pidfile")
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid"
                echo "已停止TCP转发端口 $local_port (PID: $pid)"
            else
                echo "TCP转发端口 $local_port 未在运行"
            fi
            rm -f "$tcp_pidfile"
        else
            echo "TCP转发端口 $local_port 未在运行"
        fi
    fi
    
    if [[ "$protocol" == "udp" || "$protocol" == "both" ]]; then
        local udp_pidfile="$PIDFILE_DIR/udp_${local_port}.pid"
        if [ -f "$udp_pidfile" ]; then
            local pid=$(cat "$udp_pidfile")
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid"
                echo "已停止UDP转发端口 $local_port (PID: $pid)"
            else
                echo "UDP转发端口 $local_port 未在运行"
            fi
            rm -f "$udp_pidfile"
        else
            echo "UDP转发端口 $local_port 未在运行"
        fi
    fi
}

# 启动所有转发规则
start_all() {
    echo "启动所有转发规则..."
    
    if [ ! -f "$RELAY_CONFIG" ]; then
        echo "配置文件不存在"
        return 1
    fi
    
    while IFS=' ' read -r local_port target_ip target_port protocol; do
        # 跳过空行和注释
        [[ -z "$local_port" || "$local_port" == \#* ]] && continue
        
        # 如果不包含协议字段，默认为tcp
        if [ -z "$protocol" ]; then
            protocol="tcp"
        fi
        
        start_relay "$local_port" "$target_ip" "$target_port" "$protocol"
    done < "$RELAY_CONFIG"
    
    echo "所有转发规则启动完成"
}

# 停止所有转发规则
stop_all() {
    echo "停止所有转发规则..."
    
    # 查找所有socat进程并停止
    local pids=$(pgrep -f "socat (TCP|UDP)6-LISTEN" 2>/dev/null)
    if [ -n "$pids" ]; then
        echo "正在终止socat进程: $pids"
        kill $pids 2>/dev/null
        sleep 1
        # 确保进程已终止
        for pid in $pids; do
            if kill -0 $pid 2>/dev/null; then
                echo "强制终止进程 $pid"
                kill -9 $pid 2>/dev/null
            fi
        done
    fi
    
    # 清理PID文件
    rm -f "$PIDFILE_DIR"/*.pid 2>/dev/null
    
    echo "所有转发规则已停止"
}

# 检查特定端口的转发状态
check_status() {
    local local_port=$1
    local found=0
    
    # 检查TCP转发
    local tcp_pidfile="$PIDFILE_DIR/tcp_${local_port}.pid"
    if [ -f "$tcp_pidfile" ]; then
        local pid=$(cat "$tcp_pidfile")
        if kill -0 "$pid" 2>/dev/null; then
            echo "TCP端口 $local_port: 运行中 (PID: $pid)"
            found=1
        else
            echo "TCP端口 $local_port: 进程已终止 (PID文件存在)"
            found=1
        fi
    fi
    
    # 检查UDP转发
    local udp_pidfile="$PIDFILE_DIR/udp_${local_port}.pid"
    if [ -f "$udp_pidfile" ]; then
        local pid=$(cat "$udp_pidfile")
        if kill -0 "$pid" 2>/dev/null; then
            echo "UDP端口 $local_port: 运行中 (PID: $pid)"
            found=1
        else
            echo "UDP端口 $local_port: 进程已终止 (PID文件存在)"
            found=1
        fi
    fi
    
    # 如果两种协议都没找到
    if [ $found -eq 0 ]; then
        echo "端口 $local_port 没有活动的转发"
    fi
}

# 检查所有转发状态
check_all_status() {
    echo "检查所有转发状态..."
    
    # 首先从配置文件获取所有端口
    local ports=()
    if [ -f "$RELAY_CONFIG" ]; then
        while IFS=' ' read -r local_port target_ip target_port protocol; do
            # 跳过空行和注释
            [[ -z "$local_port" || "$local_port" == \#* ]] && continue
            ports+=("$local_port")
        done < "$RELAY_CONFIG"
    fi
    
    # 检查每个配置的端口状态
    if [ ${#ports[@]} -eq 0 ]; then
        echo "配置文件中没有转发规则"
    else
        for port in "${ports[@]}"; do
            check_status "$port"
        done
    fi
    
    # 检查系统中运行的socat进程
    echo -e "\n当前运行的socat进程:"
    ps aux | grep -E "socat (TCP|UDP)6-LISTEN" | grep -v grep || echo "没有运行中的socat进程"
}

# 根据参数执行相应操作
case "$1" in
    start)
        start_all
        ;;
    stop)
        stop_all
        ;;
    restart)
        stop_all
        sleep 1
        start_all
        ;;
    status)
        check_all_status
        ;;
    start_port)
        if [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
            echo "用法: $0 start_port <本地端口> <目标IP> <目标端口> [协议]"
            exit 1
        fi
        protocol=${5:-both}
        start_relay "$2" "$3" "$4" "$protocol"
        ;;
    stop_port)
        if [ -z "$2" ]; then
            echo "用法: $0 stop_port <本地端口> [协议]"
            exit 1
        fi
        protocol=${3:-both}
        stop_relay "$2" "$protocol"
        ;;
    *)
        echo "用法: $0 {start|stop|restart|status|start_port|stop_port}"
        exit 1
        ;;
esac

exit 0
EOF

    # 使脚本可执行
    chmod +x "$FULL_SCRIPT_PATH"
}

validate_port() {
    local port=$1
    if [[ $port =~ ^[0-9]+$ ]] && ((port >= 1 && port <= 65535)); then
        return 0
    fi
    return 1
}

validate_ip() {
    local ip=$1
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        local IFS='.'
        local -a octets=($ip)
        for octet in "${octets[@]}"; do
            if ((octet > 255)); then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

add_relay_rule() {
    # 确保配置目录存在
    mkdir -p $(dirname "$RELAY_CONFIG")
    
    echo -e "${YELLOW}添加新的IPv6到IPv4转发规则${NC}"
    
    echo -e "${YELLOW}请选择协议类型：${NC}"
    echo "1. TCP"
    echo "2. UDP"
    echo "3. TCP+UDP"
    read -p "> " protocol_choice

    case $protocol_choice in
        1) protocol="tcp" ;;
        2) protocol="udp" ;;
        3) protocol="both" ;;
        *) 
            echo -e "${RED}无效的协议选择${NC}"
            return 1
            ;;
    esac
    
    echo -e "${YELLOW}请输入本地IPv6监听端口：${NC}"
    read -p "> " local_port
    
    echo -e "${YELLOW}请输入目标IPv4地址：${NC}"
    read -p "> " target_ip
    
    echo -e "${YELLOW}请输入目标端口：${NC}"
    read -p "> " target_port
    
    # 验证输入
    if ! validate_port "$local_port"; then
        echo -e "${RED}无效的本地端口${NC}"
        return 1
    fi
    
    if ! validate_ip "$target_ip"; then
        echo -e "${RED}无效的目标IP地址${NC}"
        return 1
    fi
    
    if ! validate_port "$target_port"; then
        echo -e "${RED}无效的目标端口${NC}"
        return 1
    fi
    
    # 检查端口是否已在使用
    if grep -q "^$local_port " "$RELAY_CONFIG" 2>/dev/null; then
        echo -e "${RED}警告：端口 $local_port 已存在于配置中${NC}"
        read -p "是否覆盖? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            return 1
        fi
        # 删除现有规则
        sed -i "/^$local_port /d" "$RELAY_CONFIG"
    fi
    
    # 添加规则到配置文件
    echo "$local_port $target_ip $target_port $protocol" >> "$RELAY_CONFIG"
    
    # 启动转发
    "$FULL_SCRIPT_PATH" start_port "$local_port" "$target_ip" "$target_port" "$protocol"
    
    echo -e "${GREEN}转发规则已添加并启动${NC}"
}

setup_autostart() {
    echo -e "${YELLOW}设置开机自启动...${NC}"
    
    # 创建systemd服务
    cat > "$SERVICE_DIR/socat-relay.service" << EOF
[Unit]
Description=Socat IPv6 to IPv4 Relay Service
After=network.target

[Service]
Type=oneshot
ExecStart=$FULL_SCRIPT_PATH start
ExecStop=$FULL_SCRIPT_PATH stop
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    # 启用并启动服务
    systemctl daemon-reload
    systemctl enable socat-relay.service
    systemctl start socat-relay.service
    
    # 备份方案: 添加到rc.local
    if [ ! -f "$AUTOSTART_SCRIPT" ]; then
        cat > "$AUTOSTART_SCRIPT" << 'EOF'
#!/bin/bash
# rc.local
exit 0
EOF
        chmod +x "$AUTOSTART_SCRIPT"
    fi
    
    # 检查rc.local中是否已包含启动命令
    if ! grep -q "$FULL_SCRIPT_PATH start" "$AUTOSTART_SCRIPT"; then
        # 在exit 0前插入启动命令
        sed -i "s|^exit 0|$FULL_SCRIPT_PATH start\\nexit 0|" "$AUTOSTART_SCRIPT"
    fi
    
    echo -e "${GREEN}开机自启动设置完成${NC}"
}

list_relay_rules() {
    echo -e "${CYAN}当前转发规则:${NC}"
    
    if [ ! -f "$RELAY_CONFIG" ] || [ ! -s "$RELAY_CONFIG" ]; then
        echo -e "${YELLOW}没有配置任何转发规则${NC}"
        return
    fi
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "${CYAN}%-6s %-20s %-10s %-10s %-10s${NC}\n" "序号" "本地端口" "目标IP" "目标端口" "协议"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    local line_num=1
    while IFS=' ' read -r local_port target_ip target_port protocol; do
        # 跳过空行和注释
        [[ -z "$local_port" || "$local_port" == \#* ]] && continue
        
        # 如果没有指定协议，默认为tcp
        [ -z "$protocol" ] && protocol="tcp"
        
        printf "%-6s %-20s %-10s %-10s %-10s\n" "$line_num" "$local_port" "$target_ip" "$target_port" "$protocol"
        ((line_num++))
    done < "$RELAY_CONFIG"
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # 检查转发状态
    echo -e "\n${CYAN}转发状态:${NC}"
    "$FULL_SCRIPT_PATH" status
}

delete_relay_rule() {
    if [ ! -f "$RELAY_CONFIG" ] || [ ! -s "$RELAY_CONFIG" ]; then
        echo -e "${YELLOW}没有配置任何转发规则${NC}"
        return
    fi
    
    echo -e "${YELLOW}请选择要删除的规则编号：${NC}"
    
    # 显示所有规则
    list_relay_rules
    
    # 计算规则数量
    local rule_count=$(grep -v -e '^$' -e '^#' "$RELAY_CONFIG" | wc -l)
    
    read -p "请输入要删除的规则编号 (1-$rule_count): " rule_num
    
    if ! [[ "$rule_num" =~ ^[0-9]+$ ]] || [ "$rule_num" -lt 1 ] || [ "$rule_num" -gt "$rule_count" ]; then
        echo -e "${RED}无效的规则编号${NC}"
        return 1
    fi
    
    # 获取要删除的规则信息
    local rule=$(sed -n "${rule_num}p" <(grep -v -e '^$' -e '^#' "$RELAY_CONFIG"))
    local local_port=$(echo "$rule" | awk '{print $1}')
    local protocol=$(echo "$rule" | awk '{print $4}')
    
    # 默认protocol为tcp如果未指定
    [ -z "$protocol" ] && protocol="tcp"
    
    # 停止该端口的转发
    "$FULL_SCRIPT_PATH" stop_port "$local_port" "$protocol"
    
    # 从配置文件删除
    local temp_file=$(mktemp)
    grep -v -e '^$' -e '^#' "$RELAY_CONFIG" | awk -v line="$rule_num" 'NR != line' > "$temp_file"
    cat "$temp_file" > "$RELAY_CONFIG"
    rm -f "$temp_file"
    
    echo -e "${GREEN}规则已成功删除${NC}"
}

restart_all_relay() {
    echo -e "${YELLOW}正在重启所有转发规则...${NC}"
    "$FULL_SCRIPT_PATH" restart
    echo -e "${GREEN}所有转发规则已重启${NC}"
}

stop_all_relay() {
    echo -e "${YELLOW}正在停止所有转发规则...${NC}"
    "$FULL_SCRIPT_PATH" stop
    echo -e "${GREEN}所有转发规则已停止${NC}"
}

check_system_status() {
    echo -e "${CYAN}系统状态检查:${NC}"
    
    # 检查socat是否安装
    echo -n "检查socat安装: "
    if command -v socat &>/dev/null; then
        echo -e "${GREEN}已安装${NC}"
        socat -V | head -n1
    else
        echo -e "${RED}未安装${NC}"
    fi
    
    # 检查IPv6支持
    echo -n "检查IPv6支持: "
    if [ -f /proc/net/if_inet6 ]; then
        echo -e "${GREEN}支持${NC}"
        echo "IPv6接口:"
        ip -6 addr show | grep "inet6" | grep -v "::1/128"
    else
        echo -e "${RED}不支持${NC}"
    fi
    
    # 检查IPv4支持
    echo -n "检查IPv4支持: "
    if ip -4 addr show &>/dev/null; then
        echo -e "${GREEN}支持${NC}"
        echo "IPv4接口:"
        ip -4 addr show | grep "inet " | grep -v "127.0.0.1"
    else
        echo -e "${RED}不支持${NC}"
    fi
    
    # 检查转发状态
    echo -e "\n${CYAN}转发状态:${NC}"
    "$FULL_SCRIPT_PATH" status
    
    # 检查端口占用
    echo -e "\n${CYAN}端口占用情况:${NC}"
    if command -v netstat &>/dev/null; then
        netstat -tuln | grep "LISTEN" | sort -n -k 4
    elif command -v ss &>/dev/null; then
        ss -tuln | grep "LISTEN" | sort -n -k 5
    else
        echo "未找到netstat或ss命令"
    fi
    
    # 检查自启动状态
    echo -e "\n${CYAN}自启动状态:${NC}"
    if systemctl is-enabled socat-relay.service &>/dev/null; then
        echo "Systemd服务: $(systemctl is-enabled socat-relay.service)"
        echo "服务状态: $(systemctl is-active socat-relay.service)"
    else
        echo "Systemd服务: 未配置"
    fi
    
    if grep -q "$FULL_SCRIPT_PATH" "$AUTOSTART_SCRIPT" 2>/dev/null; then
        echo "RC.local: 已配置"
    else
        echo "RC.local: 未配置"
    fi
}

###################
# 主程序
###################
check_root
show_menu
