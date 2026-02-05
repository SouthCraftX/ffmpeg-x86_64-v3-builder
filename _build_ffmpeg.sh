#!/bin/bash

# 配置路径
export WORK_DIR="$HOME/ffmpeg_sources"
export BUILD_DIR="$HOME/ffmpeg_build"   # 存放中间静态库
export FINAL_DIR="$HOME/ffmpeg_final"   # 最终产物
export PKG_CONFIG_PATH="$BUILD_DIR/lib/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig"

export CFLAGS="-march=x86-64-v3 -O3 -flto"
export LDFLAGS="-L$BUILD_DIR/lib -march=x86-64-v3 -flto"

set -euo pipefail 
mkdir -p "$WORK_DIR" "$BUILD_DIR" "$FINAL_DIR"

function log_stage() {
    local msg="$1"
    local start_time="${2:-}"
    if [ -z "$start_time" ]; then
        # 使用 >&2 将文字输出到标准错误，这样变量捕获不到它
        echo ">>> [$(date '+%H:%M:%S')] $msg" >&2
        # 唯独把时间戳留在标准输出，供 S=$(...) 捕获
        echo "$(date +%s)"
    else
        local end_time=$(date +%s)
        local diff=$((end_time - start_time))
        # 同样输出到标准错误
        echo ">>> [$(date '+%H:%M:%S')] $msg 完成，耗时: ${diff}s" >&2
    fi
}

GLOBAL_START=$(date +%s)
mkdir -p "$WORK_DIR" "$BUILD_DIR" "$FINAL_DIR"


S=$(log_stage "开始编译 x264")
cd "$WORK_DIR"
if [ ! -d "x264" ]; then
    git clone --depth 1 https://code.videolan.org/videolan/x264.git
fi
cd x264

echo "--- 配置并编译 x264 (静态 + v3) ---"
./configure \
  --prefix="$BUILD_DIR" \
  --enable-static \
  --enable-pic \
  --disable-cli \
  --enable-lto \
  --enable-strip \
  --bit-depth=8 \
  --chroma-format=420 \
  --extra-cflags="-march=x86-64-v3 -O3 -ffast-math -flto" \
  --extra-ldflags="-march=x86-64-v3 -flto" 

make -j$(nproc)
make install
log_stage "x264 编译" $S > /dev/null # 仅用于计算

S=$(log_stage "下载 FFmpeg")
cd "$WORK_DIR"
if [ ! -f "ffmpeg-8.0.1.tar.xz" ]; then
    aria2c https://ffmpeg.org/releases/ffmpeg-8.0.1.tar.xz
fi

echo "--- 正在解压 FFmpeg ---"
[ -d "ffmpeg-8.0.1" ] && rm -rf "ffmpeg-8.0.1"
tar -xJf ffmpeg-8.0.1.tar.xz --no-same-owner
cd ffmpeg-8.0.1
log_stage "FFmpeg 下载解压" $S > /dev/null

# 3. 配置并编译 FFmpeg
S=$(log_stage "配置 FFmpeg")
./configure \
  --prefix="$FINAL_DIR" \
  --pkg-config-flags="--static" \
  --extra-cflags="-I$BUILD_DIR/include $CFLAGS" \
  --extra-ldflags="$LDFLAGS" \
  --arch=x86_64 \
  --cpu=x86-64-v3 \
  --enable-static \
  --disable-shared \
  --disable-all \
  --enable-gpl \
  --enable-pthreads \
  --enable-asm \
  --enable-x86asm \
  --enable-inline-asm \
  --enable-mmx \
  --enable-sse \
  --enable-sse2 \
  --enable-sse3 \
  --enable-ssse3 \
  --enable-sse4 \
  --enable-sse42 \
  --enable-avx \
  --enable-avx2 \
  --enable-lto \
  --disable-debug \
  --disable-doc \
  --disable-network \
  --disable-autodetect \
  --enable-avcodec \
  --enable-avformat \
  --enable-swscale \
  --enable-pixelutils \
  --enable-vaapi \
  --enable-vdpau \
  --enable-ffnvcodec \
  --enable-nvenc \
  --enable-vulkan \
  --enable-libvpl \
  --enable-amf \
  --enable-opencl \
  --enable-libx264 \
  --enable-encoder=libx264,h264_nvenc,h264_vaapi,h264_qsv,h264_amf,h264_vulkan \
  --enable-decoder=h264 \
  --enable-parser=h264 \
  --enable-muxer=mp4,mov,h264 \
  --enable-demuxer=h264,mov,mp4
log_stage "FFmpeg 配置" $S > /dev/null

S=$(log_stage "编译 FFmpeg")
make -j$(nproc)
make install
log_stage "FFmpeg 编译安装" $S > /dev/null


S=$(log_stage "清理与打包")
rm -rf "$FINAL_DIR/share"
PACKAGE_NAME="ffmpeg-8.0.1-static-v3-$(date +%Y%m%d).tar.xz"

# 修复打包路径问题：进入目录后打包，不使用 "."
cd "$FINAL_DIR"
tar -cJf "$HOME/$PACKAGE_NAME" * 
log_stage "清理打包" $S > /dev/null

GLOBAL_END=$(date +%s)
echo "-------------------------------------------"
echo "全部任务完成！总耗时: $((GLOBAL_END - GLOBAL_START))s"
echo "-------------------------------------------"
