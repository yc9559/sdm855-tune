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

    # 580M for empty apps
	lock_value "18432,23040,27648,51256,122880,150296" /sys/module/lowmemorykiller/parameters/minfree

    # sched_set_boost(1) for 80ms when you are touching the screen
	lock_value "0:0 4:1056000 7:0" /sys/module/cpu_boost/parameters/input_boost_freq
	lock_value 80 /sys/module/cpu_boost/parameters/input_boost_ms
	lock_value 1 /sys/module/cpu_boost/parameters/sched_boost_on_input

    # 1632 / 1785 = 91.4
	lock_value "91 95" /proc/sys/kernel/sched_upmigrate
    # higher sched_downmigrate to use little cluster more
	lock_value "90 85" /proc/sys/kernel/sched_downmigrate

    # turn off foreground's sched_boost_enabled
    lock_value "0" /dev/stune/foreground/schedtune.sched_boost_enabled
    lock_value "0" /dev/stune/foreground/schedtune.boost
    lock_value "0" /dev/stune/foreground/schedtune.prefer_idle

    # reserve more headroom for the app you are interacting with
    lock_value "10" /dev/stune/top-app/schedtune.boost
    lock_value "1" /dev/stune/top-app/schedtune.prefer_idle

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
