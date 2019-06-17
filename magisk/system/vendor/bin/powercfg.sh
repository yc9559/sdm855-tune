#!/system/bin/sh
# sdm855-tune https://github.com/yc9559/sdm855-tune/
# Author: Matt Yang
# Platform: sdm855
# Version: 20190615

module_dir="/data/adb/modules/sdm855-tune"
default_mode_path="/data/powercfg_default_mode"

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
    cp ${module_dir}/system/vendor/etc/perf/perfd_profiles/${1}/* ${module_dir}/system/vendor/etc/perf/
    start perf-hal-1-0
    sleep 1
}

apply_common()
{
    # 580M for empty apps
	lock_value "18432,23040,27648,51256,122880,150296" /sys/module/lowmemorykiller/parameters/minfree

    # if task_util >= (4 / 1024 * 20ms), the task will be boosted(if sched_boost == 2)
    echo "4" > /proc/sys/kernel/sched_min_task_util_for_boost
    # bigger normal colocation boost threshold
    echo "512" > /proc/sys/kernel/sched_min_task_util_for_colocation
    echo "1700000" > /proc/sys/kernel/sched_little_cluster_coloc_fmin_khz

    # treat system_server and surfaceflinger as top-app
    sysserv_pid=`ps -Ao pid,cmd | grep "system_server" | awk '{print $1}'`
    echo ${sysserv_pid} > /dev/stune/top-app/tasks
    echo ${sysserv_pid} > /dev/cpuset/top-app/tasks
    flinger_pid=`ps -Ao pid,cmd | grep "surfaceflinger" | awk '{print $1}'`
    echo ${flinger_pid} > /dev/stune/top-app/tasks
    echo ${flinger_pid} > /dev/cpuset/top-app/tasks

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
    # Flash doesn't have back seek problem, so penalty is as low as possible
    lock_value "1" /sys/block/sda/queue/iosched/back_seek_penalty
    # slice_idle = 0 means CFQ IOP mode, https://lore.kernel.org/patchwork/patch/944972/
    lock_value "0" /sys/block/sda/queue/iosched/slice_idle
    # UFS 2.0+ hardware queue depth is 32
    lock_value "16" /sys/block/sda/queue/iosched/quantum

    # turn off hotplug to reduce latency
    lock_value "0" /sys/devices/system/cpu/cpu0/core_ctl/enable
    # limit the usage of big cluster
    lock_value "1" /sys/devices/system/cpu/cpu4/core_ctl/enable
	echo "0" > /sys/devices/system/cpu/cpu4/core_ctl/min_cpus
	echo "10" > /sys/devices/system/cpu/cpu4/core_ctl/busy_up_thres
	echo "3" > /sys/devices/system/cpu/cpu4/core_ctl/busy_down_thres
	echo "100" > /sys/devices/system/cpu/cpu4/core_ctl/offline_delay_ms
    # task usually doesn't run on cpu7
    lock_value "1" /sys/devices/system/cpu/cpu7/core_ctl/enable
	echo "0" > /sys/devices/system/cpu/cpu7/core_ctl/min_cpus
	echo "30" > /sys/devices/system/cpu/cpu7/core_ctl/busy_up_thres
	echo "3" > /sys/devices/system/cpu/cpu7/core_ctl/busy_down_thres
	echo "100" > /sys/devices/system/cpu/cpu7/core_ctl/offline_delay_ms

    # zram doesn't need much read ahead(random read)
    echo "4" > /sys/block/zram0/queue/read_ahead_kb
}

apply_powersave()
{
    # 0.3-1.7, 0.7-1.6, 0.8-2.0, boost: 2.0+2.4, libqti-perfd-client.so will override it
    echo "300000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
    echo "710400" > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
    echo "825600" > /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq
    echo "1785600" > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq
    echo "2419100" > /sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq
    echo "2841600" > /sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq

    # 1708 * 0.95 / 1785 = 90.9
    # higher sched_downmigrate to use little cluster more
	echo "90 60" > /proc/sys/kernel/sched_downmigrate
	echo "90 85" > /proc/sys/kernel/sched_upmigrate
	echo "90 60" > /proc/sys/kernel/sched_downmigrate

	lock_value "0:0 4:0 7:0" /sys/module/cpu_boost/parameters/input_boost_freq
	lock_value "800" /sys/module/cpu_boost/parameters/input_boost_ms
	lock_value "2" /sys/module/cpu_boost/parameters/sched_boost_on_input

    # limit the usage of big cluster
    lock_value "1" /sys/devices/system/cpu/cpu4/core_ctl/enable
	echo "0" > /sys/devices/system/cpu/cpu4/core_ctl/min_cpus
    # task usually doesn't run on cpu7
    lock_value "1" /sys/devices/system/cpu/cpu7/core_ctl/enable
	echo "0" > /sys/devices/system/cpu/cpu7/core_ctl/min_cpus
}

apply_balance()
{
    # 0.5-1.7, 0.7-2.0, 0.8-2.4, boost: 2.3+2.7, libqti-perfd-client.so will override it
    echo "576000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
    echo "710400" > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
    echo "825600" > /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq
    echo "1785600" > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq
    echo "2419100" > /sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq
    echo "2841600" > /sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq

    # 1708 * 0.95 / 1785 = 90.9
    # higher sched_downmigrate to use little cluster more
	echo "90 60" > /proc/sys/kernel/sched_downmigrate
	echo "90 85" > /proc/sys/kernel/sched_upmigrate
	echo "90 60" > /proc/sys/kernel/sched_downmigrate

	lock_value "0:1036800 4:0 7:0" /sys/module/cpu_boost/parameters/input_boost_freq
	lock_value "800" /sys/module/cpu_boost/parameters/input_boost_ms
	lock_value "2" /sys/module/cpu_boost/parameters/sched_boost_on_input

    # limit the usage of big cluster
    lock_value "1" /sys/devices/system/cpu/cpu4/core_ctl/enable
	echo "1" > /sys/devices/system/cpu/cpu4/core_ctl/min_cpus
    # task usually doesn't run on cpu7
    lock_value "1" /sys/devices/system/cpu/cpu7/core_ctl/enable
	echo "0" > /sys/devices/system/cpu/cpu7/core_ctl/min_cpus
}

apply_performance()
{
    # 0.5-1.7, 0.7-2.4, 0.8-2.8, boost: 2.4+2.8, libqti-perfd-client.so will override it
    echo "576000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
    echo "710400" > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
    echo "825600" > /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq
    echo "1785600" > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq
    echo "2419100" > /sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq
    echo "2841600" > /sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq

    # 1708 * 0.95 / 1785 = 90.9
    # higher sched_downmigrate to use little cluster more
	echo "90 60" > /proc/sys/kernel/sched_downmigrate
	echo "90 85" > /proc/sys/kernel/sched_upmigrate
	echo "90 60" > /proc/sys/kernel/sched_downmigrate

	lock_value "0:1036800 4:0 7:0" /sys/module/cpu_boost/parameters/input_boost_freq
	lock_value "2500" /sys/module/cpu_boost/parameters/input_boost_ms
	lock_value "2" /sys/module/cpu_boost/parameters/sched_boost_on_input

    # turn off core_ctl to reduce latency
    lock_value "0" /sys/devices/system/cpu/cpu4/core_ctl/enable
	echo "3" > /sys/devices/system/cpu/cpu4/core_ctl/min_cpus
    # task usually doesn't run on cpu7
    lock_value "1" /sys/devices/system/cpu/cpu7/core_ctl/enable
	echo "0" > /sys/devices/system/cpu/cpu7/core_ctl/min_cpus
}

apply_fast()
{
    # 1.0-1.7, 1.6-2.0, 1.6-2.6, boost: 2.4+2.8, libqti-perfd-client.so will override it
    echo "1036800" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
    echo "1612800" > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
    echo "1612800" > /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq
    echo "1785600" > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq
    echo "2419100" > /sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq
    echo "2841600" > /sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq

    # same as config_gameBoost
	echo "40 40" > /proc/sys/kernel/sched_downmigrate
	echo "60 60" > /proc/sys/kernel/sched_upmigrate
	echo "40 40" > /proc/sys/kernel/sched_downmigrate

	lock_value "0:0 4:0 7:0" /sys/module/cpu_boost/parameters/input_boost_freq
	lock_value "2500" /sys/module/cpu_boost/parameters/input_boost_ms
	lock_value "3" /sys/module/cpu_boost/parameters/sched_boost_on_input

    # turn off core_ctl to reduce latency
    lock_value "0" /sys/devices/system/cpu/cpu4/core_ctl/enable
	echo "3" > /sys/devices/system/cpu/cpu4/core_ctl/min_cpus
    # turn off core_ctl to reduce latency
    lock_value "0" /sys/devices/system/cpu/cpu7/core_ctl/enable
	echo "1" > /sys/devices/system/cpu/cpu7/core_ctl/min_cpus
}

# suppress stderr
(

echo ""

action=$1

if [ ! -n "$action" ]; then
    # default option is balance
    action="balance"
    # load default mode from file
    if [ -f ${default_mode_path} ]; then
        default_mode=`cat ${default_mode_path} | cut -d" " -f1`
        if [ "${default_mode}" != "" ]; then
            action=${default_mode}
        fi
    fi
fi

# save mode for automatic applying mode after reboot
echo ${action} > ${default_mode_path}

if [ "$action" = "powersave" ]; then
    update_qti_perfd_cfg powersave
    apply_common
    apply_powersave
    echo "Applying powersave done."
fi

if [ "$action" = "balance" ]; then
    update_qti_perfd_cfg balance
    apply_common
    apply_balance
    echo "Applying balance done."
fi

if [ "$action" = "performance" ]; then
    update_qti_perfd_cfg performance
    apply_common
    apply_performance
    echo "Applying performance done."
fi

if [ "$action" = "fast" ]; then
    update_qti_perfd_cfg fast
    apply_common
    apply_fast
    echo "Applying fast done."
fi

if [ "$action" = "debug" ]; then
    echo "sdm855-tune https://github.com/yc9559/sdm855-tune/"
    echo "Author: Matt Yang"
    echo "Platform: sdm855"
    echo "Version: 20190615"
    echo ""
	exit 0
fi

echo ""

# suppress stderr
) 2>/dev/null

exit 0
