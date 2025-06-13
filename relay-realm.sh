#!/bin/bash

###################
# 颜色定义
###################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

###################
# 全局变量
###################
REALM_DIR="/usr/local/bin"
SERVICE_FILE="/etc/systemd/system/realm.service"
CONFIG_FILE="/root/realm/config.toml"

###################
# 辅助函数
###################
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误：请使用root权限运行此脚本${NC}"
        exit 1
    fi
}

get_arch() {
    case $(uname -m) in
        x86_64) echo "x86_64" ;;
        aarch64|arm64) echo "aarch64" ;;
        armv7l) echo "armv7" ;;
        *) 
            echo -e "${RED}不支持的系统架构: $(uname -m)${NC}"
            exit 1
            ;;
    esac
}

print_banner() {
    clear
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Realm端口转发管理工具              ${NC}"
    echo -e "${CYAN}Powered by Moorigin               ${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

show_menu() {
    while true; do
        print_banner
        echo -e "${YELLOW}请选择操作：${NC}"
        echo "1. 安装Realm"
        echo "2. 设置开机自启"
        echo "3. 检查系统状态"
        echo "0. 退出"
        echo ""
        echo -e "${YELLOW}注意：配置文件请手动导入到 $CONFIG_FILE${NC}"
        echo ""
        
        read -p "请选择操作 [0-3]: " choice
        
        case $choice in
            1)
                install_realm
                read -p "按回车键继续..."
                ;;
            2)
                if [[ ! -f "$REALM_DIR/realm" ]]; then
                    echo -e "${RED}请先安装Realm${NC}"
                    read -p "按回车键继续..."
                    continue
                fi
                create_service
                read -p "按回车键继续..."
                ;;
            3)
                check_status
                read -p "按回车键继续..."
                ;;
            0)
                echo -e "${GREEN}退出脚本${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                read -p "按回车键继续..."
                ;;
        esac
    done
}

###################
# 功能函数
###################
install_realm() {
    echo -e "${YELLOW}开始安装Realm...${NC}"
    
    # 获取最新版本
    echo "获取最新版本信息..."
    LATEST_VERSION=$(curl -s https://api.github.com/repos/zhboner/realm/releases/latest | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4)
    
    if [[ -z "$LATEST_VERSION" ]]; then
        echo -e "${RED}获取版本信息失败${NC}"
        exit 1
    fi
    
    echo "最新版本: $LATEST_VERSION"
    
    # 获取系统架构
    ARCH=$(get_arch)
    
    # 下载文件
    DOWNLOAD_URL="https://github.com/zhboner/realm/releases/download/${LATEST_VERSION}/realm-${ARCH}-unknown-linux-musl.tar.gz"
    
    echo "下载中..."
    cd /tmp
    wget -O realm.tar.gz "$DOWNLOAD_URL"
    
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}下载失败${NC}"
        exit 1
    fi
    
    # 解压安装
    tar -xzf realm.tar.gz
    chmod +x realm
    mv realm $REALM_DIR/
    
    echo -e "${GREEN}Realm安装完成${NC}"
    cleanup_temp
}

create_service() {
    echo -e "${YELLOW}创建systemd服务...${NC}"
    
    cat > $SERVICE_FILE << EOF
[Unit]
Description=Realm Port Forward
After=network.target

[Service]
Type=simple
ExecStart=$REALM_DIR/realm -c $CONFIG_FILE
Restart=on-failure
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable realm
    echo -e "${GREEN}开机自启设置完成${NC}"
}

cleanup_temp() {
    rm -f /tmp/realm.tar.gz /tmp/realm
}

check_status() {
    echo -e "${YELLOW}=== Realm系统状态 ===${NC}"
    
    # 检查程序是否存在
    if [[ -f "$REALM_DIR/realm" ]]; then
        VERSION=$($REALM_DIR/realm --version 2>/dev/null | head -n1)
        echo -e "程序状态: ${GREEN}已安装${NC} ($VERSION)"
    else
        echo -e "程序状态: ${RED}未安装${NC}"
        return
    fi
    
    # 检查配置文件
    if [[ -f "$CONFIG_FILE" ]]; then
        echo -e "配置文件: ${GREEN}存在${NC} ($CONFIG_FILE)"
    else
        echo -e "配置文件: ${RED}不存在${NC} ($CONFIG_FILE)"
    fi
    
    # 检查服务状态
    if systemctl is-enabled realm >/dev/null 2>&1; then
        echo -e "开机自启: ${GREEN}已启用${NC}"
    else
        echo -e "开机自启: ${RED}未启用${NC}"
    fi
    
    # 检查运行状态
    if systemctl is-active realm >/dev/null 2>&1; then
        echo -e "运行状态: ${GREEN}运行中${NC}"
        
        # 显示进程信息
        PID=$(pgrep -f "realm.*config.toml")
        if [[ -n "$PID" ]]; then
            echo "进程PID: $PID"
            
            # 显示端口监听
            echo "监听端口:"
            netstat -tlnp 2>/dev/null | grep "$PID" | awk '{print "  " $4}'
        fi
    else
        echo -e "运行状态: ${RED}未运行${NC}"
        
        # 显示服务日志
        echo "最近日志:"
        journalctl -u realm --no-pager -n 3 --since "1 hour ago" 2>/dev/null | tail -n 3
    fi
    
    echo ""
    echo -e "${YELLOW}=== 系统信息 ===${NC}"
    echo "系统架构: $(uname -m)"
    echo "内核版本: $(uname -r)"
    echo "系统负载: $(uptime | awk -F'load average:' '{print $2}')"
}

###################
# 主程序
###################
check_root
show_menu
