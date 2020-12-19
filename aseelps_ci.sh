

#!/usr/bin/env bash
# Copyright (C) 2020 Aseel P Sathar (aseelps)

BOT=$BOT_API_KEY
KERN_IMG=$PWD/out/arch/arm64/boot/Image.gz-dtb
ZIP_DIR=$PWD/Zipper
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
THREAD=-j$(nproc --all)
DEVICE=$1
[ -z "$DEVICE" ] && DEVICE="vince" # if no device specified use vince

if [[ "$DEVICE" == "vince" ]]; then
    CONFIG=vince_defconfig
    [ -d $PWD/toolchains/aarch64 ] || git clone https://github.com/kdrag0n/aarch64-elf-gcc.git $PWD/toolchains/aarch64
    [ -d $PWD/toolchains/aarch32 ] || git clone https://github.com/kdrag0n/arm-eabi-gcc.git $PWD/toolchains/aarch32
elif [[ "$DEVICE" == "phoenix" ]]; then
    CHAT_ID="-1001233365676"
    CONFIG=vendor/lineage_phoenix_defconfig
    git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 $PWD/toolchains/aarch64
    git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 $PWD/toolchains/aarch32
    wget https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/master/clang-r399163b.tar.gz
    mv *.tar.gz $PWD/toolchains
    mkdir $PWD/toolchains/clang
    tar xzf $PWD/toolchains/*.tar.gz -C $PWD/toolchains/clang
fi



# build the kernel
function build_kern() {
    DATE=`date`
    BUILD_START=$(date +"%s")

    # cleaup first
    make clean && make mrproper

    # building
    make O=out $CONFIG $THREAD
    # use gcc for vince and clang for phoenix
    if [[ "$DEVICE" == "vince" ]]; then
        make O=out $THREAD \
                    CROSS_COMPILE="$PWD/toolchains/aarch64/bin/aarch64-elf-" \
                    CROSS_COMPILE_ARM32="$PWD/toolchains/aarch32/bin/arm-eabi-"
    else
        export PATH="$PWD/toolchains/clang/bin:$PATH"
        make $THREAD O=out \
                    CC=clang \
                    CROSS_COMPILE="$PWD/toolchains/aarch64/bin/aarch64-linux-android-" \
                    CROSS_COMPILE_ARM32="$PWD/toolchains/aarch32/bin/arm-linux-androideabi-" \
                    CLANG_TRIPLE=aarch64-linux-gnu-
    fi

    BUILD_END=$(date +"%s")
    DIFF=$(($BUILD_END - $BUILD_START))

}

# make flashable zip
function make_flashable() {
    cd $ZIP_DIR
    if [[ "$DEVICE" == "vince" ]]; then
        git checkout vince
    elif [[ "$DEVICE" == "phoenix" ]]; then
        git checkout phoenix
    fi
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
    current_build=$(drone build ls aseelps/kernel_dark_ages_$DEVICE | awk '/Commit/{i++}i==1{print $2; exit}')
    last_build=$(drone build ls aseelps/kernel_dark_ages_$DEVICE | awk '/Commit/{i++}i==2{print $2; exit}')
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
[ -d $PWD/Zipper ] || git clone https://github.com/Blacksuan19/AnyKernel3 $PWD/Zipper

# Build start
build_kern

# make zip
make_flashable


