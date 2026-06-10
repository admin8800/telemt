#!/bin/sh
set -eu

REPO="${REPO:-admin8800/telemt}"
BIN_NAME="${BIN_NAME:-telemt}"
INSTALL_DIR="${INSTALL_DIR:-/bin}"
CONFIG_DIR="${CONFIG_DIR:-/etc/telemt}"
CONFIG_FILE="${CONFIG_FILE:-${CONFIG_DIR}/telemt.toml}"
WORK_DIR="${WORK_DIR:-/opt/telemt}"
TLS_DOMAIN="${TLS_DOMAIN:-www.bing.com}"
SERVER_PORT="${SERVER_PORT:-8443}"
USER_SECRET=""
AD_TAG=""
SERVICE_NAME="telemt"
TEMP_DIR=""
SUDO=""
CONFIG_PARENT_DIR=""
SERVICE_START_FAILED=0

PORT_PROVIDED=0
SECRET_PROVIDED=0
AD_TAG_PROVIDED=0
DOMAIN_PROVIDED=0

ACTION="install"
TARGET_VERSION="${VERSION:-latest}"

PATH="${PATH}:/usr/sbin:/sbin"

L_ERR_DOMAIN_REQ="需要域名参数。"
L_ERR_PORT_REQ="需要端口参数。"
L_ERR_PORT_NUM="端口必须是有效数字。"
L_ERR_PORT_RANGE="端口必须在 1 到 65535 之间。"
L_ERR_SECRET_REQ="需要 secret 参数。"
L_ERR_SECRET_HEX="Secret 只能包含十六进制字符。"
L_ERR_SECRET_LEN="Secret 必须恰好为 32 个字符。"
L_ERR_ADTAG_REQ="需要 ad_tag 参数。"
L_ERR_UNKNOWN_OPT="未知选项："
L_WARN_EXTRA_ARG="忽略多余参数："
L_ERR_EMPTY_VAR="不能为空。"
L_ERR_INV_VER="版本号包含非法字符。"
L_ERR_INV_BIN="BIN_NAME 包含非法字符。"
L_ERR_ROOT="此脚本需要 root 或 sudo 权限。"
L_ERR_SUDO_TTY="sudo 需要密码，但未检测到终端 (TTY)。"
L_ERR_DIR_CHECK="安全检查失败：配置文件路径是一个目录。"
L_ERR_CMD_NOT_FOUND="未找到必要的命令："
L_ERR_NO_DL_TOOL="未安装 curl 或 wget。"
L_ERR_NO_CP_TOOL="需要 cp 或 install 命令。"
L_WARN_NO_NET_TOOL="未找到网络工具，跳过端口检查。"
L_INFO_PORT_IGNORE="端口已被 telemt 占用，将重启服务，忽略此情况。"
L_ERR_PORT_IN_USE="端口已被其他进程占用："
L_ERR_PORT_FREE="请释放该端口或更换端口后重试。"
L_ERR_UNSUP_ARCH="不支持的架构："
L_ERR_CREATE_GRP="无法创建用户组"
L_ERR_CREATE_USR="无法创建用户"
L_ERR_MKDIR="无法创建目录"
L_ERR_INSTALL_DIR="不是一个目录。"
L_ERR_BIN_INSTALL="无法安装二进制文件"
L_ERR_BIN_COPY="无法复制二进制文件"
L_ERR_BIN_EXEC="二进制文件不可执行。"
L_ERR_GEN_SEC="无法生成 secret。"
L_INFO_CONF_EXISTS="配置文件已存在，正在更新参数..."
L_INFO_UPD_PORT="已更新端口："
L_INFO_UPD_SEC="已更新用户 'hello' 的 secret"
L_INFO_UPD_DOM="已更新 tls_domain："
L_INFO_UPD_TAG="已更新 ad_tag"
L_ERR_CONF_INST="无法安装配置文件"
L_INFO_CONF_OK="配置文件创建成功。"
L_INFO_CONF_SEC="已为用户 'hello' 配置 secret："
L_WARN_SVC_FAIL="无法启动服务"
L_INFO_MANUAL_START="未找到服务管理器，请手动启动："
L_INFO_UNINST_START="开始卸载"
L_U_STAGE_1=">>> 阶段 1：停止服务"
L_U_STAGE_2=">>> 阶段 2：移除服务配置"
L_U_STAGE_3=">>> 阶段 3：终止用户进程"
L_U_STAGE_4=">>> 阶段 4：移除二进制文件"
L_U_STAGE_5=">>> 阶段 5：彻底清除（配置、数据、用户）"
L_INFO_KEEP_CONF="注意：配置已保留，使用 'purge' 可完全清除。"
L_INFO_I_START="开始安装"
L_I_STAGE_1=">>> 阶段 1：检查环境和依赖"
L_I_STAGE_2=">>> 阶段 2：交互式配置"
L_I_PROMPT_DOM="\n请输入 TLS 域名\n按 Enter 保留默认值 [%s]: "
L_I_PROMPT_PORT="\n请输入服务器端口\n按 Enter 保留默认值 [%s]: "
L_WARN_NO_TTY="交互模式不可用（无 TTY），使用默认值："
L_I_STAGE_3=">>> 阶段 3：下载安装包"
L_ERR_TMP_DIR="临时目录创建失败"
L_ERR_TMP_INV="临时目录无效或未创建"
L_INFO_FALLBACK="未找到 x86_64-v3 版本，回退到标准 x86_64..."
L_ERR_DL_FAIL="下载失败"
L_I_STAGE_4=">>> 阶段 4：解压安装包"
L_ERR_EXTRACT="解压失败。"
L_ERR_BIN_NOT_FOUND="安装包中未找到二进制文件"
L_I_STAGE_5=">>> 阶段 5：配置环境（用户、用户组、目录）"
L_I_STAGE_6=">>> 阶段 6：安装二进制文件"
L_I_STAGE_7=">>> 阶段 7：生成/更新配置文件"
L_I_STAGE_8=">>> 阶段 8：安装并启动服务"
L_OUT_WARN_H="安装完成（有警告）"
L_OUT_WARN_D="服务已安装但未能启动。\n请查看日志排查问题。\n"
L_OUT_SUCC_H="安装成功"
L_OUT_UNINST_H="卸载完成"
L_OUT_LINK="您的 Telegram 代理连接链接：\n"
L_ERR_INCORR_ROOT_LOGIN="请使用 'su -' 或 'sudo -i' 以 root 身份登录"
L_OUT_LOGS="查看日志（如遇问题）请使用以下命令："

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) ACTION="help"; shift ;;
        -d|--domain)
            if [ "$#" -lt 2 ] || [ -z "$2" ]; then
                printf '[错误] %s %s\n' "$1" "$L_ERR_DOMAIN_REQ" >&2; exit 1
            fi
            TLS_DOMAIN="$2"; DOMAIN_PROVIDED=1; shift 2 ;;
        -p|--port)
            if [ "$#" -lt 2 ] || [ -z "$2" ]; then
                printf '[错误] %s %s\n' "$1" "$L_ERR_PORT_REQ" >&2; exit 1
            fi
            case "$2" in
                *[!0-9]*) printf '[错误] %s\n' "$L_ERR_PORT_NUM" >&2; exit 1 ;;
            esac
            port_num="$(printf '%s\n' "$2" | sed 's/^0*//')"
            [ -z "$port_num" ] && port_num="0"
            if [ "${#port_num}" -gt 5 ] || [ "$port_num" -lt 1 ] || [ "$port_num" -gt 65535 ]; then
                printf '[错误] %s\n' "$L_ERR_PORT_RANGE" >&2; exit 1
            fi
            SERVER_PORT="$port_num"; PORT_PROVIDED=1; shift 2 ;;
        -s|--secret)
            if [ "$#" -lt 2 ] || [ -z "$2" ]; then
                printf '[错误] %s %s\n' "$1" "$L_ERR_SECRET_REQ" >&2; exit 1
            fi
            case "$2" in
                *[!0-9a-fA-F]*) printf '[错误] %s\n' "$L_ERR_SECRET_HEX" >&2; exit 1 ;;
            esac
            if [ "${#2}" -ne 32 ]; then
                printf '[错误] %s\n' "$L_ERR_SECRET_LEN" >&2; exit 1
            fi
            USER_SECRET="$2"; SECRET_PROVIDED=1; shift 2 ;;
        -a|--ad-tag|--ad_tag)
            if [ "$#" -lt 2 ] || [ -z "$2" ]; then
                printf '[错误] %s %s\n' "$1" "$L_ERR_ADTAG_REQ" >&2; exit 1
            fi
            AD_TAG="$2"; AD_TAG_PROVIDED=1; shift 2 ;;
        uninstall|--uninstall)
            if [ "$ACTION" != "purge" ]; then ACTION="uninstall"; fi
            shift ;;
        purge|--purge) ACTION="purge"; shift ;;
        install|--install) ACTION="install"; shift ;;
        -*) printf '[错误] %s %s\n' "$L_ERR_UNKNOWN_OPT" "$1" >&2; exit 1 ;;
        *)
            if [ "$ACTION" = "install" ]; then TARGET_VERSION="$1"
            else printf '[警告] %s %s\n' "$L_WARN_EXTRA_ARG" "$1" >&2; fi
            shift ;;
    esac
