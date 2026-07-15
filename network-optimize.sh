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
FORWARDING_SYSCTL_CONFIG="${SYSCTL_DIR}/99-network-forwarding.conf"
LEGACY_SYSCTL_CONFIG="/etc/sysctl.conf"

###################
# 辅助函数
###################
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误：此脚本需要root权限运行${NC}"
        exit 1
    fi

    while true; do
        show_menu
        select_function
    done
}

show_menu() {
    clear
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Linux网络优化工具            ${NC}"
    echo -e "${CYAN}Powered by Moorigin         ${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}1. TCP网络优化（4M）          ${NC}"
    echo -e "${CYAN}2. TCP网络优化（16M）         ${NC}"
    echo -e "${CYAN}3. 屏蔽IPv4/IPv6 Ping        ${NC}"
    echo -e "${CYAN}4. 放开IPv4/IPv6 Ping        ${NC}"
    echo -e "${CYAN}5. 开启IPv4/IPv6转发         ${NC}"
    echo -e "${CYAN}6. 关闭IPv4/IPv6转发         ${NC}"
    echo -e "${CYAN}0. 退出程序                  ${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "请输入选项 [0-6]: "
}

select_function() {
    local choice
    if ! read -r choice; then
        echo
        exit 0
    fi
    
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
            echo -e "${GREEN}正在屏蔽IPv4/IPv6 Ping响应...${NC}"
            shield_icmp
            ;;
        4)
            echo -e "${GREEN}正在放开IPv4/IPv6 Ping响应...${NC}"
            open_icmp
            ;;
        5)
            echo -e "${GREEN}正在开启IPv4/IPv6转发...${NC}"
            enable_ip_forwarding
            ;;
        6)
            echo -e "${GREEN}正在关闭IPv4/IPv6转发...${NC}"
            disable_ip_forwarding
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
    echo -e "${YELLOW}操作完成，按回车键返回主菜单...${NC}"
    read -r
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

write_icmp_config() {
	local ignore_all=$1

	install -d -m 0755 "$SYSCTL_DIR"
	remove_sysctl_keys "$LEGACY_SYSCTL_CONFIG" \
		net.ipv4.icmp_echo_ignore_broadcasts \
		net.ipv4.icmp_echo_ignore_all \
		net.ipv6.icmp.echo_ignore_all

	cat > "$ICMP_SYSCTL_CONFIG" << EOF
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_echo_ignore_all = ${ignore_all}
net.ipv6.icmp.echo_ignore_all = ${ignore_all}
EOF

	sysctl -p "$ICMP_SYSCTL_CONFIG"
}

shield_icmp() {
	if write_icmp_config 1; then
		echo -e "${GREEN}IPv4/IPv6 Ping响应已成功屏蔽！${NC}"
	else
		echo -e "${RED}IPv4/IPv6 Ping响应屏蔽失败，请检查系统日志${NC}"
	fi
}

open_icmp() {
	if write_icmp_config 0; then
		echo -e "${GREEN}IPv4/IPv6 Ping响应已成功开放！${NC}"
	else
		echo -e "${RED}IPv4/IPv6 Ping响应开放失败，请检查系统日志${NC}"
	fi
}

get_route_interface() {
	local family=$1

	ip "-${family}" route show default 2>/dev/null |
		awk '{
			for (i = 1; i < NF; i++) {
				if ($i == "dev") {
					print $(i + 1)
					exit
				}
			}
		}'
}

get_public_ipv6_interface() {
	# IPv6默认路由丢失时，优先从仍然存在的公网IPv6地址恢复网卡名。
	# 2000::/3的首个十六进制字符为2或3；这会排除docker0等ULA地址。
	ip -o -6 addr show scope global 2>/dev/null |
		awk '{
			address = tolower($4)
			sub(/\/.*/, "", address)
			if (address ~ /^[23]/) {
				print $2
				exit
			}
		}'
}

get_saved_forward_interface() {
	[[ -f $FORWARDING_SYSCTL_CONFIG ]] || return 1

	awk -F= '/^# public_interface=/ {print $2; exit}' \
		"$FORWARDING_SYSCTL_CONFIG"
}

detect_forward_interface() {
	local interface

	if [[ -n ${FORWARD_INTERFACE:-} ]]; then
		printf '%s\n' "$FORWARD_INTERFACE"
		return 0
	fi

	interface=$(get_route_interface 6)
	[[ -n $interface ]] || interface=$(get_route_interface 4)
	[[ -n $interface ]] || interface=$(get_public_ipv6_interface)
	[[ -n $interface ]] || interface=$(get_saved_forward_interface)

	[[ -n $interface ]] && printf '%s\n' "$interface"
}

validate_forward_interface() {
	local interface=$1

	if [[ ! $interface =~ ^[[:alnum:]_.:-]+$ ]]; then
		echo -e "${RED}错误：检测到无效网卡名称：${interface}${NC}" >&2
		return 1
	fi

	if [[ ! -d /sys/class/net/$interface ]]; then
		echo -e "${RED}错误：网卡不存在：${interface}${NC}" >&2
		return 1
	fi

	if [[ ! -e /proc/sys/net/ipv6/conf/$interface/accept_ra ]]; then
		echo -e "${RED}错误：网卡${interface}没有可用的IPv6 accept_ra配置${NC}" >&2
		return 1
	fi
}

