#!/system/bin/sh
# sdm855-tune https://github.com/yc9559/sdm855-tune/
# Author: Matt Yang
# Platform: sdm855
# Generated at: 2019-05-25

# $1:value $2:file path
lock_value() 
{
	if [ -f ${2} ]; then
		chmod 0666 ${2}
		echo ${1} > ${2}
		chmod 0444 ${2}
	fi
}

apply_tune()
{
    echo "Applying tuning..."

    # higher sched_downmigrate to use little cluster more
	lock_value "95 95" /proc/sys/kernel/sched_upmigrate
	lock_value "90 85" /proc/sys/kernel/sched_downmigrate

    # reserve more headroom for the app you are interacting with
    lock_value "10" /dev/stune/top-app/schedtune.boost
    lock_value "1" /dev/stune/top-app/schedtune.prefer_idle
    
    # reserve 1 big core for top-app
    lock_value "0-5" /dev/cpuset/foreground/cpus

    echo "Applying tuning done."
}

echo ""

action=$1
# default option is balance
if [ ! -n "$action" ]; then
    action="balance"
fi

if [ "$action" = "powersave" ]; then
    apply_tune
fi

if [ "$action" = "balance" ]; then
    apply_tune
fi

if [ "$action" = "performance" ]; then
    apply_tune
fi

if [ "$action" = "fast" ]; then
    apply_tune
fi

echo ""

exit 0
