#!/system/bin/sh
# sdm855-tune https://github.com/yc9559/sdm855-tune/
# Author: Matt Yang
# Platform: sdm855
# Version: 20190529

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

    # setting sched_set_boost(3) for 700ms when you are touching the screen
    # without setting min_freq, because CONSERVATIVE_BOOST = 3 is good enough
	lock_value "0:0 4:0 7:0" /sys/module/cpu_boost/parameters/input_boost_freq
	lock_value 700 /sys/module/cpu_boost/parameters/input_boost_ms
	lock_value 3 /sys/module/cpu_boost/parameters/sched_boost_on_input

    # 1632 / 1785 = 91.4
	lock_value "91 95" /proc/sys/kernel/sched_upmigrate
    # higher sched_downmigrate to use little cluster more
	lock_value "90 85" /proc/sys/kernel/sched_downmigrate

    # prevent render thread running on cpu0
    lock_value "1-3" /dev/cpuset/background/cpus
    lock_value "1-6" /dev/cpuset/foreground/cpus

    # turn off foreground's sched_boost_enabled
    lock_value "0" /dev/stune/foreground/schedtune.sched_boost_enabled
    lock_value "0" /dev/stune/foreground/schedtune.boost
    lock_value "0" /dev/stune/foreground/schedtune.prefer_idle

    # reserve more headroom for the app you are interacting with
    lock_value "5" /dev/stune/top-app/schedtune.boost
    lock_value "1" /dev/stune/top-app/schedtune.prefer_idle

    # 0 -> 125% for A55, target_load = 80
    lock_value "0" /sys/devices/system/cpu/cpu0/sched_load_boost
    lock_value "0" /sys/devices/system/cpu/cpu1/sched_load_boost
    lock_value "0" /sys/devices/system/cpu/cpu2/sched_load_boost
    lock_value "0" /sys/devices/system/cpu/cpu3/sched_load_boost
    # -6 -> 117.5% for A76, target_load = 85
    lock_value "-6" /sys/devices/system/cpu/cpu4/sched_load_boost
    lock_value "-6" /sys/devices/system/cpu/cpu5/sched_load_boost
    lock_value "-6" /sys/devices/system/cpu/cpu6/sched_load_boost
    # -10 -> 112.5% for A76 prime, target_load = 88
    lock_value "-10" /sys/devices/system/cpu/cpu7/sched_load_boost

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
