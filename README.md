# Linux Shell

> 免责声明：该项目仅供个人学习、交流，请勿用于非法用途，请勿用于生产环境  

### bbr.sh
- 描述：为 TCP BBR 自动安装最新内核
- 教程：https://teddysun.com/489.html

```
wget -N "https://github.com/ZCXYHQ/Linux/releases/download/Linux/bbr.sh" -O bbr.sh && bash bbr.sh
```

OR

```
wget --no-check-certificate -O /opt/bbr-teddysun.sh https://raw.githubusercontent.com/ZCXYHQ/Linux/main/bbr-teddysun.sh
chmod 755 /opt/bbr-teddysun.sh
/opt/bbr-teddysun.sh
```

### tools.sh
- 描述：优化TCP窗口

```
wget https://github.com/ZCXYHQ/Linux/releases/download/Linux/tools.sh -O tools.sh && bash tools.sh
```

### wireguard.sh
- 描述：这是一个用于配置和启动 WireGuard VPN 服务器的 shell 脚本。
- 教程：https://teddysun.com/554.html

```
wget --no-check-certificate -O /opt/wireguard.sh https://raw.githubusercontent.com/teddysun/across/master/wireguard.sh
chmod 755 /opt/wireguard.sh
```

### bench.sh
- 描述：自动测试I/O & 上传下载速度脚本
- 教程：https://teddysun.com/444.html

```
wget -qO- bench.sh | bash
```

OR

```
curl -Lso- bench.sh | bash
```

### backup.sh
- 运行前必须修改配置
- 备份 MySQL 或 MariaDB 数据库、文件和目录
- 备份文件使用 AES256-cbc 和 SHA1 消息摘要加密（取决于openssl命令）（选项）
- 自动将备份文件传输到 Google Drive（取决于rclone命令）（选项）
- 自动传输备份文件到 FTP 服务器（取决于ftp命令）（选项）
- 从 Google Drive 或 FTP 服务器自动删除远程文件（选项）
- 教程：https://teddysun.com/469.html
