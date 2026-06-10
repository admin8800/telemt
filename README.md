## TG代理最新rust版

### 系统支持说明

| 类型 | 发行版 | 服务管理 | 包管理 |
|------|--------|----------|--------|
| Debian 系 | Debian、Ubuntu 等 | systemd | apt-get |
| RHEL 系 | CentOS、Rocky Linux、AlmaLinux 等 | systemd | yum / dnf |
| Alpine | Alpine Linux | openrc | apk |
| 其他 Linux | 具备 systemd 或 openrc 的发行版 | 自动识别 | 视环境而定 |

> 若系统无 systemd / openrc，脚本仍可安装程序与配置，但需手动启动服务。

---

### CPU 架构支持说明

| 架构 | 支持 | 说明 |
|------|------|------|
| x86_64 / amd64 | ✅ | CPU 支持 AVX2 + BMI2 时优先下载 `x86_64-v3`，失败自动回退 `x86_64` |
| aarch64 / arm64 | ✅ | 适用于 ARM 服务器（如部分云 ARM 实例） |


### Docker部署
```
docker run -d \
  --name telemt \
  --restart always \
  -p 443:443 \
  -p 127.0.0.1:9091:9091 \
  --tmpfs /run/telemt:rw,mode=1777,size=4m \
  --cap-drop ALL \
  --cap-add NET_BIND_SERVICE \
  --read-only \
  --security-opt no-new-privileges:true \
  --ulimit nofile=65536:262144 \
  ghcr.io/admin8800/telemt
```
查看链接信息
```
doker logs telemt
```
查看配置文件
```
docker exec -it telemt sh -c 'cat /run/telemt/config.toml'
```

### 一键脚本部署
```
curl -fsSL https://raw.githubusercontent.com/admin8800/telemt/main/install.sh | sh
```
可带参数
```
# 指定域名和端口
curl -fsSL https://raw.githubusercontent.com/admin8800/telemt/main/install.sh | sudo sh -s -- install -d www.bing.com -p 8443

# 安装完成后补TAG频道推广，@MTProxybot 给你的 32 位十六进制标签
curl -fsSL https://raw.githubusercontent.com/admin8800/telemt/main/install.sh | sudo sh -s -- install -a a1b2c3d4e5f6789012345678abcdef01

# 完全卸载
curl -fsSL https://raw.githubusercontent.com/admin8800/telemt/main/install.sh | sudo sh -s -- purge

# 查看帮助
curl -fsSL https://raw.githubusercontent.com/admin8800/telemt/main/install.sh | sh -s -- --help
```
配置文件路径：`/etc/telemt/telemt.toml`，使用一键脚本重复安装时，其他自定义的配置会保持不变。

### 系统服务管理命令
```
# 查看状态
sudo systemctl status telemt

# 启动
sudo systemctl start telemt

# 停止
sudo systemctl stop telemt

# 重启（改配置后常用）
sudo systemctl restart telemt

# 查看日志（实时）
sudo journalctl -u telemt -f
```

### 代理

说明：`你的设备 → telemt → 走代理 → TG服务器`

```
[[upstreams]]
type = "socks5"
address = "1.2.3.4:1080"
weight = 1
enabled = true
```

### 频道推广TAG

1. 在 Telegram 打开 [@MTProxybot](https://t.me/MTProxybot)
2. 发送 `/newproxy`
3. 发送服务器 IP 和端口，例如：`1.2.3.4:8443`
4. 把配置里用户的 secret 发给机器人
5. 机器人会返回一个 **32 位十六进制标签**，例如：`a1b2c3d4e5f6789012345678abcdef01`

> 不要用机器人给的连接链接，用你自己脚本输出的 `tg://proxy?...` 链接。


**一句话**：先去 @MTProxybot 拿 tag，再用 `-a` 传给安装脚本，最后在机器人里设置要推广的频道。

---

### 鸣谢

原项目地址：https://github.com/telemt/telemt
