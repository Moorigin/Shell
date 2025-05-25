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
FORWARD_RULES_FILE="/etc/iptables-forward-rules.conf"
BACKUP_DIR="/root/iptables_backups"
BACKUP_FILE="${BACKUP_DIR}/iptables_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
SYSCTL_CONF="/etc/sysctl.conf"

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
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}                        IPTables 端口转发管理工具                           ${NC}"
    echo -e "${CYAN}                        Powered by Moorigin                               ${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

show_menu() {
    while true; do
        print_banner
        echo -e "${YELLOW}请选择操作：${NC}"
        echo "1. 安装iptables-persistent"
        echo "2. 启用IP转发并优化系统参数"
        echo "3. 转发规则管理"
        echo "4. 查询转发规则"
        echo "5. 保存当前规则"
        echo "6. 恢复规则"
        echo "0. 退出"

        echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}请选择操作 [0-6]:${NC}"
        read -p "> " choice

        case $choice in
            1)
                install_iptables
                read -p "按回车继续..."
                ;;
            2)
                network_optimize
                read -p "按回车继续..."
                ;;
            3)
                manage_forward_rules 
                ;;
            4)
                check_forward_status
                read -p "按回车继续..."
                ;;
            5)
                save_rules
                read -p "按回车继续..."
                ;;
            6)
                restore_rules
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
check_iptables() {
    echo "检查 iptables-persistent 是否已安装..."
    
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu 系统
        if dpkg -l | grep -q "iptables-persistent"; then
            echo "iptables-persistent 已经安装！"
            return 0
        else
            echo "iptables-persistent 未安装。"
            return 1
        fi
    elif [ -f /etc/redhat-release ]; then
        # RHEL/CentOS/Fedora 系统
        if rpm -q iptables-services &>/dev/null; then
            echo "iptables-services 已经安装！"
            return 0
        else
            echo "iptables-services 未安装。"
            return 1
        fi
    else
        echo "不支持的操作系统类型！"
        return 2
    fi
}

install_iptables() {
    echo "开始安装 iptables-persistent..."
    
    # 先检查是否已安装
    check_iptables
    local check_result=$?
    
    # 如果已安装，直接返回
    if [ $check_result -eq 0 ]; then
        echo "跳过安装步骤。"
        return 0
    # 如果系统不支持，退出
    elif [ $check_result -eq 2 ]; then
        return 1
    fi
    
    # 检测操作系统
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu 系统
        
        # 预配置 iptables-persistent 以避免交互式提示
        echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
        echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections
        
        # 安装 iptables-persistent
        apt-get update
        apt-get install -y iptables-persistent
        
        if [ $? -eq 0 ]; then
            echo "iptables-persistent 安装成功！"
        else
            echo "iptables-persistent 安装失败！"
            return 1
        fi
        
        # 确保相关服务启用
        systemctl enable netfilter-persistent.service
        
    elif [ -f /etc/redhat-release ]; then
        # RHEL/CentOS/Fedora 系统
        
        # CentOS/RHEL 使用 iptables-services 包
        yum install -y iptables-services
        
        if [ $? -eq 0 ]; then
            echo "iptables-services 安装成功！"
        else
            echo "iptables-services 安装失败！"
            return 1
        fi
        
        # 设置服务自启动
        systemctl enable iptables
        systemctl enable ip6tables
        
        # 创建保存规则的目录
        mkdir -p /etc/iptables
    fi
    
    echo "iptables 持久化服务安装完成！"
    return 0
}

network_optimize() {
    # 创建临时文件
    local tmp_sysctl="/tmp/sysctl_temp.conf"

    # 基础网络优化参数
    cat > "$tmp_sysctl" << EOF
# 启用IP转发
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1

# BBR优化
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_slow_start_after_idle=0

# 内存优化
vm.swappiness=1

#TCP缓冲区优化
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 16384 16777216
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192

#链接超时优化
net.ipv4.tcp_keepalive_time=600
net.ipv4.tcp_keepalive_intvl=15
net.ipv4.tcp_keepalive_probes=5

#其他重要配置优化
fs.file-max=1000000
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_ecn=0
net.ipv4.tcp_frto=2
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_rfc1337=1
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_adv_win_scale=1
net.ipv4.tcp_moderate_rcvbuf=1
EOF

    # 备份和更新sysctl配置
    if [ -f "$SYSCTL_CONF" ]; then
        cp "$SYSCTL_CONF" "${SYSCTL_CONF}.bak"
        grep -v -F -f <(grep -v '^#' "$tmp_sysctl" | cut -d= -f1 | tr -d ' ') "$SYSCTL_CONF" > "${SYSCTL_CONF}.tmp"
        mv "${SYSCTL_CONF}.tmp" "$SYSCTL_CONF"
    fi

    # 添加新的配置
    cat "$tmp_sysctl" >> "$SYSCTL_CONF"

    # 应用配置
    sysctl -p "$SYSCTL_CONF"

    # 清理临时文件
    rm -f "$tmp_sysctl"

    echo -e "${GREEN}IP转发已启用、系统参数已优化${NC}"
}

