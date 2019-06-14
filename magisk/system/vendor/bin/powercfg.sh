#!/system/bin/sh
# sdm855-tune https://github.com/yc9559/sdm855-tune/
# Author: Matt Yang
# Platform: sdm855
# Version: 20190612

# $1:value $2:file path
lock_value() 
{
	if [ -f ${2} ]; then
		chmod 0666 ${2}
		echo ${1} > ${2}
		chmod 0444 ${2}
	fi
}

# $1:mode(such as balance)
update_qti_perfd_cfg()
{
    stop perf-hal-1-0
    cp /data/adb/modules/sdm855-tune/system/vendor/etc/perf/perfd_profiles/${1}/* /data/adb/modules/sdm855-tune/system/vendor/etc/perf/
    start perf-hal-1-0
}

apply_common()
{
    # 580M for empty apps
	lock_value "18432,23040,27648,51256,122880,150296" /sys/module/lowmemorykiller/parameters/minfree

    # 1708 * 0.95 / 1785 = 90.9
	lock_value "91 85" /proc/sys/kernel/sched_upmigrate
    # higher sched_downmigrate to use little cluster more
	lock_value "91 60" /proc/sys/kernel/sched_downmigrate

    # if task_util >= (2 / 1024 * 20ms), the task will be boosted(if sched_boost == 2)
    lock_value 2 /proc/sys/kernel/sched_min_task_util_for_boost
    # bigger normal colocation boost threshold
    lock_value 512 /proc/sys/kernel/sched_min_task_util_for_colocation
    lock_value 1700000 /proc/sys/kernel/sched_little_cluster_coloc_fmin_khz
  
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

    # zram doesn't need much read ahead(random read)
    echo 4 > /sys/block/zram0/queue/read_ahead_kb
}

apply_powersave()
{
    # same as default
    echo 576000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
    echo 710400 > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
    echo 825600 > /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq

	lock_value "0:1036800 4:0 7:0" /sys/module/cpu_boost/parameters/input_boost_freq
	lock_value 800 /sys/module/cpu_boost/parameters/input_boost_ms
	lock_value 2 /sys/module/cpu_boost/parameters/sched_boost_on_input

    # limit the usage of big cluster
    lock_value "1" /sys/devices/system/cpu/cpu4/core_ctl/enable
	echo 0 > /sys/devices/system/cpu/cpu4/core_ctl/min_cpus
    # task usually doesn't run on cpu7
    lock_value "1" /sys/devices/system/cpu/cpu7/core_ctl/enable
	echo 0 > /sys/devices/system/cpu/cpu7/core_ctl/min_cpus

    update_qti_perfd_cfg powersave
}

apply_balance()
{
    # same as default
    echo 576000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
    echo 710400 > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
    echo 825600 > /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq

	lock_value "0:1036800 4:0 7:0" /sys/module/cpu_boost/parameters/input_boost_freq
	lock_value 800 /sys/module/cpu_boost/parameters/input_boost_ms
	lock_value 2 /sys/module/cpu_boost/parameters/sched_boost_on_input

    # limit the usage of big cluster
    lock_value "1" /sys/devices/system/cpu/cpu4/core_ctl/enable
	echo 0 > /sys/devices/system/cpu/cpu4/core_ctl/min_cpus
    # task usually doesn't run on cpu7
    lock_value "1" /sys/devices/system/cpu/cpu7/core_ctl/enable
	echo 0 > /sys/devices/system/cpu/cpu7/core_ctl/min_cpus

    update_qti_perfd_cfg balance
}

apply_performance()
{
    # same as default
    echo 576000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
    echo 710400 > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
    echo 825600 > /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq

	lock_value "0:1036800 4:0 7:0" /sys/module/cpu_boost/parameters/input_boost_freq
	lock_value 800 /sys/module/cpu_boost/parameters/input_boost_ms
	lock_value 2 /sys/module/cpu_boost/parameters/sched_boost_on_input

    # limit the usage of big cluster
    lock_value "1" /sys/devices/system/cpu/cpu4/core_ctl/enable
	echo 0 > /sys/devices/system/cpu/cpu4/core_ctl/min_cpus
    # task usually doesn't run on cpu7
    lock_value "1" /sys/devices/system/cpu/cpu7/core_ctl/enable
	echo 0 > /sys/devices/system/cpu/cpu7/core_ctl/min_cpus

    update_qti_perfd_cfg performance
}

apply_fast()
{
    # same as default
    echo 576000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
    echo 710400 > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
    echo 825600 > /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq

	lock_value "0:1036800 4:0 7:0" /sys/module/cpu_boost/parameters/input_boost_freq
	lock_value 800 /sys/module/cpu_boost/parameters/input_boost_ms
	lock_value 2 /sys/module/cpu_boost/parameters/sched_boost_on_input

    # limit the usage of big cluster
    lock_value "1" /sys/devices/system/cpu/cpu4/core_ctl/enable
	echo 0 > /sys/devices/system/cpu/cpu4/core_ctl/min_cpus
    # task usually doesn't run on cpu7
    lock_value "1" /sys/devices/system/cpu/cpu7/core_ctl/enable
	echo 0 > /sys/devices/system/cpu/cpu7/core_ctl/min_cpus

    update_qti_perfd_cfg fast
}

# suppress stderr
(

echo ""

action=$1
# default option is balance
if [ ! -n "$action" ]; then
    action="balance"
fi

if [ "$action" = "powersave" ]; then
    apply_common
    apply_powersave
    echo "Applying powersave done."
fi

if [ "$action" = "balance" ]; then
    apply_common
    apply_balance
    echo "Applying balance done."
fi

if [ "$action" = "performance" ]; then
    apply_common
    apply_performance
    echo "Applying performance done."
fi

if [ "$action" = "fast" ]; then
    apply_common
    apply_fast
    echo "Applying fast done."
fi

if [ "$action" = "debug" ]; then
    echo "sdm855-tune https://github.com/yc9559/sdm855-tune/"
    echo "Author: Matt Yang"
    echo "Platform: sdm855"
    echo "Version: 20190612"
    echo ""
	exit 0
fi

echo ""

# suppress stderr
) 2>/dev/null

exit 0