done

say() {
    if [ "$#" -eq 0 ] || [ -z "${1:-}" ]; then
        printf '\n'
    else
        case "$*" in
            \[*\]*) printf '%s\n' "$*" ;;
            *) printf '[信息] %s\n' "$*" ;;
        esac
    fi
}
die() { printf '[错误] %s\n' "$*" >&2; exit 1; }

write_root() { $SUDO sh -c 'cat > "$1"' _ "$1"; }

cleanup() {
    if [ -n "${TEMP_DIR:-}" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf -- "$TEMP_DIR"
    fi
}
trap cleanup EXIT INT TERM

show_help() {
    say "用法: $0 [ <版本> | install | uninstall | purge ] [ 选项 ]"
    say "  <版本>       安装指定版本（例如 3.3.15，默认: latest）"
    say "  install      安装最新版本"
    say "  uninstall    移除二进制文件和服务"
    say "  purge        完全卸载（包括配置、数据和用户）"
    say ""
    say "选项:"
    say "  -d, --domain 指定 TLS 域名（默认: www.bing.com）"
    say "  -p, --port   指定服务器端口（默认: 8443）"
    say "  -s, --secret 指定用户 secret（32 位十六进制字符）"
    say "  -a, --ad-tag 指定 ad_tag"
    exit 0
}

check_os_entity() {
    if command -v getent >/dev/null 2>&1; then getent "$1" "$2" >/dev/null 2>&1
    else grep -q "^${2}:" "/etc/$1" 2>/dev/null; fi
}

normalize_path() {
    printf '%s\n' "$1" | tr -s '/' | sed 's|/$||; s|^$|/|'
}

get_realpath() {
    path_in="$1"
    case "$path_in" in /*) ;; *) path_in="$(pwd)/$path_in" ;; esac

    if command -v realpath >/dev/null 2>&1; then
        if realpath_out="$(realpath -m "$path_in" 2>/dev/null)"; then
            printf '%s\n' "$realpath_out"
            return
        fi
    fi

    if command -v readlink >/dev/null 2>&1; then
        resolved_path="$(readlink -f "$path_in" 2>/dev/null || true)"
        if [ -n "$resolved_path" ]; then
            printf '%s\n' "$resolved_path"
            return
        fi
    fi

    d="${path_in%/*}"; b="${path_in##*/}"
    if [ -z "$d" ]; then d="/"; fi
    if [ "$d" = "$path_in" ]; then d="/"; b="$path_in"; fi

    if [ -d "$d" ]; then
        abs_d="$(cd "$d" >/dev/null 2>&1 && pwd || true)"
        if [ -n "$abs_d" ]; then
            if [ "$b" = "." ] || [ -z "$b" ]; then printf '%s\n' "$abs_d"
            elif [ "$abs_d" = "/" ]; then printf '/%s\n' "$b"
            else printf '%s/%s\n' "$abs_d" "$b"; fi
        else
            normalize_path "$path_in"
        fi
    else
        normalize_path "$path_in"
    fi
}