manage_forward_rules() {
    while true; do
        clear
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}                           转发规则管理                                   ${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${YELLOW}请选择操作：${NC}"
        echo "1. 添加新的转发规则"
        echo "2. 删除转发规则"
        echo "3. 重新加载所有规则"
        echo "0. 返回主菜单"

        echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}请选择操作 [0-3]:${NC}"
        read -p "> " sub_choice

        case $sub_choice in
            1)
                add_forward_rule
                read -p "按回车继续..."
                ;;
            2)
                delete_forward_rule
                read -p "按回车继续..."
                ;;
            3)
                reload_all_rules
                read -p "按回车继续..."
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效的选择${NC}"
                sleep 1
                ;;
        esac
    done
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

validate_port() {
    local port=$1
    if [[ $port =~ ^[0-9]+$ ]] && ((port >= 1 && port <= 65535)); then
        return 0
    fi
    return 1
}

add_forward_rule() {
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

    echo -e "${YELLOW}请输入源端口：${NC}"
    read -p "> " src_port

    echo -e "${YELLOW}请输入目标服务器IP：${NC}"
    read -p "> " target_ip

    echo -e "${YELLOW}请输入目标端口：${NC}"
    read -p "> " target_port

    # 输入验证
    if ! validate_port "$src_port" || ! validate_port "$target_port" || ! validate_ip "$target_ip"; then
        echo -e "${RED}无效的输入格式${NC}"
        return 1
    fi

    # 检查端口是否已被使用
    if grep -q "^$src_port " "$FORWARD_RULES_FILE" 2>/dev/null; then
        echo -e "${RED}源端口 $src_port 已被使用${NC}"
        return 1
    fi

    # 检查目标服务器可达性
    echo -e "${YELLOW}正在测试目标服务器连通性...${NC}"
    if ! ping -c 2 -W 3 "$target_ip" >/dev/null 2>&1; then
        echo -e "${YELLOW}警告：目标服务器 $target_ip 可能不可达${NC}"
        read -p "是否继续添加规则？(y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi

    # 创建备份
    backup_current_rules

    # 添加到配置文件
    mkdir -p "$(dirname "$FORWARD_RULES_FILE")"
    echo "$src_port $target_ip $target_port $protocol" >> "$FORWARD_RULES_FILE"

    # 添加iptables规则
    add_iptables_rules "$src_port" "$target_ip" "$target_port" "$protocol"

    echo -e "${GREEN}转发规则添加成功${NC}"
    
    # 保存规则
    save_rules
    
    sleep 1
}

add_iptables_rules() {
    local src_port=$1
    local target_ip=$2
    local target_port=$3
    local protocol=$4

    if [[ "$protocol" == "tcp" || "$protocol" == "both" ]]; then
        # TCP规则
        iptables -t nat -A PREROUTING -p tcp --dport "$src_port" -j DNAT --to-destination "${target_ip}:${target_port}"
        iptables -t nat -A POSTROUTING -p tcp -d "${target_ip}" --dport "${target_port}" -j MASQUERADE
        iptables -A FORWARD -p tcp -d "${target_ip}" --dport "${target_port}" -j ACCEPT
        iptables -A FORWARD -p tcp -s "${target_ip}" --sport "${target_port}" -j ACCEPT
    fi

    if [[ "$protocol" == "udp" || "$protocol" == "both" ]]; then
        # UDP规则
        iptables -t nat -A PREROUTING -p udp --dport "$src_port" -j DNAT --to-destination "${target_ip}:${target_port}"
        iptables -t nat -A POSTROUTING -p udp -d "${target_ip}" --dport "${target_port}" -j MASQUERADE
        iptables -A FORWARD -p udp -d "${target_ip}" --dport "${target_port}" -j ACCEPT
        iptables -A FORWARD -p udp -s "${target_ip}" --sport "${target_port}" -j ACCEPT
    fi
}