get_forward_interface() {
	local required=${1:-1}
	local interface

	interface=$(detect_forward_interface)
	if [[ -z $interface ]]; then
		if [[ $required -eq 1 ]]; then
			echo -e "${RED}错误：无法识别公网网卡${NC}" >&2
		fi
		return 1
	fi

	validate_forward_interface "$interface" || return 1
	printf '%s\n' "$interface"
}

set_sysctl_value() {
	local key=$1
	local value=$2

	sysctl -q -w "${key}=${value}"
}

verify_sysctl_value() {
	local key=$1
	local expected=$2
	local actual

	actual=$(sysctl -n "$key" 2>/dev/null) || return 1
	[[ $actual == "$expected" ]]
}

restore_forwarding_state() {
	local interface=$1
	local old_ipv4=$2
	local old_ipv6_all=$3
	local old_ipv6_default=$4
	local old_ra_default=$5
	local old_ra_interface=$6
	local interface_key

	set_sysctl_value net.ipv6.conf.default.accept_ra "$old_ra_default" \
		>/dev/null 2>&1 || true

	if [[ -n $interface ]]; then
		interface_key="net/ipv6/conf/${interface}/accept_ra"
		set_sysctl_value "$interface_key" "$old_ra_interface" \
			>/dev/null 2>&1 || true
	fi

	set_sysctl_value net.ipv4.ip_forward "$old_ipv4" \
		>/dev/null 2>&1 || true
	set_sysctl_value net.ipv6.conf.default.forwarding "$old_ipv6_default" \
		>/dev/null 2>&1 || true
	set_sysctl_value net.ipv6.conf.all.forwarding "$old_ipv6_all" \
		>/dev/null 2>&1 || true
}

write_forwarding_config_file() {
	local enabled=$1
	local interface=$2
	local temp_file

	install -d -m 0755 "$SYSCTL_DIR" || return 1
	temp_file=$(mktemp "${SYSCTL_DIR}/.99-network-forwarding.conf.XXXXXX") || return 1

	if [[ $enabled -eq 1 ]]; then
		if ! {
			printf '%s\n' '# 由network-optimize.sh管理，请勿手动修改'
			printf '# public_interface=%s\n' "$interface"
			printf '%s\n' 'net.ipv6.conf.default.accept_ra = 2'
			printf 'net/ipv6/conf/%s/accept_ra = 2\n' "$interface"
			printf '%s\n' 'net.ipv4.ip_forward = 1'
			printf '%s\n' 'net.ipv6.conf.default.forwarding = 1'
			printf '%s\n' 'net.ipv6.conf.all.forwarding = 1'
		} > "$temp_file"; then
			rm -f "$temp_file"
			return 1
		fi
	else
		if ! {
			printf '%s\n' '# 由network-optimize.sh管理，请勿手动修改'
			[[ -z $interface ]] || printf '# public_interface=%s\n' "$interface"
			printf '%s\n' 'net.ipv4.ip_forward = 0'
			printf '%s\n' 'net.ipv6.conf.all.forwarding = 0'
			printf '%s\n' 'net.ipv6.conf.default.forwarding = 0'
			printf '%s\n' 'net.ipv6.conf.default.accept_ra = 1'
			[[ -z $interface ]] || printf 'net/ipv6/conf/%s/accept_ra = 1\n' "$interface"
		} > "$temp_file"; then
			rm -f "$temp_file"
			return 1
		fi
	fi

	if ! chmod 0644 "$temp_file" || \
		! mv -f "$temp_file" "$FORWARDING_SYSCTL_CONFIG"; then
		rm -f "$temp_file"
		return 1
	fi
}

clean_legacy_forwarding_config() {
	local interface=$1

	remove_sysctl_keys "$LEGACY_SYSCTL_CONFIG" \
		net.ipv4.ip_forward \
		net.ipv6.conf.all.forwarding \
		net.ipv6.conf.default.forwarding \
		net.ipv6.conf.default.accept_ra

	if [[ -n $interface ]]; then
		remove_sysctl_keys "$LEGACY_SYSCTL_CONFIG" \
			"net.ipv6.conf.${interface}.accept_ra" \
			"net/ipv6/conf/${interface}/accept_ra"
	fi
}