get_svc_mgr() {
    if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then echo "systemd"
    elif command -v rc-service >/dev/null 2>&1; then echo "openrc"
    else echo "none"; fi
}

is_config_exists() {
    if [ -n "$SUDO" ]; then
        $SUDO sh -c '[ -f "$1" ]' _ "$CONFIG_FILE"
    else
        [ -f "$CONFIG_FILE" ]
    fi
}

verify_common() {
    [ -n "$BIN_NAME" ] || die "BIN_NAME $L_ERR_EMPTY_VAR"
    [ -n "$INSTALL_DIR" ] || die "INSTALL_DIR $L_ERR_EMPTY_VAR"
    [ -n "$CONFIG_DIR" ] || die "CONFIG_DIR $L_ERR_EMPTY_VAR"
    [ -n "$CONFIG_FILE" ] || die "CONFIG_FILE $L_ERR_EMPTY_VAR"

    case "$TARGET_VERSION" in *[!a-zA-Z0-9_.-]*) die "$L_ERR_INV_VER" ;; esac
    case "$BIN_NAME" in *[!a-zA-Z0-9_-]*) die "$L_ERR_INV_BIN" ;; esac

    INSTALL_DIR="$(get_realpath "$INSTALL_DIR")"
    CONFIG_DIR="$(get_realpath "$CONFIG_DIR")"
    WORK_DIR="$(get_realpath "$WORK_DIR")"
    CONFIG_FILE="$(get_realpath "$CONFIG_FILE")"

    CONFIG_PARENT_DIR="${CONFIG_FILE%/*}"
    if [ -z "$CONFIG_PARENT_DIR" ]; then CONFIG_PARENT_DIR="/"; fi
    if [ "$CONFIG_PARENT_DIR" = "$CONFIG_FILE" ]; then CONFIG_PARENT_DIR="."; fi

    if [ "$(id -u)" -eq 0 ]; then
        SUDO=""
        if [ "${USER:-}" != "root" ] && [ "${LOGNAME:-}" != "root" ]; then
            die "$L_ERR_INCORR_ROOT_LOGIN"
        fi
    else
        command -v sudo >/dev/null 2>&1 || die "$L_ERR_ROOT"
        SUDO="sudo"
        if ! sudo -n true 2>/dev/null; then
            if ! [ -t 0 ]; then
                die "$L_ERR_SUDO_TTY"
            fi
        fi
    fi

    if [ -n "$SUDO" ]; then
        if $SUDO sh -c '[ -d "$1" ]' _ "$CONFIG_FILE"; then
            die "$L_ERR_DIR_CHECK"
        fi
    elif [ -d "$CONFIG_FILE" ]; then
        die "$L_ERR_DIR_CHECK"
    fi

    for cmd in id uname awk grep find rm chown chmod mv mktemp mkdir tr dd sed ps head sleep cat tar gzip; do
        command -v "$cmd" >/dev/null 2>&1 || die "$L_ERR_CMD_NOT_FOUND $cmd"
    done
}