delete_forward_rule() {
    if [ ! -f "$FORWARD_RULES_FILE" ] || [ ! -s "$FORWARD_RULES_FILE" ]; then
        echo -e "${RED}没有可删除的规则${NC}"
        return 1
    fi

    echo -e "${YELLOW}请选择要删除的规则编号：${NC}"
    local line_num=1
    while read -r line; do
        if [ -n "$line" ]; then
            read -r src_port target_ip target_port protocol <<< "$line"
            echo "$line_num. $src_port -> $target_ip:$target_port ($protocol)"
            ((line_num++))
        fi
    done < "$FORWARD_RULES_FILE"
    
    read -p "> " rule_num

    if [[ ! $rule_num =~ ^[0-9]+$ ]] || [ "$rule_num" -lt 1 ] || [ "$rule_num" -ge "$line_num" ]; then
        echo -e "${RED}无效的规则编号${NC}"
        return 1
    fi

    # 创建备份
    backup_current_rules

    local rule
    rule=$(sed -n "${rule_num}p" "$FORWARD_RULES_FILE")
    if [ -n "$rule" ]; then
        read -r src_port target_ip target_port protocol <<< "$rule"
        
        echo -e "${YELLOW}正在删除规则: $src_port -> $target_ip:$target_port ($protocol)${NC}"
        
        # 删除iptables规则
        remove_iptables_rules "$src_port" "$target_ip" "$target_port" "$protocol"
        
        # 从配置文件中删除规则
        sed -i "${rule_num}d" "$FORWARD_RULES_FILE"

        echo -e "${GREEN}规则删除成功${NC}"
        
        # 保存规则
        save_rules
    else
        echo -e "${RED}无效的规则编号${NC}"
        return 1
    fi
}

remove_iptables_rules() {
    local src_port=$1
    local target_ip=$2
    local target_port=$3
    local protocol=$4

    if [[ "$protocol" == "tcp" || "$protocol" == "both" ]]; then
        # 删除TCP规则
        iptables -t nat -D PREROUTING -p tcp --dport "$src_port" -j DNAT --to-destination "${target_ip}:${target_port}" 2>/dev/null
        iptables -t nat -D POSTROUTING -p tcp -d "${target_ip}" --dport "${target_port}" -j MASQUERADE 2>/dev/null
        iptables -D FORWARD -p tcp -d "${target_ip}" --dport "${target_port}" -j ACCEPT 2>/dev/null
        iptables -D FORWARD -p tcp -s "${target_ip}" --sport "${target_port}" -j ACCEPT 2>/dev/null
    fi

    if [[ "$protocol" == "udp" || "$protocol" == "both" ]]; then
        # 删除UDP规则
        iptables -t nat -D PREROUTING -p udp --dport "$src_port" -j DNAT --to-destination "${target_ip}:${target_port}" 2>/dev/null
        iptables -t nat -D POSTROUTING -p udp -d "${target_ip}" --dport "${target_port}" -j MASQUERADE 2>/dev/null
        iptables -D FORWARD -p udp -d "${target_ip}" --dport "${target_port}" -j ACCEPT 2>/dev/null
        iptables -D FORWARD -p udp -s "${target_ip}" --sport "${target_port}" -j ACCEPT 2>/dev/null
    fi
}

reload_all_rules() {
    echo -e "${YELLOW}正在重新加载所有转发规则...${NC}"
    
    # 清除所有现有的转发规则
    clear_forward_rules
    
    # 从配置文件重新加载规则
    if [ -f "$FORWARD_RULES_FILE" ] && [ -s "$FORWARD_RULES_FILE" ]; then
        while read -r line; do
            if [ -n "$line" ]; then
                read -r src_port target_ip target_port protocol <<< "$line"
                add_iptables_rules "$src_port" "$target_ip" "$target_port" "$protocol"
                echo "已加载规则: $src_port -> $target_ip:$target_port ($protocol)"
            fi
        done < "$FORWARD_RULES_FILE"
        
        # 保存规则
        save_rules
        echo -e "${GREEN}所有转发规则重新加载完成${NC}"
    else
        echo -e "${YELLOW}没有找到规则配置文件${NC}"
    fi
}

clear_forward_rules() {
    echo -e "${YELLOW}正在清除现有转发规则...${NC}"
    
    # 清除NAT表规则（保留系统默认规则）
    iptables -t nat -F PREROUTING 2>/dev/null
    iptables -t nat -F POSTROUTING 2>/dev/null
    iptables -t nat -F OUTPUT 2>/dev/null
    
    # 清除FORWARD链规则（保留系统默认规则）
    iptables -F FORWARD 2>/dev/null
    
    echo -e "${GREEN}转发规则清除完成${NC}"
}

backup_current_rules() {
    mkdir -p "$BACKUP_DIR"
    
    # 备份iptables规则
    iptables-save > "${BACKUP_DIR}/iptables_$(date +%Y%m%d_%H%M%S).rules"
    
    # 备份配置文件
    if [ -f "$FORWARD_RULES_FILE" ]; then
        cp "$FORWARD_RULES_FILE" "${BACKUP_DIR}/forward_rules_$(date +%Y%m%d_%H%M%S).conf"
    fi
    
    echo -e "${GREEN}规则备份完成${NC}"
}

