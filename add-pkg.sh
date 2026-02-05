#!/bin/bash
# 用法: ./add-pkg.sh 软件包名1 软件包名2
set -euo pipefail

ARCH="x86_64_v3"
ROOTFS_DIR="$(pwd)/rootfs"
WRAPPER="fakechroot -- fakeroot"

# 1. 临时生成一个指向该 rootfs 的配置文件
cat > pacman-update.conf <<EOF
[options]
RootDir     = $ROOTFS_DIR
DBPath      = $ROOTFS_DIR/var/lib/pacman/
CacheDir    = $ROOTFS_DIR/var/cache/pacman/pkg/
LogFile     = $ROOTFS_DIR/var/log/pacman.log
Architecture = x86_64 x86_64_v3
SigLevel    = Never
# 保持极简：追加包时也剔除文档
NoExtract = usr/share/help/* usr/share/doc/* usr/share/man/* usr/share/locale/*

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

echo ">>> 正在向容器追加软件包: $*"
$WRAPPER -- pacman -Sy --config pacman-update.conf "$@"

# 清理
rm pacman-update.conf
echo ">>> 追加完成！"