configure_ip_forwarding() {
	local enabled=$1
	local interface=""
	local interface_key=""
	local old_ipv4 old_ipv6_all old_ipv6_default
	local old_ra_default old_ra_interface=""
	local desired_forwarding desired_ra

	if [[ $enabled -eq 1 ]]; then
		interface=$(get_forward_interface 1) || return 1
	else
		interface=$(get_forward_interface 0) || true
		if [[ -z $interface ]]; then
			echo -e "${YELLOW}警告：未识别到公网网卡，将先关闭全局转发${NC}"
		fi
	fi

	if [[ -n $interface ]]; then
		interface_key="net/ipv6/conf/${interface}/accept_ra"
		echo -e "${YELLOW}检测到公网网卡：${interface}${NC}"
	fi

	if ! old_ipv4=$(sysctl -n net.ipv4.ip_forward 2>/dev/null) || \
		! old_ipv6_all=$(sysctl -n net.ipv6.conf.all.forwarding 2>/dev/null) || \
		! old_ipv6_default=$(sysctl -n net.ipv6.conf.default.forwarding 2>/dev/null) || \
		! old_ra_default=$(sysctl -n net.ipv6.conf.default.accept_ra 2>/dev/null); then
		echo -e "${RED}错误：无法读取当前转发配置${NC}" >&2
		return 1
	fi

	if [[ -n $interface ]] && \
		! old_ra_interface=$(sysctl -n "$interface_key" 2>/dev/null); then
		echo -e "${RED}错误：无法读取${interface}的accept_ra配置${NC}" >&2
		return 1
	fi

	if [[ $enabled -eq 1 ]]; then
		desired_forwarding=1
		desired_ra=2

		# 必须先让当前网卡在转发模式下继续接受RA，再开启IPv6转发。
		if ! set_sysctl_value net.ipv6.conf.default.accept_ra "$desired_ra" || \
			! set_sysctl_value "$interface_key" "$desired_ra" || \
			! set_sysctl_value net.ipv4.ip_forward "$desired_forwarding" || \
			! set_sysctl_value net.ipv6.conf.default.forwarding "$desired_forwarding" || \
			! set_sysctl_value net.ipv6.conf.all.forwarding "$desired_forwarding"; then
			restore_forwarding_state "$interface" "$old_ipv4" "$old_ipv6_all" \
				"$old_ipv6_default" "$old_ra_default" "$old_ra_interface"
			echo -e "${RED}错误：转发设置失败，已尝试恢复原配置${NC}" >&2
			return 1
		fi
	else
		desired_forwarding=0
		desired_ra=1

		# 按已验证可恢复IPv6 RA默认路由的顺序关闭转发。
		if ! set_sysctl_value net.ipv4.ip_forward "$desired_forwarding" || \
			! set_sysctl_value net.ipv6.conf.all.forwarding "$desired_forwarding" || \
			! set_sysctl_value net.ipv6.conf.default.forwarding "$desired_forwarding" || \
			! set_sysctl_value net.ipv6.conf.default.accept_ra "$desired_ra" || \
			{ [[ -n $interface ]] && ! set_sysctl_value "$interface_key" "$desired_ra"; }; then
			restore_forwarding_state "$interface" "$old_ipv4" "$old_ipv6_all" \
				"$old_ipv6_default" "$old_ra_default" "$old_ra_interface"
			echo -e "${RED}错误：转发关闭失败，已尝试恢复原配置${NC}" >&2
			return 1
		fi
	fi

	if ! verify_sysctl_value net.ipv4.ip_forward "$desired_forwarding" || \
		! verify_sysctl_value net.ipv6.conf.all.forwarding "$desired_forwarding" || \
		! verify_sysctl_value net.ipv6.conf.default.forwarding "$desired_forwarding" || \
		! verify_sysctl_value net.ipv6.conf.default.accept_ra "$desired_ra" || \
		{ [[ -n $interface ]] && ! verify_sysctl_value "$interface_key" "$desired_ra"; }; then
		restore_forwarding_state "$interface" "$old_ipv4" "$old_ipv6_all" \
			"$old_ipv6_default" "$old_ra_default" "$old_ra_interface"
		echo -e "${RED}错误：转发配置校验失败，已尝试恢复原配置${NC}" >&2
		return 1
	fi

	if ! write_forwarding_config_file "$enabled" "$interface"; then
		restore_forwarding_state "$interface" "$old_ipv4" "$old_ipv6_all" \
			"$old_ipv6_default" "$old_ra_default" "$old_ra_interface"
		echo -e "${RED}错误：持久化配置失败，已尝试恢复原配置${NC}" >&2
		return 1
	fi

	if ! clean_legacy_forwarding_config "$interface"; then
		echo -e "${YELLOW}警告：/etc/sysctl.conf中的旧转发配置清理失败${NC}" >&2
	fi
}

enable_ip_forwarding() {
	if configure_ip_forwarding 1; then
		echo -e "${GREEN}IPv4/IPv6转发已成功开启！${NC}"
		echo -e "${YELLOW}当前公网网卡accept_ra=2，IPv6 RA默认路由将继续保留${NC}"
	else
		echo -e "${RED}IPv4/IPv6转发开启失败${NC}"
	fi
}

disable_ip_forwarding() {
	if configure_ip_forwarding 0; then
		echo -e "${GREEN}IPv4/IPv6转发已成功关闭！${NC}"
		echo -e "${YELLOW}IPv6 accept_ra已恢复为1${NC}"
	else
		echo -e "${RED}IPv4/IPv6转发关闭失败${NC}"
	fi
}

###################
# 主程序
###################
check_root
