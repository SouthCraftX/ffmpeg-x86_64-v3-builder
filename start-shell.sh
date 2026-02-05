#!/bin/bash

ROOTFS="$(pwd)/rootfs"

if [ ! -d "$ROOTFS" ]; then
    echo "错误: 找不到 rootfs 目录"
    exit 1
fi

echo ">>> 以独立身份启动 CachyOS (Rootless Root)..."

# 关键参数解释：
# --unshare-user: 开启新的用户命名空间
# --uid 0: 将当前宿主机用户映射为容器内的 UID 0 (root)
# --gid 0: 将当前宿主机组映射为容器内的 GID 0 (root)
# --hostname: 指定独立的主机名
bwrap \
    --unshare-user \
    --uid 0 \
    --gid 0 \
    --bind "$ROOTFS" / \
    --dev-bind /dev /dev \
    --proc /proc \
    --bind /sys /sys \
    --tmpfs /tmp \
    --tmpfs /run \
    --share-net \
    --die-with-parent \
    --hostname cachyos-builder \
    --unshare-uts \
    --setenv TERM "$TERM" \
    --setenv USER root \
    --setenv HOME /root \
    --setenv PATH "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    --chdir /root \
    --bind /etc/resolv.conf /etc/resolv.conf \
    /usr/bin/bash --login
