#!/system/bin/sh
# sdm855-tune https://github.com/yc9559/sdm855-tune/
# Author: Matt Yang
# Platform: sdm855
# Version: 20190606

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

    # power cruve of 576-1209 is almost linear
	lock_value "0:1036800 4:0 7:0" /sys/module/cpu_boost/parameters/input_boost_freq
	lock_value 800 /sys/module/cpu_boost/parameters/input_boost_ms
	lock_value 2 /sys/module/cpu_boost/parameters/sched_boost_on_input

    # 1708 * 0.95 / 1785 = 90.9
	lock_value "91 95" /proc/sys/kernel/sched_upmigrate
    # higher sched_downmigrate to use little cluster more
	lock_value "91 85" /proc/sys/kernel/sched_downmigrate

    # if task_util >= (100 / 1024 * 20ms), the task will be boosted
    lock_value 100 /proc/sys/kernel/sched_min_task_util_for_boost
    lock_value 50 /proc/sys/kernel/sched_min_task_util_for_colocation

    # prevent render thread running on cpu0
    lock_value "0-3" /dev/cpuset/background/cpus
    lock_value "1-6" /dev/cpuset/foreground/cpus
    lock_value "0-7" /dev/cpuset/top-app/cpus

    # always limit background task
    lock_value "0" /dev/stune/background/schedtune.sched_boost_enabled
    lock_value "0" /dev/stune/background/schedtune.sched_boost_no_override
    lock_value "0" /dev/stune/background/schedtune.boost
    lock_value "0" /dev/stune/background/schedtune.prefer_idle
    # limit sched_boost override on foreground task
    lock_value "1" /dev/stune/foreground/schedtune.sched_boost_enabled
    lock_value "0" /dev/stune/foreground/schedtune.sched_boost_no_override
    lock_value "0" /dev/stune/foreground/schedtune.boost
    lock_value "0" /dev/stune/foreground/schedtune.prefer_idle
    # "boost" effect on ArkNight(CPU0 frequency used most): 0->1036, 1->1113, 5->1305
    lock_value "1" /dev/stune/top-app/schedtune.sched_boost_enabled
    lock_value "1" /dev/stune/top-app/schedtune.sched_boost_no_override
    # do not use lock_value(), libqti-perfd-client.so will fail to override it
    echo "0" > /dev/stune/top-app/schedtune.boost
    echo "0" > /dev/stune/top-app/schedtune.prefer_idle

    # 0 -> 125% for A55, target_load = 80
    lock_value "0" /sys/devices/system/cpu/cpu0/sched_load_boost
    lock_value "0" /sys/devices/system/cpu/cpu1/sched_load_boost
    lock_value "0" /sys/devices/system/cpu/cpu2/sched_load_boost
    lock_value "0" /sys/devices/system/cpu/cpu3/sched_load_boost
    # -6 -> 117.5% for A76, target_load = 85
    lock_value "-6" /sys/devices/system/cpu/cpu4/sched_load_boost
    lock_value "-6" /sys/devices/system/cpu/cpu5/sched_load_boost
    lock_value "-6" /sys/devices/system/cpu/cpu6/sched_load_boost
    # -6 -> 117.5% for A76 prime, target_load = 85
    lock_value "-6" /sys/devices/system/cpu/cpu7/sched_load_boost

    # CFQ io scheduler takes cgroup into consideration
    lock_value "cfq" /sys/block/sda/queue/scheduler
    # 32K means read more 32K data(starting at 0x0) when reading at 0x0, lower overhead on random iop
    lock_value "32" /sys/block/sda/queue/read_ahead_kb
    # Flash doesn't have back seek problem, so penalty is as low as possible
    lock_value "1" /sys/block/sda/queue/iosched/back_seek_penalty
    # slice_idle = 0 means CFQ IOP mode, https://lore.kernel.org/patchwork/patch/944972/
    lock_value "0" /sys/block/sda/queue/iosched/slice_idle
    # UFS 2.0+ hardware queue depth is 32
    lock_value "32" /sys/block/sda/queue/iosched/quantum
    # Lower than default value "8"
    lock_value "4" /sys/block/sda/queue/iosched/group_idle

    # turn off hotplug to reduce latency
    lock_value "0" /sys/devices/system/cpu/cpu0/core_ctl/enable
    # limit the usage of big cluster
    lock_value "1" /sys/devices/system/cpu/cpu4/core_ctl/enable
	echo 0 > /sys/devices/system/cpu/cpu4/core_ctl/min_cpus
	echo 10 > /sys/devices/system/cpu/cpu4/core_ctl/busy_up_thres
	echo 3 > /sys/devices/system/cpu/cpu4/core_ctl/busy_down_thres
	echo 100 > /sys/devices/system/cpu/cpu4/core_ctl/offline_delay_ms
    # task usually doesn't run on cpu7
    lock_value "1" /sys/devices/system/cpu/cpu7/core_ctl/enable
	echo 0 > /sys/devices/system/cpu/cpu7/core_ctl/min_cpus
	echo 30 > /sys/devices/system/cpu/cpu7/core_ctl/busy_up_thres
	echo 3 > /sys/devices/system/cpu/cpu7/core_ctl/busy_down_thres
	echo 100 > /sys/devices/system/cpu/cpu7/core_ctl/offline_delay_ms

    # reduce latency of reaching sched_upmigrate, libqti-perfd-client.so will override it
    # echo "1209600" > /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_freq
    # echo "90" > /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_load
    # echo "1401600" > /sys/devices/system/cpu/cpufreq/policy4/schedutil/hispeed_freq
    # echo "90" > /sys/devices/system/cpu/cpufreq/policy4/schedutil/hispeed_load

    echo 0 > /sys/block/zram0/queue/read_ahead_kb

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
