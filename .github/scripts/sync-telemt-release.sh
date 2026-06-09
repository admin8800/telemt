#!/usr/bin/env bash
set -euo pipefail

SOURCE_REPO="${SOURCE_REPO:-telemt/telemt}"
FORCE="${FORCE:-true}"
ASSET_DIR="$(mktemp -d)"
NOTES_FILE="$(mktemp)"

cleanup() {
  rm -rf "$ASSET_DIR"
  rm -f "$NOTES_FILE"
}
trap cleanup EXIT

log_info()  { echo "[信息] $*"; }
log_warn()  { echo "[警告] $*"; }
log_error() { echo "[错误] $*" >&2; }

echo "=========================================="
echo "  开始同步 telemt 最新 Release"
echo "  源仓库: ${SOURCE_REPO}"
echo "  目标仓库: ${GITHUB_REPOSITORY}"
echo "  强制覆盖: ${FORCE}"
echo "=========================================="

log_info "正在从 GitHub API 获取最新 Release..."
RELEASE_JSON="$(gh api "repos/${SOURCE_REPO}/releases/latest")"

TAG_NAME="$(printf '%s' "$RELEASE_JSON" | jq -r '.tag_name')"
RELEASE_NAME="$(printf '%s' "$RELEASE_JSON" | jq -r '.name')"
RELEASE_BODY="$(printf '%s' "$RELEASE_JSON" | jq -r '.body // ""')"
IS_PRERELEASE="$(printf '%s' "$RELEASE_JSON" | jq -r '.prerelease')"
ASSET_COUNT="$(printf '%s' "$RELEASE_JSON" | jq '.assets | length')"

if [ -z "$TAG_NAME" ] || [ "$TAG_NAME" = "null" ]; then
  log_error "未能获取有效的版本标签，请检查源仓库是否存在 Latest Release。"
  exit 1
fi

log_info "最新版本标签: ${TAG_NAME}"
log_info "发布名称: ${RELEASE_NAME}"
log_info "是否预发布: ${IS_PRERELEASE}"
log_info "附件数量: ${ASSET_COUNT}"

if gh release view "$TAG_NAME" >/dev/null 2>&1; then
  if [ "$FORCE" = "true" ]; then
    log_warn "Release ${TAG_NAME} 已存在，强制模式：删除旧 Release 及标签..."
    gh release delete "$TAG_NAME" --yes --cleanup-tag
  else
    log_error "Release ${TAG_NAME} 已存在。"
    log_error "如需覆盖，请重新运行工作流并勾选「强制重新发布」。"
    exit 1
  fi
fi

if [ "$ASSET_COUNT" -gt 0 ]; then
  log_info "开始下载全部附件..."
  printf '%s' "$RELEASE_JSON" | jq -c '.assets[]' | while read -r asset; do
    name="$(printf '%s' "$asset" | jq -r '.name')"
    url="$(printf '%s' "$asset" | jq -r '.browser_download_url')"
    size="$(printf '%s' "$asset" | jq -r '.size')"
    log_info "下载附件: ${name} (${size} bytes)"
    curl -fsSL -o "${ASSET_DIR}/${name}" "$url"
  done
  log_info "全部附件下载完成。"
else
  log_warn "源 Release 没有附件，将仅同步 Release 说明。"
fi

SYNC_TIME="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
cat > "$NOTES_FILE" <<EOF
> 本 Release 由 CI 自动同步自 [${SOURCE_REPO}](https://github.com/${SOURCE_REPO}/releases/tag/${TAG_NAME})，同步时间：${SYNC_TIME}

${RELEASE_BODY}
EOF

log_info "正在创建 Release: ${TAG_NAME}..."

CREATE_ARGS=(
  "$TAG_NAME"
  --title "$RELEASE_NAME"
  --notes-file "$NOTES_FILE"
)

if [ "$IS_PRERELEASE" = "true" ]; then
  CREATE_ARGS+=(--prerelease)
fi

gh release create "${CREATE_ARGS[@]}"

UPLOADED=0
if [ "$ASSET_COUNT" -gt 0 ]; then
  log_info "正在上传附件到当前仓库..."
  for file in "$ASSET_DIR"/*; do
    [ -f "$file" ] || continue
    log_info "上传: $(basename "$file")"
    gh release upload "$TAG_NAME" "$file" --clobber
    UPLOADED=$((UPLOADED + 1))
  done
fi

echo "=========================================="
echo "  同步完成！"
echo "  版本标签: ${TAG_NAME}"
echo "  发布名称: ${RELEASE_NAME}"
echo "  上传附件: ${UPLOADED} / ${ASSET_COUNT}"
echo "  查看地址: https://github.com/${GITHUB_REPOSITORY}/releases/tag/${TAG_NAME}"
echo "=========================================="
