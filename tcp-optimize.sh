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
    echo -e "${CYAN}1. TCP网络优化               ${NC}"
    echo -e "${CYAN}2. 屏蔽ICMP                  ${NC}"
    echo -e "${CYAN}3. 放开ICMP                  ${NC}"
    echo -e "${CYAN}0. 退出程序                  ${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "请输入选项 [0-3]: "
}

select_function() {
    local choice
    read -r choice
    
    case $choice in
        1)
            echo -e "${GREEN}执行TCP网络优化...${NC}"
            tcp_optimize
            ;;
        2)
            echo -e "${GREEN}执行屏蔽ICMP请求...${NC}"
            shield_icmp
            ;;
        3)
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
tcp_optimize() {
	#清除IP转发配置
	sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
	sed -i '/net.ipv6.conf.all.forwarding/d' /etc/sysctl.conf
	sed -i '/net.ipv6.conf.default.forwarding/d' /etc/sysctl.conf
	sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
	sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf
	#清除拥塞控制配置
	sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
	#清除TCP缓冲区配置
	sed -i '/net.core.rmem_default/d' /etc/sysctl.conf
	sed -i '/net.core.rmem_default/d' /etc/sysctl.conf
	sed -i '/net.core.rmem_max/d' /etc/sysctl.conf
	sed -i '/net.core.wmem_max/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_rmem/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_wmem/d' /etc/sysctl.conf
	#写入新的配置
	cat >> /etc/sysctl.conf << EOF
#IP转发
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.default.forwarding = 1
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
#BBR优化
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
#TCP缓冲区优化
net.core.rmem_default = 87380
net.core.wmem_default = 65536
net.core.rmem_max = 8388608
net.core.wmem_max = 8388608
net.ipv4.tcp_rmem = 4096 87380 8388608
net.ipv4.tcp_wmem = 4096 65536 8388608
EOF
	if sysctl -p && sysctl --system; then
		echo -e "${GREEN}TCP网络优化配置成功应用！${NC}"
	else
		echo -e "${RED}TCP网络优化配置应用失败，请检查系统日志${NC}"
	fi
}

shield_icmp() {
	sed -i '/net.ipv4.icmp_echo_ignore_all/d' /etc/sysctl.conf
	sed -i '/net.ipv4.icmp_echo_ignore_broadcasts/d' /etc/sysctl.conf
	cat >> '/etc/sysctl.conf' << EOF
net.ipv4.icmp_echo_ignore_all=1
net.ipv4.icmp_echo_ignore_broadcasts=1
EOF
	if sysctl -p && sysctl --system; then
		echo -e "${GREEN}ICMP已成功屏蔽！${NC}"
	else
		echo -e "${RED}ICMP屏蔽失败，请检查系统日志${NC}"
	fi
}

open_icmp() {
	# 检查是否存在相关配置，如果不存在则添加
	if grep -q "net.ipv4.icmp_echo_ignore_all" /etc/sysctl.conf; then
		sed -i "s/net.ipv4.icmp_echo_ignore_all=1/net.ipv4.icmp_echo_ignore_all=0/g" /etc/sysctl.conf
	else
		echo "net.ipv4.icmp_echo_ignore_all=0" >> /etc/sysctl.conf
	fi
	
	if grep -q "net.ipv4.icmp_echo_ignore_broadcasts" /etc/sysctl.conf; then
		sed -i "s/net.ipv4.icmp_echo_ignore_broadcasts=1/net.ipv4.icmp_echo_ignore_broadcasts=0/g" /etc/sysctl.conf
	else
		echo "net.ipv4.icmp_echo_ignore_broadcasts=0" >> /etc/sysctl.conf
	fi
	
	if sysctl -p && sysctl --system; then
		echo -e "${GREEN}ICMP已成功开放！${NC}"
	else
		echo -e "${RED}ICMP开放失败，请检查系统日志${NC}"
	fi
}

###################
# 主程序
###################
check_root
