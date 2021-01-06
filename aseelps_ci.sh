#!/usr/bin/env bash
# Copyright (C) 2020 Aseel P Sathar (aseelps)

BOT=$BOT_API_KEY
KERN_IMG=$PWD/out/arch/arm64/boot/Image.gz-dtb
ZIP_DIR=$PWD/Zipper
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
THREAD=-j$(nproc --all)
DEVICE=$1
CONFIG=vince_defconfig
[ -d $PWD/toolchains/aarch64 ] || git clone https://github.com/kdrag0n/aarch64-elf-gcc.git $PWD/toolchains/aarch64
[ -d $PWD/toolchains/aarch32 ] || git clone https://github.com/kdrag0n/arm-eabi-gcc.git $PWD/toolchains/aarch32

# build the kernel
function build_kern() {
    DATE=`date`
    BUILD_START=$(date +"%s")

    # cleaup first
    make clean && make mrproper

    # building
    make O=out $CONFIG $THREAD
    # use gcc for vince 
    
    make O=out $THREAD \
                CROSS_COMPILE="$PWD/toolchains/aarch64/bin/aarch64-elf-" \
                CROSS_COMPILE_ARM32="$PWD/toolchains/aarch32/bin/arm-eabi-"
    
    BUILD_END=$(date +"%s")
    DIFF=$(($BUILD_END - $BUILD_START))

}

# make flashable zip
function make_flashable() {
    cd $ZIP_DIR
    git checkout vince
    
    make clean &>/dev/null
    cp $KERN_IMG $ZIP_DIR/zImage
    if [ $BRANCH == "darky" ]; then
        make stable &>/dev/null
    else
        make beta &>/dev/null
    fi
    echo "Flashable zip generated under $ZIP_DIR."
    ZIP=$(ls | grep *.zip)
    cd -
}

function generate_changelog() {
    # install drone CI
    wget --no-check-certificate https://github.com/drone/drone-cli/releases/download/v1.2.1/drone_linux_amd64.tar.gz
    tar -xzf drone_linux_amd64.tar.gz
    mv drone /bin

    # some magic
    current_build=$(drone build ls aseelps/kernel_xiaomi_vince| awk '/Commit/{i++}i==1{print $2; exit}')
    last_build=$(drone build ls aseelps/kernel_xiaomi_vince | awk '/Commit/{i++}i==2{print $2; exit}')
    log=$(git log --pretty=format:'- %s' $last_build".."$current_build)
    if [[ -z $log ]]; then
        log=$(git log --pretty=format:'- %s' $current_build)
    fi
    export CHANGE_URL=$(echo "$log" | curl -F 'clbin=<-' https://clbin.com)
}

# Export
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER="Aseel_P_S"
export KBUILD_BUILD_HOST="Últra-Factory"
export LINUX_VERSION=$(awk '/SUBLEVEL/ {print $3}' Makefile \
    | head -1 | sed 's/[^0-9]*//g')

# Clone AnyKernel3
[ -d $PWD/Zipper ] || git clone https://github.com/aseelps/AnyKernel3 $PWD/Zipper

# Build start
build_kern

# make zip
make_flashable
