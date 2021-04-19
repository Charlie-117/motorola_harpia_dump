#!/system/bin/sh
#
# Copyright (c) 2015, Motorola LLC  All rights reserved.
#

[ "$1" == "-c" ] && CHECK=1

# Abort automatic updates if we are in the factory.
BOOTMODE=`/system/bin/getprop ro.boot.mode`
[ "$BOOTMODE" == "mot-factory" -o "$BOOTMODE" == "factory" ] && FACTORY=1
MANUAL_START=`/system/bin/getprop sys.emmc.ffu_start`
[ "$FACTORY" == "1" -a "$MANUAL_START" != "1" -a "$CHECK" != "1" ] && exit

MID=`cat /sys/block/mmcblk0/device/manfid`
PNM=`cat /sys/block/mmcblk0/device/name`

# eMMC MID is only 1 byte.
MID=${MID#0x0000}

# Skip anything other than Micron.
if [ "$MID" != "fe" ] ; then
  echo "Manufacturer: Other (0x$MID)"
  echo "Device Name: $PNM"
  echo "Result: PASSED"
  echo "emmc_ffu.sh: no action required for $MID:$PNM" > /dev/kmsg
  [ "$CHECK" == "1" ] && /system/bin/setprop sys.emmc.ffu_needed 0
  exit
fi

echo "Manufacturer: Micron"
echo "Device Name: $PNM"

CID=`cat /sys/block/mmcblk0/device/cid`
PRV=${CID:18:2}
echo "Product Revision: $PRV"

FIRMWARE_VERSION=`cat /sys/block/mmcblk0/device/firmware_version`
FIRMWARE_VERSION=${FIRMWARE_VERSION#0x}
echo "Firmware Version: $FIRMWARE_VERSION"
FIRMWARE_FILE="emmc_ffu_${MID}_${PNM}_${FIRMWARE_VERSION}.fw"

# Check to see if we have an update for this firmware version (the file name matches the current
# firmware version number).
if [ ! -e /system/etc/firmware/$FIRMWARE_FILE ] ; then
  echo "Result: PASSED"
  echo "emmc_ffu.sh: no update available for Micron firmware $FIRMWARE_VERSION" > /dev/kmsg
  [ "$CHECK" == "1" ] && /system/bin/setprop sys.emmc.ffu_needed 0
  exit
fi
FIRMWARE_PATH=`/system/bin/ls /system/etc/firmware/$FIRMWARE_FILE`

# Make sure we have Micron's modified mmc tool.
if [ ! -x /system/bin/emmc_ffu_fe ] ; then
  echo "Result: FAILED"
  echo "emmc_ffu.sh: missing flash tool executable" > /dev/kmsg
  exit
fi

echo "Firmware: $FIRMWARE_PATH"

# Just performing a check, so exit now.
if [ "$CHECK" == "1" ] ; then
  echo "Result: UPGRADE NEEDED"
  echo "emmc_ffu.sh: upgrade needed for Micron firmware $FIRMWARE_VERSION" > /dev/kmsg
  /system/bin/setprop sys.emmc.ffu_needed 1
  exit
fi

# There is a risk of bricking the eMMC if we apply this more than once too quickly.
UPDATE_PASS=0
[ -e /data/local/.$FIRMWARE_FILE ] && UPDATE_PASS=`/system/bin/cat /data/local/.$FIRMWARE_FILE`
UPDATE_PASS=$((10#$UPDATE_PASS + 1))

if [ "$FACTORY" != "1" -a "$UPDATE_PASS" -gt "3" ] ; then
  echo "Result: FAILED (update attempted too many times)"
  echo "emmc_ffu.sh: update attempted too many times for Micron firmware $FIRMWARE_VERSION" > /dev/kmsg
  exit
fi

echo "emmc_ffu.sh: applying $FIRMWARE_FILE (pass $UPDATE_PASS)" > /dev/kmsg

# Disable RPM, as sleep seems to cause problems with FFU.
echo on > /sys/block/mmcblk0/device/power/control

# Shutdown the framework
/system/bin/setprop vold.decrypt trigger_reset_main

# Stamp before the upgrade in case the process prangs the eMMC.
echo $UPDATE_PASS > /data/local/.$FIRMWARE_FILE
/system/bin/sync

# The FFU process is very touchy, so allow the framework stop to finish and
# let things calm down before attempting it.
sleep $(($UPDATE_PASS * 4))

# Flash the firmware.
/system/bin/emmc_ffu_fe ffu $FIRMWARE_PATH /dev/block/mmcblk0 > /dev/kmsg
RESULT=$?
if [ "$RESULT" != "0" ] ; then
  echo "emmc_ffu.sh: firmware upgrade failed ($RESULT)" > /dev/kmsg
  echo "Result: FAILED"
  # This usually means we are hosed, so force a reboot
  echo b > /proc/sysrq-trigger
fi

echo "Result: PASSED"
echo "emmc_ffu.sh: firmware successfully upgraded" > /dev/kmsg

echo "Rebooting..."
# The eMMC is usually off in the weeds at this point, so force a reboot
echo b > /proc/sysrq-trigger
