# Linux Shell

> 免责声明：该项目仅供个人学习、交流，请勿用于非法用途，请勿用于生产环境  

## bbr.sh
- 描述：为 TCP BBR 自动安装最新内核

```
wget --no-check-certificate -O bbr.sh https://raw.githubusercontent.com/Moorigin/Shell/main/bbr.sh && bash bbr.sh
```

- 检查bbr是否开启

```
sysctl net.core.default_qdisc | grep fq
# 若已开启bbr，结果如下：
net.core.default_qdisc = fq
```

- 删除多余内核

```
dpkg --list | grep linux-image
```

```
apt purge linux-image-***
```

## gb6-test.sh
- 描述：cpu基准测试

```
wget --no-check-certificate -O gb6-test.sh https://raw.githubusercontent.com/Moorigin/Shell/main/gb6-test.sh && chmod +x gb6-test.sh && ./gb6-test.sh
```

## iptables.sh
- 描述：IPTables端口转发管理工具
- 需要先安装iptables-persistent工具
```
sudo apt install iptables-persistent
```

```
wget --no-check-certificate -O tools.sh https://raw.githubusercontent.com/Moorigin/Shell/main/iptables.sh && chmod +x iptables.sh && ./iptables.sh
```

## tools.sh
- 描述：优化TCP窗口

```
wget --no-check-certificate -O tools.sh https://raw.githubusercontent.com/Moorigin/Shell/main/tools.sh && chmod +x tools.sh && ./tools.sh
```

## swap.sh
- 描述：添加SWAP分区

```
wget --no-check-certificate -O swap.sh https://raw.githubusercontent.com/Moorigin/Shell/main/swap.sh && chmod +x swap.sh && ./swap.sh
```