save_rules() {
    echo -e "${YELLOW}正在保存iptables规则...${NC}"
    
    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save
        echo -e "${GREEN}规则已通过netfilter-persistent保存${NC}"
    elif command -v iptables-save &> /dev/null && [ -f /etc/debian_version ]; then
        iptables-save > /etc/iptables/rules.v4
        echo -e "${GREEN}规则已保存到 /etc/iptables/rules.v4${NC}"
    elif command -v service &> /dev/null && [ -f /etc/redhat-release ]; then
        service iptables save
        echo -e "${GREEN}规则已通过service保存${NC}"
    else
        echo -e "${YELLOW}警告：无法自动保存规则，请手动保存${NC}"
    fi
}

restore_rules() {
    echo -e "${YELLOW}可用的备份文件：${NC}"
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR"/*.rules 2>/dev/null)" ]; then
        echo -e "${RED}没有找到备份文件${NC}"
        return 1
    fi
    
    local files=("$BACKUP_DIR"/*.rules)
    local i=1
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            echo "$i. $(basename "$file")"
            ((i++))
        fi
    done
    
    read -p "请选择要恢复的备份文件编号: " backup_num
    
    if [[ ! $backup_num =~ ^[0-9]+$ ]] || [ "$backup_num" -lt 1 ] || [ "$backup_num" -ge "$i" ]; then
        echo -e "${RED}无效的备份文件编号${NC}"
        return 1
    fi
    
    local selected_file="${files[$((backup_num-1))]}"
    
    echo -e "${YELLOW}正在恢复规则从 $(basename "$selected_file")...${NC}"
    
    # 恢复iptables规则
    iptables-restore < "$selected_file"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}规则恢复成功${NC}"
        save_rules
    else
        echo -e "${RED}规则恢复失败${NC}"
        return 1
    fi
}

check_forward_status() {
    echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│                           系统状态                              │${NC}"
    echo -e "${CYAN}├──────────────────┬──────────────────────────────────────────────┤${NC}"
    
    # IP转发状态
    local ip_forward=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo "未知")
    if [ "$ip_forward" = "1" ]; then
        echo -e "${CYAN}│    IP转发状态    │${NC} ${GREEN}已启用${NC}                                       ${CYAN}│${NC}"
    else
        echo -e "${CYAN}│    IP转发状态    │${NC} ${RED}未启用${NC}                                       ${CYAN}│${NC}"
    fi
    
    # 检查iptables NAT规则数量
    local nat_rules=$(iptables -t nat -L PREROUTING -n 2>/dev/null | grep -c DNAT || echo "0")
    echo -e "${CYAN}│  NAT转发规则数   │${NC} $nat_rules                                            ${CYAN}│${NC}"
    
    # 检查配置文件中的转发端口数量
    if [ -f "$FORWARD_RULES_FILE" ] && [ -s "$FORWARD_RULES_FILE" ]; then
        local forwarded_ports=$(grep -v '^#' "$FORWARD_RULES_FILE" | grep -v '^$' | wc -l)
        echo -e "${CYAN}│  配置转发规则数  │${NC} $forwarded_ports                                            ${CYAN}│${NC}"
    else
        echo -e "${CYAN}│  配置转发规则数  │${NC} 0                                                   ${CYAN}│${NC}"
    fi
    
    echo -e "${CYAN}└──────────────────┴──────────────────────────────────────────────┘${NC}"
    echo ""

    # 显示当前转发规则
    echo -e "${CYAN}┌──────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│                        当前转发规则                              │${NC}"
    echo -e "${CYAN}├────────────┬───────────────────────┬──────────────┬──────────────┤${NC}"
    echo -e "${CYAN}│   源端口   │       目标IP          │   目标端口   │     协议     │${NC}"
    echo -e "${CYAN}├────────────┼───────────────────────┼──────────────┼──────────────┤${NC}"
    
    if [ -f "$FORWARD_RULES_FILE" ] && [ -s "$FORWARD_RULES_FILE" ]; then
        while read -r line; do
            if [ -n "$line" ] && [[ ! "$line" =~ ^#.* ]]; then
                read -r src_port target_ip target_port protocol <<< "$line"
                # 如果没有协议字段，默认为tcp（兼容旧配置）
                [ -z "$protocol" ] && protocol="tcp"
                printf "${CYAN}│${NC} %-10s ${CYAN}│${NC} %-21s ${CYAN}│${NC} %-12s ${CYAN}│${NC} %-12s ${CYAN}│${NC}\n" \
                    "$src_port" "$target_ip" "$target_port" "$protocol"
            fi
        done < "$FORWARD_RULES_FILE"
    else
        printf "${CYAN}│${NC}%-63s${CYAN}│${NC}\n" "  暂无转发规则"
    fi
    echo -e "${CYAN}└────────────┴───────────────────────┴──────────────┴──────────────┘${NC}"
}

###################
# 主程序
###################
check_root
show_menu
