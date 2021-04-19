#!/system/bin/sh
#
# Copyright (c) 2015, Motorola Mobility LLC,  All rights reserved.
#
# The purpose of this script is to read panic dumps to /data and dropbox
# for issue report
#

export PATH=/system/bin:$PATH

# read log from "kpan" partition to /data/dontpanic
/system/bin/kpreadwrite r
# write panic/wdt report to dropbox
/system/bin/kpgather

if [ -e /dev/block/bootdevice/by-name/logs ]
then
	cat /dev/block/bootdevice/by-name/logs > /data/dontpanic/BL_logs
	chown root:log /data/dontpanic/BL_logs
	chmod 0640 /data/dontpanic/BL_logs
fi
