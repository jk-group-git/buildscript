#!/bin/bash

MYDIR=$(dirname $(realpath ${0}))
REPO=$MYDIR/repo
REPO_VERSION_GIT="e469a0c741832f6584513f4a382d6b93f417b8d2"
REPOPATH_DEFAULT=~/bin
YOCTODIR=`realpath ${0%/*}`/yocto-linux-jk-public
MANIFESTHOST=github.com
MANIFESTUSER=git
MANIFESTREPO=jk-group-git/public-manifest.git
MANIFESTURI=$MANIFESTUSER@$MANIFESTHOST:$MANIFESTREPO
MANIFEST=manifest.xml
MYDISTRO=jk-public
MYBUILDDIR=build
MYMACHINE=pl-161
VERSION=main

usage="$(basename "$0") [-m manifestrev] -M machine [-r] [-C] [-o] -- build an image, toolchain, kernel, devicetree, u-boot into a .zip\n
\n
where:\n
    -M  the machine to build for (pl-161(default) or pl-900))\n
\n
Note that this script does not do any seatbelts, handholding or error handling. If a build fails you will be left alone at the error messages.
"

while getopts "m:M:rosC" opt; do
        case $opt in
                m)
                        MANIFESTREV=$OPTARG
                        ;;
		M)
			MYMACHINE=$OPTARG
			;;
                :)
                        echo -e $usage
                        exit 1
                        ;;
                \?)
                        echo -e $usage
                        exit 1
                        ;;
                *)
                        echo -e $usage
                        exit 1
                        ;;
        esac
done

IMAGE=$MYMACHINE-image

if [ -e $YOCTODIR ]; then
	if [ ! -d $YOCTODIR ]; then
		echo "Working dir \"$YOCTODIR\" exists, but is not a directory. Exiting."
		exit 1
	fi
else
	mkdir $YOCTODIR
fi

pushd $YOCTODIR

$REPO init -u $MANIFESTURI -b $VERSION -m $MANIFEST
if [ $? -ne 0 ]; then
		git -C .repo/repo/ checkout "${REPO_VERSION_GIT}"
		$REPO init -u $MANIFESTURI -b $VERSION -m $MANIFEST
		if [ $? -ne 0 ]; then
			git -C .repo/repo/ checkout "${REPO_VERSION_GIT}"
			echo "Error while trying to init repo. Cleaning up and exiting."
			rm -rf .repo
			exit 1
		fi
fi

$REPO sync -d
if [ $? -ne 0 ]; then
	echo "Error while syncing. Exiting."
	exit 1
fi

git -C .repo/repo/ checkout "${REPO_VERSION_GIT}"

KEY=`realpath sources/meta-jk-public/${MYMACHINE}.pem`

export MACHINE=$MYMACHINE
export DISTRO=$MYDISTRO
. setup-environment $MYBUILDDIR

export jk_version=public
export BB_ENV_EXTRAWHITE="$BB_ENV_EXTRAWHITE jk_version"

bitbake -k $IMAGE
if [ $? -ne 0 ]; then
	echo "Error while building image. Exiting."
	exit 1
fi

TCMODE=uboot bitbake -k u-boot
if [ $? -ne 0 ]; then
	echo "Error while building bootloader. Exiting."
	exit 1
fi

popd

set -e

ODIR=`realpath ${0%/*}`/output
PACKDIR=`mktemp -d`
UPDATEDIR=$PACKDIR
mkdir $UPDATEDIR
REVFILE=$PACKDIR/revisions

DEPLOYPATH=$YOCTODIR/$MYBUILDDIR/tmp/deploy/images/$MYMACHINE/
SPATH=$YOCTODIR/$MYBUILDDIR/tmp/deploy/sources/
SPATH_ARM=$SPATH/arm-poky-linux-gnueabi
SPATH_X86=$SPATH/x86_64-linux
SPATH_ALL=$SPATH/allarch-poky-linux

DTBMAGIC=imx6dl-tx6-emmc

tstamp=`date -u -Iseconds`
if [ $RELEASE -eq 1 ]; then
	imagezipname=$VERSION-$tstamp.zip
	sourceimagezipname=$VERSION-OSR-$tstamp.zip
	checksumname=$VERSION-checksum-$tstamp.txt
else
	imagezipname=$VERSION-$tstamp-developmental.zip
	if [ -e $ODIR/$imagezipname ]; then
		rm $ODIR/$imagezipname
	fi
	sourceimagezipname=$VERSION-OSR-$tstamp-developmental.zip
	if [ -e $ODIR/$sourceimagezipname ]; then
		rm $ODIR/$sourceimagezipname
	fi
	checksumname=$VERSION-checksum-$tstamp-developmental.txt
	if [ -e $ODIR/$sourceimagezipname ]; then
		rm $ODIR/$sourceimagezipname
	fi
fi

cp $DEPLOYPATH/$IMAGE-$MYMACHINE.manifest $PACKDIR
cp $DEPLOYPATH/$IMAGE-$MYMACHINE.tar.gz $UPDATEDIR/rootfs-pl161.tar.gz
cp $DEPLOYPATH/uImage $UPDATEDIR
cp $DEPLOYPATH/uImage-$DTBMAGIC-$MYMACHINE.dtb $UPDATEDIR/dtb
cp $DEPLOYPATH/u-boot.penv $UPDATEDIR/penv
cp $DEPLOYPATH/u-boot.bin $UPDATEDIR/
cp $DEPLOYPATH/checksum.txt $PACKDIR/$checksumname

pushd $UPDATEDIR/
sha256sum rootfs-pl161.tar.gz | tee -a VERSION_$VERSION.TXT rootfs-pl161.sha256
sha256sum u-boot.bin | tee -a VERSION_$VERSION.TXT u-boot.sha256
sha256sum penv | tee -a VERSION_$VERSION.TXT penv.sha256
sha256sum uImage | tee -a VERSION_$VERSION.TXT uImage.sha256
sha256sum dtb | tee -a VERSION_$VERSION.TXT dtb.sha256
if [ -f $KEY ]; then
	openssl dgst -sha256 -sign $KEY -out rootfs-pl161.tar.gz.sgn rootfs-pl161.tar.gz
	openssl dgst -sha256 -sign $KEY -out u-boot.bin.sgn u-boot.bin
	openssl dgst -sha256 -sign $KEY -out penv.sgn penv
	openssl dgst -sha256 -sign $KEY -out uImage.sgn uImage
	openssl dgst -sha256 -sign $KEY -out dtb.sgn dtb
fi
popd

if [ ! -d $ODIR ]; then
	if [ -e $ODIR ]; then
		echo $ODIR exists but is not a directory. Please move it out of the way, so we can store our output there.
		exit 1;
	fi
	mkdir $ODIR
fi

pushd $YOCTODIR
$REPO forall -pc "git log -n1 --oneline" >> $REVFILE
popd

pushd $PACKDIR
zip -r $ODIR/$imagezipname *
popd

rm -rf $PACKDIR
