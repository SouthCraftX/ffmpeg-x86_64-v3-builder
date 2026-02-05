#!/bin/bash

# --- 配置 ---
ROOTFS="$(pwd)/rootfs"
OUTPUT_DIR="$(pwd)/output"
HISTORY_LOG="$(pwd)/build_history.log"
FULL_DETAIL_LOG="$(pwd)/build_full.log" # 详细编译过程日志
BUILD_SCRIPT="/opt/build_ffmpeg.sh"

mkdir -p "$OUTPUT_DIR"
[ -f "$FULL_DETAIL_LOG" ] && mv "$FULL_DETAIL_LOG" "${FULL_DETAIL_LOG}.old"

if [ ! -d "$ROOTFS" ]; then echo "错误: 找不到 rootfs"; exit 1; fi

START_TIME=$(date +%s)
HUMAN_START=$(date "+%Y-%m-%d %H:%M:%S")

echo ">>> 构建开始: $HUMAN_START"

# --- 执行构建并捕捉日志 ---
# 使用 stdbuf 确保流实时输出，tee 同时写入屏幕和文件
bwrap \
    --unshare-user --uid 0 --gid 0 \
    --bind "$ROOTFS" / \
    --dev-bind /dev /dev \
    --proc /proc \
    --bind /sys /sys \
    --tmpfs /tmp --tmpfs /run \
    --share-net --die-with-parent \
    --hostname cachyos-builder \
    --unshare-uts \
    --setenv TERM "$TERM" \
    --setenv USER root \
    --setenv HOME /root \
    --setenv PATH "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    --chdir /root \
    --bind /etc/resolv.conf /etc/resolv.conf \
    /usr/bin/bash --login -c "$BUILD_SCRIPT" 2>&1 | tee "$FULL_DETAIL_LOG"

EXIT_CODE=${PIPESTATUS[0]} # 获取 bwrap 的退出状态，而不是 tee 的

# --- 时间计算 ---
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# --- 结果处理 ---
if [ $EXIT_CODE -eq 0 ]; then
    STATUS="SUCCESS"
    FIND_PKG=$(ls "$ROOTFS/root"/ffmpeg-*.tar.xz 2>/dev/null | head -n 1)
    if [ -n "$FIND_PKG" ]; then
        mv "$FIND_PKG" "$OUTPUT_DIR/"
        RESULT_MSG="产物提取成功: $(basename "$FIND_PKG")"
    else
        STATUS="WARNING"
        RESULT_MSG="编译成功但未发现压缩包"
    fi
else
    STATUS="FAILED"
    RESULT_MSG="编译过程中止，请检查 build_full.log"
fi

# --- 记录历史摘要 ---
{
    echo "[$HUMAN_START] 状态: $STATUS | 耗时: ${DURATION}s"
    echo "结果: $RESULT_MSG"
    # 从详细日志中提取各个步骤的耗时 (grep 容器脚本中的输出)
    grep "完成，耗时:" "$FULL_DETAIL_LOG" | sed 's/^/  /' 
    echo "-----------------------------------------------------------"
} >> "$HISTORY_LOG"

echo ">>> 处理完成。详细日志: $FULL_DETAIL_LOG，摘要: $HISTORY_LOG"
exit $EXIT_CODE
