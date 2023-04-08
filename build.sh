#!/bin/bash

CHATID=482554110

BASE_DIR="/tmp/kernel"
KERNEL_DIR="$BASE_DIR/android_kernel_samsung_sm8250"
TOOLCHAIN_DIR="$BASE_DIR/neutron-clang"
REPACK_DIR="$BASE_DIR/AnyKernel3"
ZIP_DIR="$BASE_DIR/zip"
KBUILD_OUTPUT="$KERNEL_DIR/out"

IMAGE="$KBUILD_OUTPUT/arch/arm64/boot/Image.gz"
DTB="$KBUILD_OUTPUT/arch/arm64/boot/dts/vendor/qcom"

DEFCONFIG="soviet-star_defconfig"

BASE_AK_VER="SOVIET-STAR"
DATE=`date +"%Y%m%d-%H%M"`
AK_VER="$BASE_AK_VER"
ZIP_NAME="$AK_VER"-"$DATE"

function exports() {
	export ARCH=arm64
	export SUBARCH=arm64
	export KBUILD_BUILD_USER=LaKardo
	export KBUILD_BUILD_HOST=KREMLIN

	export CLANG_DIR=$TOOLCHAIN_DIR/bin/
	export PATH=${CLANG_DIR}:${PATH}
	export CROSS_COMPILE=${CLANG_DIR}/aarch64-linux-gnu-
	export CROSS_COMPILE_COMPAT=${CLANG_DIR}/arm-linux-gnueabi-
	export KBUILD_COMPILER_STRING=$($CLANG_DIR/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
}

function git_clone(){
	mkdir -p $BASE_DIR && cd $BASE_DIR
	echo
	tg_post_msg "<b>Cloning android kernel sources</b>"
	git clone --recursive --shallow-submodules --depth 1 https://github.com/LaKardo/android_kernel_samsung_sm8250 -b prime $KERNEL_DIR
	echo
	tg_post_msg "<b>Cloning AnyKernel3</b>"
	git clone --recursive --shallow-submodules --depth 1 https://github.com/LaKardo/AnyKernel3 -b r8q $REPACK_DIR
	echo
	tg_post_msg "<b>Cloning toolchain</b>"
	wget --quiet https://github.com/Neutron-Toolchains/clang-build-catalogue/releases/download/11032023/neutron-clang-11032023.tar.zst
	mkdir $TOOLCHAIN_DIR && tar -I zstd -xf "neutron-clang-11032023.tar.zst" -C $TOOLCHAIN_DIR
	echo
	tg_post_msg "<b>Cloning finished succsesfully</b>"
	echo
}

function tg_post_msg() {
	curl -s -X POST "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage" \
	-d chat_id=$CHATID \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"
}

function tg_post_build() {
	curl --progress-bar -F document=@"$1" "https://api.telegram.org/bot$TG_BOT_TOKEN/sendDocument" \
	-F chat_id=$CHATID  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=html" \
	-F caption="$3"
}

function make_kernel() {
	git_clone
	exports
	tg_post_msg "<b>NEW CI Build Triggered</b>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>"
	echo
	BUILD_START=$(date +"%s")
	cd $KERNEL_DIR
	make O=$KBUILD_OUTPUT LLVM=1 CC="ccache clang" $DEFCONFIG
	make O=$KBUILD_OUTPUT LLVM=1 CC="ccache clang" -j8 2>&1 | tee error.log
	make O=$KBUILD_OUTPUT LLVM=1 CC="ccache clang" -j8 dtbs
	tg_post_build $KBUILD_OUTPUT/.config
	BUILD_END=$(date +"%s")
	DIFF=$((BUILD_END - BUILD_START))
	make_zip
}

function make_zip() {
	if [ -f $IMAGE ]
	then
		mkdir -p $ZIP_DIR
		cp $IMAGE $REPACK_DIR/Image.gz
		cat $DTB/*.dtb > $REPACK_DIR/kona.dtb
		cd $REPACK_DIR
		zip -r9 `echo $ZIP_NAME`.zip *
		mv `echo $ZIP_NAME`*.zip $ZIP_DIR
		tg_post_build $ZIP_DIR/$ZIP_NAME.zip
		tg_post_msg "<b>Build took : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)</b>"
	else
		tg_post_build "error.log"
	fi
}

make_kernel
