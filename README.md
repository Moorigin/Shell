# Linux Shell

> 免责声明：该项目仅供个人学习、交流，请勿用于非法用途，请勿用于生产环境  

## bbr.sh
- 描述：为 TCP BBR 自动安装最新内核

```
wget --no-check-certificate -O bbr.sh https://raw.githubusercontent.com/Moorigin/Linux/main/bbr.sh && bash bbr.sh
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

## tools.sh
- 描述：优化TCP窗口

```
wget --no-check-certificate -O tools.sh https://raw.githubusercontent.com/Moorigin/Linux/main/tools.sh && chmod +x tools.sh && ./tools.sh
```

## swap.sh
- 描述：添加SWAP分区

```
wget --no-check-certificate -O swap.sh https://raw.githubusercontent.com/Moorigin/Linux/main/swap.sh && chmod +x swap.sh && ./swap.sh
```