verify_install_deps() {
    command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || die "$L_ERR_NO_DL_TOOL"
    command -v cp >/dev/null 2>&1 || command -v install >/dev/null 2>&1 || die "$L_ERR_NO_CP_TOOL"

    if ! command -v setcap >/dev/null 2>&1; then
        if command -v apk >/dev/null 2>&1; then
            $SUDO apk add --no-cache libcap-utils libcap >/dev/null 2>&1 || true
        elif command -v apt-get >/dev/null 2>&1; then
            $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -q libcap2-bin >/dev/null 2>&1 || {
                $SUDO env DEBIAN_FRONTEND=noninteractive apt-get update -q >/dev/null 2>&1 || true
                $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -q libcap2-bin >/dev/null 2>&1 || true
            }
        elif command -v dnf >/dev/null 2>&1; then $SUDO dnf install -y -q libcap >/dev/null 2>&1 || true
        elif command -v yum >/dev/null 2>&1; then $SUDO yum install -y -q libcap >/dev/null 2>&1 || true
        fi
    fi
}

check_port_availability() {
    port_info=""

    if command -v ss >/dev/null 2>&1; then
        port_info=$($SUDO ss -tulnp 2>/dev/null | grep -E ":${SERVER_PORT}([[:space:]]|$)" || true)
    elif command -v netstat >/dev/null 2>&1; then
        port_info=$($SUDO netstat -tulnp 2>/dev/null | grep -E ":${SERVER_PORT}([[:space:]]|$)" || true)
    elif command -v lsof >/dev/null 2>&1; then
        port_info=$($SUDO lsof -i :${SERVER_PORT} 2>/dev/null | grep LISTEN || true)
    else
        say "[警告] $L_WARN_NO_NET_TOOL"
        return 0
    fi

    if [ -n "$port_info" ]; then
        if printf '%s\n' "$port_info" | grep -q "${BIN_NAME}"; then
            say "  -> $L_INFO_PORT_IGNORE"
        else
            say "[错误] $L_ERR_PORT_IN_USE $SERVER_PORT:"
            printf '  %s\n' "$port_info"
            die "$L_ERR_PORT_FREE"
        fi
    fi
}

detect_arch() {
    sys_arch="$(uname -m)"
    case "$sys_arch" in
        x86_64|amd64)
            if [ -r /proc/cpuinfo ] && grep -q "avx2" /proc/cpuinfo 2>/dev/null && grep -q "bmi2" /proc/cpuinfo 2>/dev/null; then
                echo "x86_64-v3"
            else
                echo "x86_64"
            fi
            ;;
        aarch64|arm64) echo "aarch64" ;;
        *) die "$L_ERR_UNSUP_ARCH $sys_arch" ;;
    esac
}

detect_libc() {
    for f in /lib/ld-musl-*.so.* /lib64/ld-musl-*.so.*; do
        if [ -e "$f" ]; then echo "musl"; return 0; fi
    done
    if grep -qE '^ID="?alpine"?' /etc/os-release 2>/dev/null; then echo "musl"; return 0; fi
    if command -v ldd >/dev/null 2>&1 && (ldd --version 2>&1 || true) | grep -qi musl; then echo "musl"; return 0; fi
    echo "gnu"
}

fetch_file() {
    if command -v curl >/dev/null 2>&1; then curl -fsSL "$1" -o "$2"
    else wget -q -O "$2" "$1"; fi
}

ensure_user_group() {
    nologin_bin="$(command -v nologin 2>/dev/null || command -v false 2>/dev/null || echo /bin/false)"

    if ! check_os_entity group telemt; then
        if command -v groupadd >/dev/null 2>&1; then $SUDO groupadd -r telemt
        elif command -v addgroup >/dev/null 2>&1; then $SUDO addgroup -S telemt
        else die "$L_ERR_CREATE_GRP" ; fi
    fi

    if ! check_os_entity passwd telemt; then
        if command -v useradd >/dev/null 2>&1; then
            $SUDO useradd -r -g telemt -d "$WORK_DIR" -s "$nologin_bin" -c "Telemt Proxy" telemt
        elif command -v adduser >/dev/null 2>&1; then
            if adduser --help 2>&1 | grep -q -- '-S'; then
                $SUDO adduser -S -D -H -h "$WORK_DIR" -s "$nologin_bin" -G telemt telemt
            else
                $SUDO adduser --system --home "$WORK_DIR" --shell "$nologin_bin" --no-create-home --ingroup telemt --disabled-password telemt
            fi
        else die "$L_ERR_CREATE_USR"; fi
    fi
}

setup_dirs() {
    $SUDO mkdir -p "$WORK_DIR" "$CONFIG_DIR" "$CONFIG_PARENT_DIR" || die "$L_ERR_MKDIR"

    $SUDO chown telemt:telemt "$WORK_DIR" && $SUDO chmod 750 "$WORK_DIR"
    $SUDO chown telemt:telemt "$CONFIG_DIR" && $SUDO chmod 750 "$CONFIG_DIR"

    if [ "$CONFIG_PARENT_DIR" != "$CONFIG_DIR" ] && [ "$CONFIG_PARENT_DIR" != "." ] && [ "$CONFIG_PARENT_DIR" != "/" ]; then
        $SUDO chown root:telemt "$CONFIG_PARENT_DIR" && $SUDO chmod 750 "$CONFIG_PARENT_DIR"
    fi
}

