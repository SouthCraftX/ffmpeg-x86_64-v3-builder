#!/bin/bash
set -euo pipefail

# --- 配置 ---
ARCH="x86_64_v3"
ROOTFS_DIR="$(pwd)/rootfs"
LOG_FILE="$(pwd)/setup_rootfs.log"
WRAPPER="fakechroot -- fakeroot"
PACK_FLAG=false

CHECK_TOOLS=("pacman" "fakeroot" "fakechroot" "pixz" "tar")
MISSING_TOOLS=()

for tool in "${CHECK_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        MISSING_TOOLS+=("$tool")
    fi
done

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    echo "错误: 缺少必要工具: ${MISSING_TOOLS[*]}"
    echo "请根据你的系统安装它们 (例如: sudo pacman -S pixz fakeroot fakechroot)"
    exit 1
fi

# --- 参数解析 ---
for arg in "$@"; do
    if [ "$arg" == "--pack" ]; then
        PACK_FLAG=true
    fi
done

# --- 计时与日志函数 ---
# 初始化日志文件
echo "=== Setup Rootfs Log: $(date) ===" > "$LOG_FILE"


function log_stage() {
    local msg="$1"
    local start_time="${2:-}"
    if [ -z "$start_time" ]; then
        echo "-------------------------------------------" | tee -a "$LOG_FILE" >&2
        echo ">>> [$(date '+%H:%M:%S')] $msg" | tee -a "$LOG_FILE" >&2
        echo "$(date +%s)"
    else
        local end_time=$(date +%s)
        local diff=$((end_time - start_time))
        echo ">>> [$(date '+%H:%M:%S')] $msg 完成，耗时: ${diff}s" | tee -a "$LOG_FILE" >&2
    fi
}

# --- 开始执行 ---
TOTAL_START=$(date +%s)

# 1. 环境预建
S=$(log_stage "1. 环境预建与清理")
[ -d "$ROOTFS_DIR" ] && { 
    echo "清理旧目录..." >> "$LOG_FILE"
    chmod -R u+w "$ROOTFS_DIR" 2>/dev/null || true
    rm -rf "$ROOTFS_DIR"
}
mkdir -p "$ROOTFS_DIR/var/lib/pacman" "$ROOTFS_DIR/etc" "$ROOTFS_DIR/tmp"
touch "$ROOTFS_DIR/etc/ld.so.cache"
echo "NAME=CachyOS_Compile_Env" > "$ROOTFS_DIR/etc/os-release"
log_stage "环境预建" $S > /dev/null

# 2. 构建配置
S=$(log_stage "2. 生成 Pacman 配置文件")
cat > pacman-build.conf <<EOF
[options]
RootDir     = $ROOTFS_DIR
DBPath      = $ROOTFS_DIR/var/lib/pacman/
CacheDir    = $ROOTFS_DIR/var/cache/pacman/pkg/
LogFile     = $ROOTFS_DIR/var/log/pacman.log
Architecture = x86_64 x86_64_v3
SigLevel    = Never

NoExtract = usr/share/help/* usr/share/doc/* usr/share/man/*
NoExtract = usr/share/locale/* usr/share/info/*
NoExtract = usr/share/i18n/locales/* !usr/share/i18n/locales/en_US
NoExtract = usr/share/i18n/charmaps/* !usr/share/i18n/charmaps/UTF-8.gz

[cachyos-v3]
Server = https://mirrors.ustc.edu.cn/cachyos/repo/x86_64_v3/cachyos-v3
[cachyos-core-v3]
Server = https://mirrors.ustc.edu.cn/cachyos/repo/x86_64_v3/cachyos-core-v3
[cachyos-extra-v3]
Server = https://mirrors.ustc.edu.cn/cachyos/repo/x86_64_v3/cachyos-extra-v3
[cachyos]
Server = https://mirrors.ustc.edu.cn/cachyos/repo/x86_64/cachyos
[core]
Server = https://mirrors.ustc.edu.cn/archlinux/core/os/x86_64
[extra]
Server = https://mirrors.ustc.edu.cn/archlinux/extra/os/x86_64
EOF
log_stage "配置文件生成" $S > /dev/null

# 3. 安装包
S=$(log_stage "3. 正在同步并安装 V3 编译环境 (输出已重定向至日志)")
# 将 pacman 的详细输出全部重定向至 LOG_FILE
$WRAPPER -- pacman -Sy --config pacman-build.conf --noconfirm --needed \
    filesystem bash coreutils binutils glibc grep sed \
    file tar xz base-devel git pkgconf yasm nasm libva \
    libdrm libvdpau vulkan-headers shaderc \
    opencl-headers opencl-icd-loader onevpl amf-headers \
    ffnvcodec-headers opencl-headers aria2 >> "$LOG_FILE" 2>&1
log_stage "编译环境安装" $S > /dev/null

# 4. 初始化身份与扫尾
S=$(log_stage "4. 初始化系统设置与清理")
# 清理缓存
rm -rf "$ROOTFS_DIR/var/cache/pacman"
rm pacman-build.conf

# 身份设置
cat > "$ROOTFS_DIR/etc/passwd" <<EOF
root:x:0:0:root:/root:/bin/bash
EOF
cat > "$ROOTFS_DIR/etc/group" <<EOF
root:x:0:
EOF
mkdir -p "$ROOTFS_DIR/root"
cat > "$ROOTFS_DIR/root/.bashrc" <<EOF
export PS1='\[\e[35m\][cachy-box \W]# \[\e[m\] '
alias ls='ls --color=auto'
EOF

# 网络设置
cat > "$ROOTFS_DIR/etc/resolv.conf" << EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

# 拷贝构建脚本
if [ -f "_build_ffmpeg.sh" ]; then
    cp _build_ffmpeg.sh "$ROOTFS_DIR/opt/build_ffmpeg.sh"
    chmod +x "$ROOTFS_DIR/opt/build_ffmpeg.sh"
fi
log_stage "扫尾工作" $S > /dev/null

# 5. 可选打包
if [ "$PACK_FLAG" = true ]; then
    S=$(log_stage "5. 正在执行最大压缩打包 (xz -9e)")
    PACKAGE_NAME="cachyos-v3-rootfs-$(date +%Y%m%d).tar.xz"
    # 使用 XZ_OPT 传递极致压缩参数，-T0 使用所有 CPU 核心
    export XZ_OPT="-9e -T0"
    (cd "$ROOTFS_DIR" && tar -cf - * | pixz -9 > "../$PACKAGE_NAME") 
    log_stage "打包完成: $PACKAGE_NAME" $S
fi

TOTAL_END=$(date +%s)
echo "-------------------------------------------" | tee -a "$LOG_FILE"
echo ">>> 全部构建任务结束！总耗时: $((TOTAL_END - TOTAL_START))s" | tee -a "$LOG_FILE"
echo ">>> 完整日志已保存至: $LOG_FILE" | tee -a "$LOG_FILE"
