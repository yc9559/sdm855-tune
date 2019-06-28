#! /vendor/bin/sh
# sdm855-tune https://github.com/yc9559/sdm855-tune/
# Author: Matt Yang
# Platform: sdm855
# Version: 20190624

module_dir="/data/adb/modules/sdm855-tune"
default_mode_path="/sdcard/powercfg_default_mode"

# $1:value $2:file path
lock_value() 
{
    if [ -f ${2} ]; then
        chmod 0666 ${2}
        echo ${1} > ${2}
        chmod 0444 ${2}
    fi
}

# stop before updating cfg
stop_qti_perfd()
{
    stop perf-hal-1-0
}

# start after updating cfg
start_qti_perfd()
{
    start perf-hal-1-0
}

# $1:mode(such as balance)
update_qti_perfd()
{
    rm /data/vendor/perfd/default_values
    cp ${module_dir}/system/vendor/etc/perf/perfd_profiles/${1}/* ${module_dir}/system/vendor/etc/perf/
}

apply_common()
{
    # 580M for empty apps
    lock_value "18432,23040,27648,51256,122880,150296" /sys/module/lowmemorykiller/parameters/minfree

    # if task_util >= (896 / 1024 * 20ms = 17.5ms)
    echo "896" > /proc/sys/kernel/sched_min_task_util_for_boost
    # if task_util >= (640 / 1024 * 20ms = 12.5ms)
    echo "640" > /proc/sys/kernel/sched_min_task_util_for_colocation
    # normal colocation util report
    echo "1000000" > /proc/sys/kernel/sched_little_cluster_coloc_fmin_khz
    # prevent big tasks which we aren't interacting with running on big cluster
    echo "0" > /proc/sys/kernel/sched_walt_rotate_big_tasks
    # placebo tweak
    echo "0" > /proc/sys/kernel/sched_schedstats
    echo "1000000" > /proc/sys/kernel/sched_wakeup_granularity_ns

    # prevent foreground using big cluster, libqti-perfd-client.so will override it
    echo "0-3" > /dev/cpuset/foreground/cpus

    # avoid display preemption on big
    lock_value "0-3" /dev/cpuset/display/cpus

    # treat surfaceflinger as display
    flinger_pid=`ps -Ao pid,cmd | grep "surfaceflinger" | awk '{print $1}'`
    echo ${flinger_pid} > /dev/cpuset/display/tasks

    # treat crtc_commit as display
    crtc_pids=`ps -Ao pid,cmd | grep "crtc_commit" | awk '{print $1}'`
    for crtc_pid in ${crtc_pids}
    do
        echo ${crtc_pid} > /dev/cpuset/display/tasks
    done

    # treat servicemanager as foreground, fix laggy scrolling bilibili feed issue
    servmgr_pid=`ps -Ao pid,cmd | grep " servicemanager" | awk '{print $1}'`
    echo ${servmgr_pid} > /dev/cpuset/foreground/tasks

    # move all top-app to foreground to reduce nr_top_app
    for ttask in `cat /dev/cpuset/top-app/tasks`
    do
        echo ${ttask} > /dev/cpuset/foreground/tasks
    done

    # unify schedtune misc
    lock_value "0" /dev/stune/background/schedtune.sched_boost_enabled
    lock_value "1" /dev/stune/background/schedtune.sched_boost_no_override
    lock_value "0" /dev/stune/background/schedtune.boost
    lock_value "0" /dev/stune/background/schedtune.prefer_idle
    lock_value "0" /dev/stune/foreground/schedtune.sched_boost_enabled
    lock_value "1" /dev/stune/foreground/schedtune.sched_boost_no_override
    lock_value "0" /dev/stune/foreground/schedtune.boost
    lock_value "1" /dev/stune/foreground/schedtune.prefer_idle
    lock_value "0" /dev/stune/top-app/schedtune.sched_boost_enabled
    lock_value "1" /dev/stune/top-app/schedtune.sched_boost_no_override

    # CFQ io scheduler takes cgroup into consideration
    lock_value "cfq" /sys/block/sda/queue/scheduler
    # Flash doesn't have back seek problem, so penalty is as low as possible
    lock_value "1" /sys/block/sda/queue/iosched/back_seek_penalty
    # slice_idle = 0 means CFQ IOP mode, https://lore.kernel.org/patchwork/patch/944972/
    lock_value "0" /sys/block/sda/queue/iosched/slice_idle
    # UFS 2.0+ hardware queue depth is 32
    lock_value "16" /sys/block/sda/queue/iosched/quantum
    # lower read_ahead_kb to reduce random access overhead
    lock_value "128" /sys/block/sda/queue/read_ahead_kb

    # turn off hotplug to reduce latency
    lock_value "0" /sys/devices/system/cpu/cpu0/core_ctl/enable
    # limit the usage of big cluster
    echo "15" > /sys/devices/system/cpu/cpu4/core_ctl/busy_up_thres
    echo "5" > /sys/devices/system/cpu/cpu4/core_ctl/busy_down_thres
    echo "100" > /sys/devices/system/cpu/cpu4/core_ctl/offline_delay_ms
    echo "5" > /sys/devices/system/cpu/cpu4/core_ctl/task_thres
    # task usually doesn't run on cpu7
    echo "15" > /sys/devices/system/cpu/cpu7/core_ctl/busy_up_thres
    echo "10" > /sys/devices/system/cpu/cpu7/core_ctl/busy_down_thres
    echo "100" > /sys/devices/system/cpu/cpu7/core_ctl/offline_delay_ms

    # zram doesn't need much read ahead(random read)
    echo "4" > /sys/block/zram0/queue/read_ahead_kb

    # unify scaling_max_freq, libqti-perfd-client.so will override it
    echo "1785600" > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq
    echo "2419100" > /sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq
    echo "2841600" > /sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq

    # adreno default settings
    lock_value "0" /sys/class/kgsl/kgsl-3d0/force_no_nap
    lock_value "1" /sys/class/kgsl/kgsl-3d0/bus_split
    lock_value "0" /sys/class/kgsl/kgsl-3d0/force_bus_on
    lock_value "0" /sys/class/kgsl/kgsl-3d0/force_clk_on
    lock_value "0" /sys/class/kgsl/kgsl-3d0/force_rail_on
}

apply_powersave()
{
    # 0.3-1.7, 0.7-1.6, 0.8-2.0, boost: 2.0+2.4, libqti-perfd-client.so will override it
    echo "300000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
    echo "710400" > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
    echo "825600" > /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq

    # 1708 * 0.95 / 1785 = 90.9
    # higher sched_downmigrate to use little cluster more
    echo "90 60" > /proc/sys/kernel/sched_downmigrate
    echo "90 85" > /proc/sys/kernel/sched_upmigrate
    echo "90 60" > /proc/sys/kernel/sched_downmigrate

    # do not use lock_value(), libqti-perfd-client.so will fail to override it
    echo "0" > /dev/stune/top-app/schedtune.boost
    echo "0" > /dev/stune/top-app/schedtune.prefer_idle

    lock_value "0:0 4:0 7:0" /sys/module/cpu_boost/parameters/input_boost_freq
    lock_value "500" /sys/module/cpu_boost/parameters/input_boost_ms
    lock_value "3" /sys/module/cpu_boost/parameters/sched_boost_on_input

    # limit the usage of big cluster
    lock_value "1" /sys/devices/system/cpu/cpu4/core_ctl/enable
    echo "0" > /sys/devices/system/cpu/cpu4/core_ctl/min_cpus
    # task usually doesn't run on cpu7
    lock_value "1" /sys/devices/system/cpu/cpu7/core_ctl/enable
    echo "0" > /sys/devices/system/cpu/cpu7/core_ctl/min_cpus
}

apply_balance()
{
    # libqti-perfd-client.so will override it
    echo "576000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
    echo "710400" > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
    echo "825600" > /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq

    # 1708 * 0.95 / 1785 = 90.9
    # higher sched_downmigrate to use little cluster more
    echo "90 60" > /proc/sys/kernel/sched_downmigrate
    echo "90 85" > /proc/sys/kernel/sched_upmigrate
    echo "90 60" > /proc/sys/kernel/sched_downmigrate

    # do not use lock_value(), libqti-perfd-client.so will fail to override it
    echo "0" > /dev/stune/top-app/schedtune.boost
    echo "0" > /dev/stune/top-app/schedtune.prefer_idle

    lock_value "0:1036800 4:1056000 7:0" /sys/module/cpu_boost/parameters/input_boost_freq
    lock_value "500" /sys/module/cpu_boost/parameters/input_boost_ms
    lock_value "3" /sys/module/cpu_boost/parameters/sched_boost_on_input

    # limit the usage of big cluster
    lock_value "1" /sys/devices/system/cpu/cpu4/core_ctl/enable
    echo "2" > /sys/devices/system/cpu/cpu4/core_ctl/min_cpus
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

    # 1708 * 0.95 / 1785 = 90.9
    # higher sched_downmigrate to use little cluster more
    echo "90 60" > /proc/sys/kernel/sched_downmigrate
    echo "90 85" > /proc/sys/kernel/sched_upmigrate
    echo "90 60" > /proc/sys/kernel/sched_downmigrate

    # do not use lock_value(), libqti-perfd-client.so will fail to override it
    echo "10" > /dev/stune/top-app/schedtune.boost
    echo "1" > /dev/stune/top-app/schedtune.prefer_idle

    lock_value "0:1209600 4:1612800 7:0" /sys/module/cpu_boost/parameters/input_boost_freq
    lock_value "2000" /sys/module/cpu_boost/parameters/input_boost_ms
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

    # same as config_gameBoost
    echo "40 40" > /proc/sys/kernel/sched_downmigrate
    echo "60 60" > /proc/sys/kernel/sched_upmigrate
    echo "40 40" > /proc/sys/kernel/sched_downmigrate

    # do not use lock_value(), libqti-perfd-client.so will fail to override it
    echo "20" > /dev/stune/top-app/schedtune.boost
    echo "1" > /dev/stune/top-app/schedtune.prefer_idle

    lock_value "0:0 4:0 7:0" /sys/module/cpu_boost/parameters/input_boost_freq
    lock_value "2000" /sys/module/cpu_boost/parameters/input_boost_ms
    lock_value "1" /sys/module/cpu_boost/parameters/sched_boost_on_input

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
        default_mode=`cat ${default_mode_path} | sed -n "1p" | awk '{printf $1}'`
        if [ "${default_mode}" != "" ]; then
            action=${default_mode}
        fi
    fi
fi

# we doesn't have the permission to write "/sdcard" before the user unlocks the screen
while [ ! -e ${default_mode_path} ] 
do
    touch ${default_mode_path}
    sleep 2
done

if [ "$action" = "powersave" ]; then
    stop_qti_perfd
    apply_common
    apply_powersave
    update_qti_perfd powersave
    start_qti_perfd
    echo "Applying powersave done."
fi

if [ "$action" = "balance" ]; then
    stop_qti_perfd
    apply_common
    apply_balance
    update_qti_perfd balance
    start_qti_perfd
    echo "Applying balance done."
fi

if [ "$action" = "performance" ]; then
    stop_qti_perfd
    apply_common
    apply_performance
    update_qti_perfd performance
    start_qti_perfd
    echo "Applying performance done."
fi

if [ "$action" = "fast" ]; then
    stop_qti_perfd
    apply_common
    apply_fast
    update_qti_perfd fast
    start_qti_perfd
    echo "Applying fast done."
fi

# save mode for automatic applying mode after reboot
echo ${action}                                              > ${default_mode_path}
echo ""                                                     >> ${default_mode_path}
echo "sdm855-tune https://github.com/yc9559/sdm855-tune/"   >> ${default_mode_path}
echo "Author:   Matt Yang"                                  >> ${default_mode_path}
echo "Platform: sdm855"                                     >> ${default_mode_path}
echo "Version:  20190624"                                   >> ${default_mode_path}
echo ""                                                     >> ${default_mode_path}
echo "Last performed: `date '+%Y-%m-%d %H:%M:%S'`"          >> ${default_mode_path}

echo "${default_mode_path} has been updated."

echo ""

# suppress stderr
) 2>/dev/null

exit 0