stop_service() {
    svc="$(get_svc_mgr)"
    if [ "$svc" = "systemd" ] && $SUDO systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        $SUDO systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    elif [ "$svc" = "openrc" ] && $SUDO rc-service "$SERVICE_NAME" status >/dev/null 2>&1; then
        $SUDO rc-service "$SERVICE_NAME" stop 2>/dev/null || true
    fi
}

install_binary() {
    bin_src="$1"; bin_dst="$2"
    if [ -e "$INSTALL_DIR" ] && [ ! -d "$INSTALL_DIR" ]; then
        die "'$INSTALL_DIR' $L_ERR_INSTALL_DIR"
    fi

    $SUDO mkdir -p "$INSTALL_DIR" || die "$L_ERR_MKDIR"

    $SUDO rm -f "$bin_dst" 2>/dev/null || true

    if command -v install >/dev/null 2>&1; then
        $SUDO install -m 0755 "$bin_src" "$bin_dst" || die "$L_ERR_BIN_INSTALL"
    else
        $SUDO cp "$bin_src" "$bin_dst" && $SUDO chmod 0755 "$bin_dst" || die "$L_ERR_BIN_COPY"
    fi

    $SUDO sh -c '[ -x "$1" ]' _ "$bin_dst" || die "$L_ERR_BIN_EXEC $bin_dst"

    if command -v setcap >/dev/null 2>&1; then
        $SUDO setcap cap_net_bind_service,cap_net_admin=+ep "$bin_dst" 2>/dev/null || true
    fi
}

generate_secret() {
    secret="$(command -v openssl >/dev/null 2>&1 && openssl rand -hex 16 2>/dev/null || true)"
    if [ -z "$secret" ] || [ "${#secret}" -ne 32 ]; then
        if command -v od >/dev/null 2>&1; then secret="$(dd if=/dev/urandom bs=16 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')"
        elif command -v hexdump >/dev/null 2>&1; then secret="$(dd if=/dev/urandom bs=16 count=1 2>/dev/null | hexdump -e '1/1 "%02x"')"
        elif command -v xxd >/dev/null 2>&1; then secret="$(dd if=/dev/urandom bs=16 count=1 2>/dev/null | xxd -p | tr -d '\n')"
        fi
    fi
    if [ "${#secret}" -eq 32 ]; then echo "$secret"; else return 1; fi
}

generate_config_content() {
    conf_secret="$1"
    conf_tag="$2"
    escaped_tls_domain="$(printf '%s\n' "$TLS_DOMAIN" | tr -d '[:cntrl:]' | sed 's/\\/\\\\/g; s/"/\\"/g')"

    cat <<EOF
[general]
use_middle_proxy = true
EOF

    if [ -n "$conf_tag" ]; then
        echo "ad_tag = \"${conf_tag}\""
    fi

    cat <<EOF

[general.modes]
classic = false
secure = false
tls = true

[server]
port = ${SERVER_PORT}

[server.api]
enabled = true
listen = "127.0.0.1:9091"
whitelist = ["127.0.0.1/32"]

[censorship]
tls_domain = "${escaped_tls_domain}"

[access.users]
hello = "${conf_secret}"
EOF
}

install_config() {
    if is_config_exists; then
        say "  -> $L_INFO_CONF_EXISTS"

        tmp_conf="${TEMP_DIR}/config.tmp"
        $SUDO cat "$CONFIG_FILE" > "$tmp_conf"

        escaped_domain="$(printf '%s\n' "$TLS_DOMAIN" | tr -d '[:cntrl:]' | sed 's/\\/\\\\/g; s/"/\\"/g')"

        awk -v port="$SERVER_PORT" -v secret="$USER_SECRET" -v domain="$escaped_domain" -v ad_tag="$AD_TAG" \
            -v flag_p="$PORT_PROVIDED" -v flag_s="$SECRET_PROVIDED" -v flag_d="$DOMAIN_PROVIDED" -v flag_a="$AD_TAG_PROVIDED" '
        BEGIN { ad_tag_handled = 0 }

        flag_p == "1" && /^[ \t]*port[ \t]*=/ { print "port = " port; next }
        flag_s == "1" && /^[ \t]*hello[ \t]*=/ { print "hello = \"" secret "\""; next }
        flag_d == "1" && /^[ \t]*tls_domain[ \t]*=/ { print "tls_domain = \"" domain "\""; next }

        flag_a == "1" && /^[ \t]*ad_tag[ \t]*=/ {
            if (!ad_tag_handled) {
                print "ad_tag = \"" ad_tag "\"";
                ad_tag_handled = 1;
            }
            next
        }
        flag_a == "1" && /^\[general\]/ {
            print;
            if (!ad_tag_handled) {
                print "ad_tag = \"" ad_tag "\"";
                ad_tag_handled = 1;
            }
            next
        }

        { print }
        ' "$tmp_conf" > "${tmp_conf}.new" && mv "${tmp_conf}.new" "$tmp_conf"

        [ "$PORT_PROVIDED" -eq 1 ] && say "  -> $L_INFO_UPD_PORT $SERVER_PORT"
        [ "$SECRET_PROVIDED" -eq 1 ] && say "  -> $L_INFO_UPD_SEC"
        [ "$DOMAIN_PROVIDED" -eq 1 ] && say "  -> $L_INFO_UPD_DOM $TLS_DOMAIN"
        [ "$AD_TAG_PROVIDED" -eq 1 ] && say "  -> $L_INFO_UPD_TAG"

        write_root "$CONFIG_FILE" < "$tmp_conf"
        rm -f "$tmp_conf"
        return 0
    fi

    if [ -z "$USER_SECRET" ]; then
        USER_SECRET="$(generate_secret)" || die "$L_ERR_GEN_SEC"
    fi

    generate_config_content "$USER_SECRET" "$AD_TAG" | write_root "$CONFIG_FILE" || die "$L_ERR_CONF_INST"
    $SUDO chown root:telemt "$CONFIG_FILE" && $SUDO chmod 640 "$CONFIG_FILE"

    say "  -> $L_INFO_CONF_OK"
    say "  -> $L_INFO_CONF_SEC $USER_SECRET"
}

