#!/system/bin/sh
#
# Copyright (c) 2015, Motorola Mobility LLC,  All rights reserved.
#
# The purpose of this script is to annotate panic dumps with useful information
# about the context of the event, and then save to emmc.
#

export PATH=/system/bin:$PATH

annotate()
{
    VAL=`$2`
    [ "$VAL" ] || return

    echo "$1: $VAL" > /sys/fs/pstore/annotate-ramoops
}

case $1 in
    build*)
        annotate "Build number" "getprop ro.build.display.id"
        annotate "Build config" "getprop ro.build.config.version"
        annotate "Kernel version" "cat /proc/sys/kernel/osrelease"
        ;;
    baseband*)
        annotate "Baseband version" "getprop gsm.version.baseband"
        ;;
esac

# write log from pstore to "kpan" partition
/system/bin/kpreadwrite w
