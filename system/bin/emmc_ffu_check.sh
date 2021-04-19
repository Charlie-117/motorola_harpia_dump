#!/system/bin/sh
#
# Copyright (c) 2013-2015, Motorola LLC  All rights reserved.
#

SCRIPT=${0#/system/bin/}

MID=`cat /sys/block/mmcblk0/device/manfid`
if [ "$MID" != "0x0000fe" ] ; then
  echo "Result: FAIL"
  echo "$SCRIPT: manufacturer not supported" > /dev/kmsg
  exit
fi

# Handle the legacy user-space eMMC 4.51 FFU version check for Micron
if [ -x /system/bin/emmc_ffu_fe_legacy.sh ] ; then
  /system/bin/sh /system/bin/emmc_ffu_fe_legacy.sh -c
else
  echo "Result: PASS"
  echo "$SCRIPT: no action required" > /dev/kmsg
  exit
fi