generate_systemd_content() {
    cat <<EOF
[Unit]
Description=Telemt
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=telemt
Group=telemt
WorkingDirectory=$WORK_DIR
ExecStart="${INSTALL_DIR}/${BIN_NAME}" "${CONFIG_FILE}"
Restart=on-failure
RestartSec=5
LimitNOFILE=65536
AmbientCapabilities=CAP_NET_BIND_SERVICE CAP_NET_ADMIN
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_ADMIN

[Install]
WantedBy=multi-user.target
EOF
}

generate_openrc_content() {
    cat <<EOF
#!/sbin/openrc-run
name="$SERVICE_NAME"
description="Telemt Proxy Service"
command="${INSTALL_DIR}/${BIN_NAME}"
command_args="${CONFIG_FILE}"
command_background=true
command_user="telemt:telemt"
pidfile="/run/\${RC_SVCNAME}.pid"
directory="${WORK_DIR}"
rc_ulimit="-n 65536"
depend() { need net; use logger; }
EOF
}

install_service() {
    svc="$(get_svc_mgr)"
    if [ "$svc" = "systemd" ]; then
        generate_systemd_content | write_root "/etc/systemd/system/${SERVICE_NAME}.service"
        $SUDO chown root:root "/etc/systemd/system/${SERVICE_NAME}.service" && $SUDO chmod 644 "/etc/systemd/system/${SERVICE_NAME}.service"

        $SUDO systemctl daemon-reload || true
        $SUDO systemctl enable "$SERVICE_NAME" || true

        if ! $SUDO systemctl start "$SERVICE_NAME"; then
            say "[警告] $L_WARN_SVC_FAIL"
            SERVICE_START_FAILED=1
        fi
    elif [ "$svc" = "openrc" ]; then
        generate_openrc_content | write_root "/etc/init.d/${SERVICE_NAME}"
        $SUDO chown root:root "/etc/init.d/${SERVICE_NAME}" && $SUDO chmod 0755 "/etc/init.d/${SERVICE_NAME}"

        $SUDO rc-update add "$SERVICE_NAME" default 2>/dev/null || true

        if ! $SUDO rc-service "$SERVICE_NAME" start 2>/dev/null; then
            say "[警告] $L_WARN_SVC_FAIL"
            SERVICE_START_FAILED=1
        fi
    else
        cmd="\"${INSTALL_DIR}/${BIN_NAME}\" \"${CONFIG_FILE}\""
        if [ -n "$SUDO" ]; then
            say "  -> $L_INFO_MANUAL_START sudo -u telemt $cmd"
        else
            say "  -> $L_INFO_MANUAL_START su -s /bin/sh telemt -c '$cmd'"
        fi
    fi
}

kill_user_procs() {
    if command -v pkill >/dev/null 2>&1; then
        $SUDO pkill -u telemt "$BIN_NAME" 2>/dev/null || true
        sleep 1
        $SUDO pkill -9 -u telemt "$BIN_NAME" 2>/dev/null || true
    else
        if command -v pgrep >/dev/null 2>&1; then
            pids="$(pgrep -u telemt 2>/dev/null || true)"
        else
            pids="$(ps -ef 2>/dev/null | awk '$1=="telemt"{print $2}' || true)"
            [ -z "$pids" ] && pids="$(ps 2>/dev/null | awk '$2=="telemt"{print $1}' || true)"
        fi

        if [ -n "$pids" ]; then
            for pid in $pids; do
                case "$pid" in ''|*[!0-9]*) continue ;; *) $SUDO kill "$pid" 2>/dev/null || true ;; esac
            done
            sleep 1
            for pid in $pids; do
                case "$pid" in ''|*[!0-9]*) continue ;; *) $SUDO kill -9 "$pid" 2>/dev/null || true ;; esac
            done
        fi
    fi
}

