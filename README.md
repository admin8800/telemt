## telemt
TG代理

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

## 一键脚本
```
curl -fsSL https://raw.githubusercontent.com/admin8800/telemt/main/install.sh | sh
```
带参数
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

## 频道推广TAG

1. 在 Telegram 打开 [@MTProxybot](https://t.me/MTProxybot)
2. 发送 `/newproxy`
3. 发送服务器 IP 和端口，例如：`1.2.3.4:8443`
4. 把配置里用户的 secret 发给机器人
5. 机器人会返回一个 **32 位 hex 的 tag**，例如：`a1b2c3d4e5f6789012345678abcdef01`

> 不要用机器人给的连接链接，用你自己脚本输出的 `tg://proxy?...` 链接。


**一句话**：先去 @MTProxybot 拿 tag，再用 `-a` 传给安装脚本，最后在机器人里设置要推广的频道。
