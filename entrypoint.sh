#!/bin/sh
set -eu

CONFIG_TEMPLATE="/etc/telemt/config.toml.template"
RUNTIME_DIR="/run/telemt"
CONFIG_FILE="$RUNTIME_DIR/config.toml"
USERS_JSON="$RUNTIME_DIR/telemt-users.json"
API_URL="http://127.0.0.1:9091/v1/users"

log() {
    echo "[Telemt] $*"
}

fail() {
    echo "[Telemt] 错误：$*" >&2
    exit 1
}

check_bool() {
    name="$1"
    eval value="\${$name:-}"

    case "$value" in
        true|false|"") ;;
        *) fail "$name 只能是 true 或 false" ;;
    esac
}

check_hex32_value() {
    name="$1"
    value="$2"

    case "$value" in
        ""|*[!0-9a-fA-F]*)
            fail "$name 必须是 32 位十六进制字符串"
            ;;
    esac

    [ "${#value}" -eq 32 ] || fail "$name 长度必须是 32 位"
}

log "开始初始化 Telemt"

mkdir -p "$RUNTIME_DIR"
cd "$RUNTIME_DIR"

TELEMT_USER="${TELEMT_USER:-admin}"
TELEMT_TLS_DOMAIN="${TELEMT_TLS_DOMAIN:-www.bing.com}"
TELEMT_ENABLE_API="${TELEMT_ENABLE_API:-true}"
TELEMT_ENABLE_AD_TAG="${TELEMT_ENABLE_AD_TAG:-false}"

check_bool TELEMT_ENABLE_API
check_bool TELEMT_ENABLE_AD_TAG

if [ -z "${TELEMT_PUBLIC_HOST:-}" ]; then
    log "未配置 TELEMT_PUBLIC_HOST，正在自动获取公网 IPv4..."

    TELEMT_PUBLIC_HOST="$(
        curl -4fsSL https://www.cloudflare.com/cdn-cgi/trace \
        | grep '^ip=' \
        | cut -d= -f2 \
        | tr -d '\r\n'
    )"

    [ -n "$TELEMT_PUBLIC_HOST" ] || fail "自动获取公网 IPv4 失败，请手动配置 TELEMT_PUBLIC_HOST"

    log "自动获取公网 IPv4 成功：$TELEMT_PUBLIC_HOST"
else
    log "使用自定义公网地址：$TELEMT_PUBLIC_HOST"
fi

if [ -z "${TELEMT_SECRET:-}" ]; then
    log "未配置 TELEMT_SECRET，正在自动生成 32 位 Secret..."

    TELEMT_SECRET="$(
        od -An -N16 -tx1 /dev/urandom \
        | tr -d ' \n'
    )"

    log "Secret 自动生成完成"
else
    log "使用自定义 Secret"
fi

check_hex32_value "TELEMT_SECRET" "$TELEMT_SECRET"

case "$TELEMT_USER" in
    ""|*[!A-Za-z0-9_.-]*)
        fail "TELEMT_USER 只能包含字母、数字、下划线、点和横线"
        ;;
esac

if [ "$TELEMT_ENABLE_AD_TAG" = "true" ]; then
    [ -n "${TELEMT_AD_TAG:-}" ] || fail "已启用 TG 频道推广，但 TELEMT_AD_TAG 未设置"

    check_hex32_value "TELEMT_AD_TAG" "$TELEMT_AD_TAG"

    AD_TAG_BLOCK="ad_tag = \"$TELEMT_AD_TAG\""
    log "TG 频道推广：已启用"
else
    AD_TAG_BLOCK="# TG 频道推广：未启用"
    log "TG 频道推广：未启用"
fi

API_ENABLED="$TELEMT_ENABLE_API"

log "正在生成配置文件：$CONFIG_FILE"

sed \
    -e "s|__TELEMT_PUBLIC_HOST__|$TELEMT_PUBLIC_HOST|g" \
    -e "s|__TELEMT_TLS_DOMAIN__|$TELEMT_TLS_DOMAIN|g" \
    -e "s|__TELEMT_USER__|$TELEMT_USER|g" \
    -e "s|__TELEMT_SECRET__|$TELEMT_SECRET|g" \
    -e "s|__AD_TAG_BLOCK__|$AD_TAG_BLOCK|g" \
    -e "s|__API_ENABLED__|$API_ENABLED|g" \
    "$CONFIG_TEMPLATE" > "$CONFIG_FILE"

log "配置文件生成完成"

log "========== 当前配置 =========="
log "公网地址：$TELEMT_PUBLIC_HOST"
log "伪装域名：$TELEMT_TLS_DOMAIN"
log "用户名：$TELEMT_USER"
log "Secret：$TELEMT_SECRET"
log "本地 API：$API_ENABLED"

if [ "$TELEMT_ENABLE_AD_TAG" = "true" ]; then
    log "TG 推广：已启用"
else
    log "TG 推广：未启用"
fi

log "=============================="

log "正在启动 Telemt..."

"/app/telemt" "$CONFIG_FILE" &
telemt_pid="$!"

trap 'log "收到退出信号，正在停止 Telemt"; kill "$telemt_pid" 2>/dev/null || true; wait "$telemt_pid" 2>/dev/null || true' INT TERM

if [ "$API_ENABLED" = "true" ]; then
    log "正在等待本地 API 就绪..."

    i=0
    while [ "$i" -lt 30 ]; do
        if curl -fsS "$API_URL" > "$USERS_JSON" 2>/dev/null; then
            log "本地 API 已就绪"
            log "========== TG 一键导入链接 =========="

            if jq -e '.data' "$USERS_JSON" >/dev/null 2>&1; then
                jq -r '
                  .data[]? |
                  "用户：" + (.username // "unknown"),
                  (
                    if (.links.tls // empty) then
                      .links.tls[]?
                    else
                      empty
                    end
                  ),
                  ""
                ' "$USERS_JSON"
            else
                cat "$USERS_JSON"
            fi

            log "===================================="
            break
        fi

        i=$((i + 1))
        sleep 1
    done

    if [ "$i" -ge 30 ]; then
        log "API 暂未就绪，可稍后手动执行：curl -s $API_URL"
    fi
else
    log "本地 API 已关闭，无法自动输出 TG 一键链接"
fi

wait "$telemt_pid"