uninstall() {
    say "$L_INFO_UNINST_START $BIN_NAME..."

    say "$L_U_STAGE_1"
    stop_service

    say "$L_U_STAGE_2"
    svc="$(get_svc_mgr)"
    if [ "$svc" = "systemd" ]; then
        $SUDO systemctl disable "$SERVICE_NAME" 2>/dev/null || true
        $SUDO rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
        $SUDO systemctl daemon-reload 2>/dev/null || true
    elif [ "$svc" = "openrc" ]; then
        $SUDO rc-update del "$SERVICE_NAME" 2>/dev/null || true
        $SUDO rm -f "/etc/init.d/${SERVICE_NAME}"
    fi

    say "$L_U_STAGE_3"
    kill_user_procs

    say "$L_U_STAGE_4"
    $SUDO rm -f "${INSTALL_DIR}/${BIN_NAME}"

    if [ "$ACTION" = "purge" ]; then
        say "$L_U_STAGE_5"
        $SUDO rm -rf "$CONFIG_DIR" "$WORK_DIR"
        $SUDO rm -f "$CONFIG_FILE"

        if check_os_entity passwd telemt; then
            $SUDO userdel telemt 2>/dev/null || $SUDO deluser telemt 2>/dev/null || true
        fi

        if check_os_entity group telemt; then
            $SUDO groupdel telemt 2>/dev/null || $SUDO delgroup telemt 2>/dev/null || true
        fi
    else
        say "$L_INFO_KEEP_CONF"
    fi

    printf '\n====================================================================\n'
    printf '                    %s\n' "$L_OUT_UNINST_H"
    printf '====================================================================\n\n'
    exit 0
}

