# Linux Shell

> 免责声明：该项目仅供个人学习、交流，请勿用于非法用途，请勿用于生产环境  

## bbr.sh
- 描述：为 TCP BBR 自动安装最新内核
- 教程：https://teddysun.com/489.html

```
wget --no-check-certificate -O bbr.sh https://raw.githubusercontent.com/ZCXYHQ/Linux/main/bbr.sh && bash bbr.sh
```

OR

```
wget --no-check-certificate -O bbr-teddysun.sh https://raw.githubusercontent.com/ZCXYHQ/Linux/main/bbr-teddysun.sh && bash bbr-teddysun.sh
```

- 检查bbr是否开启

```
sysctl net.ipv4.tcp_congestion_control | grep bbr
sysctl net.core.default_qdisc | grep fq
lsmod | grep bbr
```

- 删除多余内核

```
dpkg --list | grep linux-image
```

```
apt purge linux-image-***
```

## tools.sh
- 描述：优化TCP窗口

```
wget --no-check-certificate -O tools.sh https://raw.githubusercontent.com/ZCXYHQ/Linux/main/tools.sh && bash tools.sh
```

## wireguard.sh
- 描述：这是一个用于配置和启动 WireGuard VPN 服务器的 shell 脚本。
- 教程：https://teddysun.com/554.html

```
wget --no-check-certificate -O wireguard.sh https://raw.githubusercontent.com/ZCXYHQ/Linux/main/wireguard.sh
```

- 从代码编译安装 WireGuard

```
bash wireguard.sh -s
```

- 从 repository 直接安装 WireGuard

```
bash wireguard.sh -r
```

- 卸载

```
bash wireguard.sh -n
```

## mtr_trace.sh

- 描述：检测VPS回程国内三网路由
- 支持的线路为：电信CN2 GT，电信CN2 GIA，联通169，电信163，联通9929，联通4837，移动CMI

```
wget --no-check-certificate -O mtr_trace.sh https://raw.githubusercontent.com/ZCXYHQ/Linux/main/mtr_trace.sh && bash mtr_trace.sh
```

## bench.sh
- 描述：自动测试I/O & 上传下载速度脚本
- 教程：https://teddysun.com/444.html

```
wget --no-check-certificate -O bench.sh https://raw.githubusercontent.com/ZCXYHQ/Linux/main/bench.sh && bash bench.sh
```

OR

```
curl -Lso- bench.sh | bash
```

## yabs.sh

- 描述：使用fio、iPerform3和Geekbench评估Linux服务器性能。
- -b 强制使用来自 repo 的预编译二进制文件，而不是本地包；
- -f/d 禁用 fio (磁盘性能) 测试；
- -i 禁用 iPerf (网络性能) 测试；
- -g 禁用 Geekbench (系统性能) 测试
- -h 打印帮助信息，包括用法、检测到的标志和本地包 (fio/iperf) 的状态；
- -r 减少 iPerf 位置的数量 (Online.net/Clouvider LON+NYC) 以减少带宽的使用；
- -4 停用 Geekbench 5 而转为运行 Geekbench 4 测试；
- -9 在 Geekbench 5 及 Geekbench 4 测试；

```
wget --no-check-certificate -O yabs.sh https://raw.githubusercontent.com/ZCXYHQ/Linux/main/yabs.sh && bash yabs.sh
```

## backup.sh
- 运行前必须修改配置
- 备份 MySQL 或 MariaDB 数据库、文件和目录
- 备份文件使用 AES256-cbc 和 SHA1 消息摘要加密（取决于openssl命令）（选项）
- 自动将备份文件传输到 Google Drive（取决于rclone命令）（选项）
- 自动传输备份文件到 FTP 服务器（取决于ftp命令）（选项）
- 从 Google Drive 或 FTP 服务器自动删除远程文件（选项）
- 教程：https://teddysun.com/469.html
