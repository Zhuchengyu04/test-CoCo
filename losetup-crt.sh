#!/bin/bash
if [ ! -f $1 ]; then
    echo "$1 does not exist"
    exit 1
fi

MNT_DIR=$(basename -s .img $1)
FLAG=$2

echo $MNT_DIR
#startsector=$(file $1 | awk '{match($11,/(.*),/,a);print a[1]}' )
startsector=$(fdisk -l $1 | tail -n 1 | awk '{print $2}')
#echo $?
echo $startsector
mkdir -p /tmp/$MNT_DIR || exit 1
losetup -Pf $1 || exit 1
DEV="$(losetup -l | grep "$1" | awk '{print $1}')p1"
echo $DEV
if [ "$startsector" == "" ]; then
    echo "mount $DEV"
    mount $DEV /tmp/$MNT_DIR || exit 1
else
    echo "mount $DEV with offset"
    #mount -ooffset=$((512*$startsector)) $DEV /mnt/$MNT_DIR || exit 1
    mount $DEV /tmp/$MNT_DIR || exit 1
fi

if [ $FLAG == "c" ]; then
    # mkdir ./tmp
    # cp /mnt/$MNT_DIR/etc/ssl/certs/ca-certificates.crt ./tmp/
    # cp ./certs/ca-certificates.crt.guest  /mnt/$MNT_DIR/etc/ssl/certs/ca-certificates.crt
    # rm  /tmp/$MNT_DIR/etc/ssl/certs/ca-certificates.crt
    cat /root/shells/kata/certs/domain.crt >> /tmp/$MNT_DIR/etc/ssl/certs/ca-certificates.crt
    # cp /mnt/$MNT_DIR/usr/local/bin/attestation-agent ./tmp/
    # rm /tmp/$MNT_DIR/usr/local/bin/attestation-agent
    cp /usr/local/bin/attestation-agent /tmp/$MNT_DIR/usr/local/bin/attestation-agent
elif [ $FLAG == "r" ]; then
    cp ./tmp/ca-certificates.crt /tmp/$MNT_DIR/etc/ssl/certs/ca-certificates.crt
    cp ./tmp/attestation-agent /tmp/$MNT_DIR/usr/local/bin/attestation-agent
else
    pushd /tmp/$MNT_DIR
    bash
    popd
fi

umount /tmp/$MNT_DIR
echo "umount and detach.."
losetup -D
echo "rm /tmp/$MNT_DIR .."
rm -r /tmp/$MNT_DIR
