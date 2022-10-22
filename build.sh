#!/bin/bash

Trigger_build=2

CHATID=482554110

BASE_DIR="/tmp/kernel"
KERNEL_DIR="$BASE_DIR/android_kernel_samsung_sm8250"
TOOLCHAIN_DIR="$BASE_DIR/proton-clang"
REPACK_DIR="$BASE_DIR/AnyKernel3"
ZIP_DIR="$BASE_DIR/zip"
KBUILD_OUTPUT="$KERNEL_DIR/out"

IMAGE="$KBUILD_OUTPUT/arch/arm64/boot/Image.gz-dtb"

DEFCONFIG="soviet-star_defconfig"

BASE_AK_VER="SOVIET-STAR"
DATE=`date +"%Y%m%d-%H%M"`
AK_VER="$BASE_AK_VER"
ZIP_NAME="$AK_VER"-"$DATE"

exports() {
	export ARCH=arm64
	export SUBARCH=arm64
	export KBUILD_BUILD_USER=LaKardo
	export KBUILD_BUILD_HOST=KREMLIN

	export CLANG_DIR=$TOOLCHAIN_DIR/bin/
	export CROSS_COMPILE=aarch64-linux-gnu-
	export CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
	export KBUILD_COMPILER_STRING=$($TOOLCHAIN_DIR/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
}

git_clone(){
	mkdir -p $BASE_DIR && cd $BASE_DIR
	echo
	tg_post_msg "<b>Cloning android kernel sources</b>"
	git clone --recursive --shallow-submodules --depth 1 https://github.com/LaKardo/android_kernel_samsung_sm8250 -b stable $KERNEL_DIR
	echo
	tg_post_msg "<b>Cloning AnyKernel3</b>"
	git clone --recursive --shallow-submodules --depth 1 https://github.com/LaKardo/AnyKernel3 -b r8q $REPACK_DIR
	echo
	tg_post_msg "<b>Cloning toolchain</b>"
	git clone --recursive --shallow-submodules --depth 1 https://github.com/kdrag0n/proton-clang $TOOLCHAIN_DIR
	echo
	tg_post_msg "<b>Cloning finished succsesfully</b>"
	echo
}

tg_post_msg() {
	curl -s -X POST "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage" \
	-d chat_id=$CHATID \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"
}

tg_post_build() {
	curl --progress-bar -F document=@"$1" "https://api.telegram.org/bot$TG_BOT_TOKEN/sendDocument" \
	-F chat_id=$CHATID  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=html" \
	-F caption="$3"
}

make_kernel() {
	git_clone
	exports
	tg_post_msg "<b>NEW CI Build Triggered</b>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>"
	echo
	BUILD_START=$(date +"%s")
	cd $KERNEL_DIR
	make O=$KBUILD_OUTPUT LLVM=1 LLVM_IAS=1 $DEFCONFIG
	make O=$KBUILD_OUTPUT LLVM=1 LLVM_IAS=1 -j8 2>&1 | tee error.log
	tg_post_build $KBUILD_OUTPUT/.config
	BUILD_END=$(date +"%s")
	DIFF=$((BUILD_END - BUILD_START))
	check_img
}

check_img() {
	if [ -f $IMAGE ]
	then
		make_zip
	else
		tg_post_build "error.log"
	fi
}

make_zip() {
	mkdir -p $ZIP_DIR
	cp $IMAGE $REPACK_DIR
	cd $REPACK_DIR
	zip -r9 `echo $ZIP_NAME`.zip *
	mv  `echo $ZIP_NAME`*.zip $ZIP_DIR
	echo
	tg_post_build $ZIP_DIR/$ZIP_NAME.zip
	echo
	tg_post_msg "<b>Build took : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)</b>"
	echo
}

make_kernel
