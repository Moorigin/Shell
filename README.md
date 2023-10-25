# Linux Shell

> 免责声明：该项目仅供个人学习、交流，请勿用于非法用途，请勿用于生产环境  

## bbr.sh
- 描述：为 TCP BBR 自动安装最新内核

```
wget --no-check-certificate -O bbr.sh https://raw.githubusercontent.com/ZCXYHQ/Linux/main/bbr.sh && bash bbr.sh
```

OR

```
wget --no-check-certificate -O bbr-teddysun.sh https://raw.githubusercontent.com/ZCXYHQ/Linux/main/bbr-teddysun.sh && bash bbr-teddysun.sh
```

- 检查bbr是否开启

```
sysctl net.ipv4.tcp_available_congestion_control | grep bbr
# 若已开启bbr，结果通常为以下两种：
net.ipv4.tcp_available_congestion_control = bbr cubic reno
net.ipv4.tcp_available_congestion_control = reno cubic bbr
```

```
sysctl net.ipv4.tcp_congestion_control | grep bbr
# 若已开启bbr，结果如下：
net.ipv4.tcp_congestion_control = bbr
```

```
sysctl net.core.default_qdisc | grep fq
# 若已开启bbr，结果如下：
net.core.default_qdisc = fq
```

```
lsmod | grep bbr
# 若已开启bbr，结果可能如下。并不是所有的 VPS 都会有此返回值，若没有也属正常。
tcp_bbr                20480  2
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