case "$ACTION" in
    help) show_help ;;
    uninstall|purge) verify_common; uninstall ;;
    install)
        say "$L_INFO_I_START $BIN_NAME (Version: $TARGET_VERSION)"

        say "$L_I_STAGE_1"
        verify_common
        verify_install_deps

        if is_config_exists; then
            ext_port="$($SUDO awk -F'=' '/^[ \t]*port[ \t]*=/ {gsub(/[^0-9]/, "", $2); print $2; exit}' "$CONFIG_FILE" 2>/dev/null || true)"
            if [ -n "$ext_port" ] && [ "$PORT_PROVIDED" -eq 0 ]; then
                SERVER_PORT="$ext_port"
            fi

            ext_secret="$($SUDO awk -F'"' '/^[ \t]*hello[ \t]*=/ {print $2; exit}' "$CONFIG_FILE" 2>/dev/null || true)"
            if [ -n "$ext_secret" ] && [ "$SECRET_PROVIDED" -eq 0 ]; then
                USER_SECRET="$ext_secret"
            fi

            ext_domain="$($SUDO awk -F'"' '/^[ \t]*tls_domain[ \t]*=/ {print $2; exit}' "$CONFIG_FILE" 2>/dev/null || true)"
            if [ -n "$ext_domain" ] && [ "$DOMAIN_PROVIDED" -eq 0 ]; then
                TLS_DOMAIN="$ext_domain"
            fi
        fi

        if [ "$PORT_PROVIDED" -eq 0 ] || [ "$DOMAIN_PROVIDED" -eq 0 ]; then
            say "$L_I_STAGE_2"
        fi

        if [ "$PORT_PROVIDED" -eq 0 ]; then
            if [ -t 0 ] || [ -c /dev/tty ]; then
                while true; do
                    printf "$L_I_PROMPT_PORT" "$SERVER_PORT"
                    read -r input_port </dev/tty || input_port=""
                    if [ -z "$input_port" ]; then
                        break
                    fi
                    case "$input_port" in
                        *[!0-9]*) printf '[错误] %s\n' "$L_ERR_PORT_NUM" >&2; continue ;;
                    esac
                    port_num="$(printf '%s\n' "$input_port" | sed 's/^0*//')"
                    [ -z "$port_num" ] && port_num="0"
                    if [ "${#port_num}" -gt 5 ] || [ "$port_num" -lt 1 ] || [ "$port_num" -gt 65535 ]; then
                        printf '[错误] %s\n' "$L_ERR_PORT_RANGE" >&2; continue
                    fi
                    SERVER_PORT="$port_num"
                    break
                done
            else
                say "[警告] $L_WARN_NO_TTY $SERVER_PORT"
            fi
            PORT_PROVIDED=1
        fi

        if [ "$DOMAIN_PROVIDED" -eq 0 ]; then
            if [ -t 0 ] || [ -c /dev/tty ]; then
                printf "$L_I_PROMPT_DOM" "$TLS_DOMAIN"
                read -r input_domain </dev/tty || input_domain=""
                if [ -n "$input_domain" ]; then
                    TLS_DOMAIN="$input_domain"
                fi
            else
                say "[警告] $L_WARN_NO_TTY $TLS_DOMAIN"
            fi
            DOMAIN_PROVIDED=1
        fi

        check_port_availability

        if [ "$TARGET_VERSION" != "latest" ]; then
            TARGET_VERSION="${TARGET_VERSION#v}"
        fi

        ARCH="$(detect_arch)"; LIBC="$(detect_libc)"
        FILE_NAME="${BIN_NAME}-${ARCH}-linux-${LIBC}.tar.gz"

        if [ "$TARGET_VERSION" = "latest" ]; then
            DL_URL="https://github.com/${REPO}/releases/latest/download/${FILE_NAME}"
        else
            DL_URL="https://github.com/${REPO}/releases/download/${TARGET_VERSION}/${FILE_NAME}"
        fi

        say "$L_I_STAGE_3"
        TEMP_DIR="$(mktemp -d)" || die "$L_ERR_TMP_DIR"
        if [ -z "$TEMP_DIR" ] || [ ! -d "$TEMP_DIR" ]; then
            die "$L_ERR_TMP_INV"
        fi

        if ! fetch_file "$DL_URL" "${TEMP_DIR}/${FILE_NAME}"; then
            if [ "$ARCH" = "x86_64-v3" ]; then
                say "  -> $L_INFO_FALLBACK"
                ARCH="x86_64"
                FILE_NAME="${BIN_NAME}-${ARCH}-linux-${LIBC}.tar.gz"
                if [ "$TARGET_VERSION" = "latest" ]; then
                    DL_URL="https://github.com/${REPO}/releases/latest/download/${FILE_NAME}"
                else
                    DL_URL="https://github.com/${REPO}/releases/download/${TARGET_VERSION}/${FILE_NAME}"
                fi
                fetch_file "$DL_URL" "${TEMP_DIR}/${FILE_NAME}" || die "$L_ERR_DL_FAIL"
            else
                die "$L_ERR_DL_FAIL"
            fi
        fi

        say "$L_I_STAGE_4"
        if ! gzip -dc "${TEMP_DIR}/${FILE_NAME}" | tar -xf - -C "$TEMP_DIR" 2>/dev/null; then
            die "$L_ERR_EXTRACT"
        fi

        EXTRACTED_BIN="$(find "$TEMP_DIR" -type f -name "$BIN_NAME" -print 2>/dev/null | head -n 1 || true)"
        [ -n "$EXTRACTED_BIN" ] || die "$L_ERR_BIN_NOT_FOUND"

        say "$L_I_STAGE_5"
        ensure_user_group; setup_dirs; stop_service

        say "$L_I_STAGE_6"
        install_binary "$EXTRACTED_BIN" "${INSTALL_DIR}/${BIN_NAME}"

        say "$L_I_STAGE_7"
        install_config

        say "$L_I_STAGE_8"
        install_service

        if [ "${SERVICE_START_FAILED:-0}" -eq 1 ]; then
            printf '\n====================================================================\n'
            printf '               %s\n' "$L_OUT_WARN_H"
            printf '====================================================================\n\n'
            printf '%b' "$L_OUT_WARN_D"
        else
            printf '\n====================================================================\n'
            printf '                      %s\n' "$L_OUT_SUCC_H"
            printf '====================================================================\n\n'
        fi

        SERVER_IP=""
        if command -v curl >/dev/null 2>&1; then SERVER_IP="$(curl -s4 -m 3 ifconfig.me 2>/dev/null || curl -s4 -m 3 api.ipify.org 2>/dev/null || true)"
        elif command -v wget >/dev/null 2>&1; then SERVER_IP="$(wget -qO- -T 3 ifconfig.me 2>/dev/null || wget -qO- -T 3 api.ipify.org 2>/dev/null || true)"; fi
        [ -z "$SERVER_IP" ] && SERVER_IP="<YOUR_SERVER_IP>"

        if command -v xxd >/dev/null 2>&1; then HEX_DOMAIN="$(printf '%s' "$TLS_DOMAIN" | xxd -p | tr -d '\n')"
        elif command -v hexdump >/dev/null 2>&1; then HEX_DOMAIN="$(printf '%s' "$TLS_DOMAIN" | hexdump -v -e '/1 "%02x"')"
        elif command -v od >/dev/null 2>&1; then HEX_DOMAIN="$(printf '%s' "$TLS_DOMAIN" | od -A n -t x1 | tr -d ' \n')"
        else HEX_DOMAIN=""; fi

        CLIENT_SECRET="ee${USER_SECRET}${HEX_DOMAIN}"

        printf '%b\n' "$L_OUT_LINK"
        printf '  tg://proxy?server=%s&port=%s&secret=%s\n\n' "$SERVER_IP" "$SERVER_PORT" "$CLIENT_SECRET"

        svc="$(get_svc_mgr)"
        if [ "$svc" = "systemd" ]; then
            printf '%s\n' "$L_OUT_LOGS"
            printf '  sudo journalctl -u %s -f\n\n' "$SERVICE_NAME"
        elif [ "$svc" = "openrc" ]; then
            printf '%s\n' "$L_OUT_LOGS"
            printf '  sudo tail -f /var/log/messages /var/log/syslog 2>/dev/null | grep -i %s\n\n' "$SERVICE_NAME"
        fi

        printf '====================================================================\n'
        ;;
esac
