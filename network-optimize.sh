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
# sysctl配置文件
###################
# Debian 13的systemd-sysctl不再读取/etc/sysctl.conf，
# 本脚本使用/etc/sysctl.d中的独立配置片段，确保重启后仍然生效。
SYSCTL_DIR="/etc/sysctl.d"
TCP_SYSCTL_CONFIG="${SYSCTL_DIR}/99-network-optimize.conf"
ICMP_SYSCTL_CONFIG="${SYSCTL_DIR}/99-network-optimize-icmp.conf"
LEGACY_SYSCTL_CONFIG="/etc/sysctl.conf"

###################
# 辅助函数
###################
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误：此脚本需要root权限运行${NC}"
        exit 1
    fi
    show_menu
    select_function
}

show_menu() {
    clear
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Linux网络优化工具            ${NC}"
    echo -e "${CYAN}Powered by Moorigin         ${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}1. TCP网络优化（4M）          ${NC}"
    echo -e "${CYAN}2. TCP网络优化（16M）         ${NC}"
    echo -e "${CYAN}3. IPv4优先                  ${NC}"
    echo -e "${CYAN}4. IPv6优先                  ${NC}"
    echo -e "${CYAN}5. 屏蔽ICMP                  ${NC}"
    echo -e "${CYAN}6. 放开ICMP                  ${NC}"
    echo -e "${CYAN}0. 退出程序                  ${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "请输入选项 [0-6]: "
}

select_function() {
    local choice
    read -r choice
    
    case $choice in
        1)
            echo -e "${GREEN}执行TCP网络优化（4M）...${NC}"
            tcp_optimize_4M
            ;;
        2)
            echo -e "${GREEN}执行TCP网络优化（16M）...${NC}"
            tcp_optimize_16M
            ;;
        3)
            echo -e "${GREEN}设置IPv4优先...${NC}"
            set_ipv4_priority
            ;;
        4)
            echo -e "${GREEN}设置IPv6优先...${NC}"
            set_ipv6_priority
            ;;
        5)
            echo -e "${GREEN}执行屏蔽ICMP请求...${NC}"
            shield_icmp
            ;;
        6)
            echo -e "${GREEN}执行开放ICMP请求...${NC}"
            open_icmp
            ;;
        0)
            echo -e "${GREEN}感谢使用！${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}错误：无效的选项，请重新选择${NC}"
            ;;
    esac
    
    # 操作完成后暂停
    echo
    echo -e "${YELLOW}操作完成，按任意键返回主菜单...${NC}"
    read -n 1
    show_menu
    select_function
}

###################
# 功能函数
###################
remove_sysctl_keys() {
	local config_file=$1
	shift

	[[ -f $config_file ]] || return 0

	local key key_pattern
	for key in "$@"; do
		key_pattern=${key//./\\.}
		sed -i "\\|^[[:space:]]*${key_pattern}[[:space:]]*=|d" "$config_file"
	done
}

clean_legacy_tcp_config() {
	# 清理旧版本脚本写入/etc/sysctl.conf的同名配置，避免手动运行
	# sysctl --system时旧值覆盖本脚本的配置。
	remove_sysctl_keys "$LEGACY_SYSCTL_CONFIG" \
		net.ipv4.ip_forward \
		net.ipv6.conf.all.forwarding \
		net.ipv6.conf.default.forwarding \
		net.ipv6.conf.all.disable_ipv6 \
		net.ipv6.conf.default.disable_ipv6 \
		net.core.default_qdisc \
		net.ipv4.tcp_congestion_control \
		net.ipv4.tcp_moderate_rcvbuf \
		net.core.rmem_default \
		net.core.wmem_default \
		net.core.rmem_max \
		net.core.wmem_max \
		net.ipv4.tcp_rmem \
		net.ipv4.tcp_wmem
}

write_tcp_config() {
	local max_buffer=$1

	install -d -m 0755 "$SYSCTL_DIR"
	clean_legacy_tcp_config

	cat > "$TCP_SYSCTL_CONFIG" << EOF
# 由network-optimize.sh管理
# IP转发
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.default.forwarding = 1
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
# TCP调优
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_moderate_rcvbuf = 1
net.core.rmem_default = 87380
net.core.wmem_default = 65536
net.core.rmem_max = ${max_buffer}
net.core.wmem_max = ${max_buffer}
net.ipv4.tcp_rmem = 4096 87380 ${max_buffer}
net.ipv4.tcp_wmem = 4096 65536 ${max_buffer}
EOF

	# 立即加载本脚本的配置；重启时由systemd-sysctl自动加载。
	sysctl -p "$TCP_SYSCTL_CONFIG"
}

tcp_optimize_4M() {
	if write_tcp_config 4194304; then
		echo -e "${GREEN}TCP网络优化配置成功应用！${NC}"
	else
		echo -e "${RED}TCP网络优化配置应用失败，请检查系统日志${NC}"
	fi
}

tcp_optimize_16M() {
	if write_tcp_config 16777216; then
		echo -e "${GREEN}TCP网络优化配置成功应用！${NC}"
	else
		echo -e "${RED}TCP网络优化配置应用失败，请检查系统日志${NC}"
	fi
}

set_ipv4_priority() {
	echo -e "${CYAN}正在配置IPv4优先...${NC}"
	
	# 配置gai.conf使IPv4优先
	cat > /etc/gai.conf << EOF
# Configuration for getaddrinfo(3).
# IPv4优先配置
precedence ::ffff:0:0/96  100
EOF
	
	echo -e "${GREEN}IPv4优先设置完成（IPv6仍然启用）！${NC}"
	echo -e "${YELLOW}提示：某些应用可能需要重启才能生效${NC}"
}

set_ipv6_priority() {
	echo -e "${CYAN}正在恢复IPv6优先...${NC}"
	
	# 恢复为默认配置（IPv6优先）
	cat > /etc/gai.conf << EOF
# Configuration for getaddrinfo(3).
# 默认配置（IPv6优先）
EOF
	
	echo -e "${GREEN}IPv6优先已恢复！${NC}"
	echo -e "${YELLOW}提示：某些应用可能需要重启才能生效${NC}"
}

write_icmp_config() {
	local ignore_all=$1
	local ignore_broadcasts=$2

	install -d -m 0755 "$SYSCTL_DIR"
	remove_sysctl_keys "$LEGACY_SYSCTL_CONFIG" \
		net.ipv4.icmp_echo_ignore_all \
		net.ipv4.icmp_echo_ignore_broadcasts

	cat > "$ICMP_SYSCTL_CONFIG" << EOF
# 由network-optimize.sh管理
net.ipv4.icmp_echo_ignore_all = ${ignore_all}
net.ipv4.icmp_echo_ignore_broadcasts = ${ignore_broadcasts}
EOF

	sysctl -p "$ICMP_SYSCTL_CONFIG"
}

shield_icmp() {
	if write_icmp_config 1 1; then
		echo -e "${GREEN}ICMP已成功屏蔽！${NC}"
	else
		echo -e "${RED}ICMP屏蔽失败，请检查系统日志${NC}"
	fi
}

open_icmp() {
	if write_icmp_config 0 0; then
		echo -e "${GREEN}ICMP已成功开放！${NC}"
	else
		echo -e "${RED}ICMP开放失败，请检查系统日志${NC}"
	fi
}

###################
# 主程序
###################
check_root
