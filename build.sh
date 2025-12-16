ANDROID_NDK="/home/leee/compilable/android-ndk-r26d"
# Linux 交叉编译 Android 库脚本
if [[ -z $ANDROID_NDK ]]; then
    echo 'Error: Can not find ANDROID_NDK path.'
    exit 1
fi

echo "ANDROID_NDK path: ${ANDROID_NDK}"

OUTPUT_DIR="ffmpeg_output"

mkdir ${OUTPUT_DIR}
cd ${OUTPUT_DIR}

OUTPUT_PATH=`pwd`

API=21
TOOLCHAIN=$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64

# 编译出的x264库地址
X264_ANDROID_DIR=/home/leee/compilable/x264_0.165/x264_output/product

EXTRA_CONFIGURATIONS="--disable-stripping \
    --disable-ffmpeg \
    --disable-doc \
    --disable-appkit \
    --disable-avfoundation \
    --disable-coreimage \
    --disable-amf \
    --disable-audiotoolbox \
    --disable-cuda-llvm \
    --disable-cuvid \
    --disable-d3d11va \
    --disable-dxva2 \
    --disable-ffnvcodec \
    --disable-nvdec \
    --disable-nvenc \
    --disable-vdpau \
    --disable-videotoolbox"

function build {
    ABI=$1

    if [[ $ABI == "armeabi-v7a" ]]; then
        ARCH="arm"
        TRIPLE="armv7a-linux-androideabi"
        CROSS_PREFIX="arm-linux-androideabi-"
    elif [[ $ABI == "arm64-v8a" ]]; then
        ARCH="arm64"
        TRIPLE="aarch64-linux-android"
        CROSS_PREFIX="aarch64-linux-android-"
    elif [[ $ABI == "x86" ]]; then
        ARCH="x86"
        TRIPLE="i686-linux-android"
        CROSS_PREFIX="i686-linux-android-"
    elif [[ $ABI == "x86-64" ]]; then
        ARCH="x86_64"
        TRIPLE="x86_64-linux-android"
        CROSS_PREFIX="x86_64-linux-android-"
    else
        echo "Unsupported ABI ${ABI}!"
        exit 1
    fi

    echo "Build ABI ${ABI}..."

    rm -rf ${ABI}
    mkdir ${ABI} && cd ${ABI}

    PREFIX=${OUTPUT_PATH}/product/$ABI

    export CC=$TOOLCHAIN/bin/${TRIPLE}${API}-clang
    
    export CXX=$TOOLCHAIN/bin/${TRIPLE}${API}-clang++
    
    # 正确设置 Vulkan 头文件路径
    VULKAN_BETA_PATH="$ANDROID_NDK/sources/third_party/vulkan/src/include"
    
    if [[ -f "$VULKAN_BETA_PATH/vulkan/vulkan.h" ]]; then
        echo "Found Vulkan headers at: $VULKAN_BETA_PATH"
        # 需要同时包含系统头文件路径和 Vulkan Beta 路径
        SYSROOT_INCLUDE="$TOOLCHAIN/sysroot/usr/include"
        export CFLAGS="-g -DANDROID -fdata-sections -ffunction-sections \
            -funwind-tables -fstack-protector-strong -no-canonical-prefixes \
            -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security -O0 -DNDEBUG \
            -fPIC --gcc-toolchain=$TOOLCHAIN --target=${TRIPLE}${API} \
            -I$VULKAN_BETA_PATH -I$SYSROOT_INCLUDE \
            -DVK_ENABLE_BETA_EXTENSIONS"
    else
        echo "Error: Vulkan Beta headers not found at $VULKAN_BETA_PATH"
	echo "Please ensure Android NDK contains Vulkan Beta extensions."
	echo "You can either:"
	echo "1. Install a newer NDK version that includes Vulkan Beta headers"
	echo "2. If you don't need Vulkan support, modify the script to remove Vulkan dependency"
	exit 1  # 直接退出，返回非0状态码表示错误
    fi
    # 设置PKG_CONFIG_PATH环境变量，让pkg-config能找到x264库
    export PKG_CONFIG_PATH="${X264_ANDROID_DIR}/${ABI}/lib/pkgconfig"
    
    ../../configure \
        --prefix=$PREFIX \
        --enable-cross-compile \
        --sysroot=$TOOLCHAIN/sysroot \
        --cc=$CC \
        --enable-static \
        --enable-shared \
        --disable-asm \
        --enable-gpl \
        --enable-libx264 \
        --extra-cflags="-I${X264_ANDROID_DIR}/${ABI}/include" \
        --extra-ldflags="-L${X264_ANDROID_DIR}/${ABI}/lib" \
        $EXTRA_CONFIGURATIONS

    make clean && make -j`nproc` && make install
}

echo "Select arch:"
select arch in "armeabi-v7a" "arm64-v8a" "x86" "x86-64"
do
    build $arch
    break
done
