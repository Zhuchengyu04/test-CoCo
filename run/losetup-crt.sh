#!/bin/bash
if [ ! -f $1 ]; then
    echo "$1 does not exist"
    exit 1
fi

source run/common.bash
FLAG=$2

echo "MNT_DIR=$MNT_DIR!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
#startsector=$(file $1 | awk '{match($11,/(.*),/,a);print a[1]}' )
startsector=$(fdisk -l $1 | tail -n 1 | awk '{print $2}')
#echo $?
echo $startsector
mkdir -p /mnt/$MNT_DIR || exit 1
losetup -Pf $1 || exit 1
DEV="$(losetup -l | grep "$1" | awk '{print $1}')p1"
echo $DEV
if [ "$startsector" == "" ]; then
    echo "mount $DEV"
    mount $DEV /mnt/$MNT_DIR || exit 1
else
    echo "mount $DEV with offset"
    #mount -ooffset=$((512*$startsector)) $DEV /mnt/$MNT_DIR || exit 1
    mount $DEV /mnt/$MNT_DIR || exit 1
fi

if [ $FLAG == "c" ]; then
    # mkdir ./mnt
    # cp /mnt/$MNT_DIR/etc/ssl/certs/ca-certificates.crt ./mnt/
    # cp ./certs/ca-certificates.crt.guest  /mnt/$MNT_DIR/etc/ssl/certs/ca-certificates.crt
    # rm  /mnt/$MNT_DIR/etc/ssl/certs/ca-certificates.crt
    # cat /root/kata/install_and_test_cc/test-kata/certs/domain.crt >> /mnt/kata-containers-ubuntu/etc/ssl/certs/ca-certificates.crt

    cat $TEST_COCO_PATH/../certs/domain.crt >>/mnt/$MNT_DIR/etc/ssl/certs/ca-certificates.crt
    # cp -r /usr/local/lib/rats-tls /mnt/$MNT_DIR/usr/local/lib/
    # cp -r /usr/local/include/rats-tls /mnt/$MNT_DIR/usr/local/include/
    # cp -r /usr/share/rats-tls  /mnt/$MNT_DIR/usr/share/
    # cp /mnt/$MNT_DIR/usr/local/bin/attestation-agent ./mnt/
    # rm /mnt/$MNT_DIR/usr/local/bin/attestation-agent
    # cp /usr/local/bin/attestation-agent /mnt/$MNT_DIR/usr/local/bin/attestation-agent
elif [ $FLAG == "r" ]; then
    cp ./mnt/ca-certificates.crt /mnt/$MNT_DIR/etc/ssl/certs/ca-certificates.crt
    cp ./mnt/attestation-agent /mnt/$MNT_DIR/usr/local/bin/attestation-agent
else
    pushd /mnt/$MNT_DIR
    bash
    popd
fi

umount /mnt/$MNT_DIR
echo "umount and detach.."
losetup -D
echo "rm /mnt/$MNT_DIR .."
rm -r /mnt/$MNT_DIR
