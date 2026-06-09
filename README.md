# telemt
TG代理

```
docker run -d \
  --name telemt \
  --restart unless-stopped \
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
```
doker logs telemt
```
