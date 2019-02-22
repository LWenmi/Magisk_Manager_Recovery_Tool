#!/sbin/sh

IMG=$1
mountPath=$2

donescript=/tmp/mmr/script/done-script.sh
skscript=/tmp/mmr/script/shrink-magiskimg.sh
doskscript=/tmp/mmr/script/do-shrink.sh

is_mounted() { mountpoint -q $1; }

mount_image() {
    e2fsck -fy $1 &>/dev/null
    if [ ! -d $2 ]; then
        mount -o remount,rw /
        mkdir -p $2
    fi
    is_mounted $2 && {
        loopedA=`mount | grep $2 | head -n1 | cut -d " " -f1`
        umount $2
        losetup -d $loopedA
    }
    loopDevice=
    for LOOP in 0 1 2 3 4 5 6 7; do
        is_mounted $2 || {
            loopDevice=/dev/block/loop$LOOP
            [ -f $loopDevice ] || mknod $loopDevice b 7 $LOOP 2>/dev/null
            losetup $loopDevice $1 && {
                mount -t ext4 -o loop $loopDevice $2
                is_mounted $2 || /system/bin/toolbox mount -t ext4 -o loop $loopDevice $2
                is_mounted $2 || /system/bin/toybox mount -t ext4 -o loop $loopDevice $2
            }
            is_mounted $2 && break
        }
    done
    is_mounted $2 || exit 1
}

gen_done_script() {
    cat > $donescript <<EOF
#!/sbin/sh

umount /system
umount $mountPath
losetup -d $loopDevice
rmdir $mountPath
EOF
    chmod 0755 $donescript
}

gen_shrink_script() {
    cat > $doskscript <<EOF
#!/sbin/sh

if [ -f /data/adb/magisk/util_functions.sh ]; then
    . /data/adb/magisk/util_functions.sh
elif [ -f /data/magisk/util_functions.sh ]; then
    NVBASE=/data
    . /data/magisk/util_functions.sh
else
    exit 2
fi

unset ui_print
ui_print() { echo "\$1"; }

IMG=$IMG
MOUNTPATH=$mountPath
MAGISKLOOP=$loopDevice

recovery_actions
unmount_magisk_img
recovery_cleanup

is_mounted \$MOUNTPATH && {
    loopedB=\`mount | grep \$MOUNTPATH | head -n1 | cut -d " " -f1\`
    umount \$MOUNTPATH
    losetup -d \$loopedB
}

rmdir \$MOUNTPATH || exit 1

EOF
    cat > $skscript <<EOF
#!/sbin/sh

$doskscript &>/dev/null
exitcode=\$?

if [ "\$exitcode" -eq 1 ]; then
    echo ""
    echo "! 无法卸载 magisk 镜像!"
    echo ""
    exit 1
fi

if [ "\$exitcode" -eq 2 ]; then
    echo "*******************************"
    echo " 请安装 Magisk v17.0 以上的版本! "
    echo "*******************************"
    exit 2
fi

curSizeM=\`wc -c < $IMG\`
curSizeM=\$((curSizeM / 1048576))

echo ""
echo "- 已将 $IMG 瘦身为 \${curSizeM}M"
echo ""

EOF
    chmod 0755 $doskscript
    chmod 0755 $skscript
}

mount_image $IMG $mountPath

gen_done_script

gen_shrink_script
