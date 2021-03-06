#! /vendor/bin/sh
# sdm855-tune https://github.com/yc9559/sdm855-tune/
# Author: Matt Yang
# Platform: sdm855
# Version: 20190712

module_dir="/data/adb/modules/sdm855-tune"
panel_path="/sdcard/powercfg_panel.txt"

# target power mode
action=$1

# $1:value $2:file path
lock_value() 
{
    if [ -f ${2} ]; then
        chmod 0666 ${2}
        echo ${1} > ${2}
        chmod 0444 ${2}
    fi
}

# $1:task_name $2:cgroup_name $3:"cpuset"/"stune"
change_task_cgroup()
{
    temp_pids=`ps -Ao pid,cmd | grep "${1}" | awk '{print $1}'`
    for temp_pid in ${temp_pids}
    do
        for temp_tid in `ls /proc/${temp_pid}/task/`
        do
            echo ${temp_tid} > /dev/${3}/${2}/tasks
        done
    done
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

# $1:key $return:value(string)
read_cfg_value()
{
    value=""
    if [ -f ${panel_path} ]; then
        value=`grep "^${1}=" "${panel_path}" | tr -d ' ' | cut -d= -f2`
    fi
    echo ${value}
}

apply_common()
{
    # 580M for empty apps
    lock_value "18432,23040,27648,51256,122880,150296" /sys/module/lowmemorykiller/parameters/minfree

    # task_util(p) = p->ravg.demand_scaled <= sysctl_sched_min_task_util_for_boost
    echo "16" > /proc/sys/kernel/sched_min_task_util_for_boost
    echo "96" > /proc/sys/kernel/sched_min_task_util_for_colocation
    # normal colocation util report
    echo "1000000" > /proc/sys/kernel/sched_little_cluster_coloc_fmin_khz
    # prevent big tasks which we aren't interacting with running on big cluster
    echo "0" > /proc/sys/kernel/sched_walt_rotate_big_tasks

    # move all top-app to foreground to reduce nr_top_app
    for ttask in `cat /dev/cpuset/top-app/tasks`
    do
        echo ${ttask} > /dev/cpuset/foreground/tasks
        echo ${ttask} > /dev/stune/foreground/tasks
    done

    # prevent foreground using big cluster, may be override
    echo "0-3" > /dev/cpuset/foreground/cpus

    # treat crtc_commit as display
    change_task_cgroup "crtc_commit" "display" "cpuset"

    # avoid display preemption on big
    lock_value "0-3" /dev/cpuset/display/cpus

    # fix laggy bilibili feed scrolling
    change_task_cgroup "servicemanager" "top-app" "cpuset"
    change_task_cgroup "servicemanager" "top-app" "stune"
    change_task_cgroup "android.phone" "top-app" "cpuset"
    change_task_cgroup "android.phone" "top-app" "stune"

    # fix laggy home gesture
    change_task_cgroup "system_server" "top-app" "cpuset"
    change_task_cgroup "system_server" "top-app" "stune"

    # reduce render thread waiting time
    change_task_cgroup "surfaceflinger" "top-app" "cpuset"
    change_task_cgroup "surfaceflinger" "top-app" "stune"

    # unify schedtune misc
    lock_value "0" /dev/stune/background/schedtune.sched_boost_enabled
    lock_value "1" /dev/stune/background/schedtune.sched_boost_no_override
    lock_value "0" /dev/stune/background/schedtune.boost
    lock_value "0" /dev/stune/background/schedtune.prefer_idle
    lock_value "0" /dev/stune/foreground/schedtune.sched_boost_enabled
    lock_value "1" /dev/stune/foreground/schedtune.sched_boost_no_override
    lock_value "0" /dev/stune/foreground/schedtune.boost
    lock_value "1" /dev/stune/foreground/schedtune.prefer_idle
    lock_value "0" /dev/stune/top-app/schedtune.sched_boost_no_override

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
    # tend to online more cores to balance parallel tasks
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

    # unify scaling_min_freq, may be override
    echo "576000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
    echo "710400" > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
    echo "825600" > /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq

    # unify scaling_max_freq, may be override
    echo "1785600" > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq
    echo "2419100" > /sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq
    echo "2841600" > /sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq

    # unify group_migrate
	lock_value "120" /proc/sys/kernel/sched_group_upmigrate
	lock_value "100" /proc/sys/kernel/sched_group_downmigrate

    # adreno default settings
    lock_value "0" /sys/class/kgsl/kgsl-3d0/force_no_nap
    lock_value "1" /sys/class/kgsl/kgsl-3d0/bus_split
    lock_value "0" /sys/class/kgsl/kgsl-3d0/force_bus_on
    lock_value "0" /sys/class/kgsl/kgsl-3d0/force_clk_on
    lock_value "0" /sys/class/kgsl/kgsl-3d0/force_rail_on
}

apply_powersave()
{
    # may be override
    echo "300000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
    echo "710400" > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
    echo "825600" > /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq

    # 1708 * 0.95 / 1785 = 90.9
    # higher sched_downmigrate to use little cluster more
    echo "90 60" > /proc/sys/kernel/sched_downmigrate
    echo "90 85" > /proc/sys/kernel/sched_upmigrate
    echo "90 60" > /proc/sys/kernel/sched_downmigrate

    # do not use lock_value(), libqti-perfd-client.so will fail to override it
    echo "0" > /dev/stune/top-app/schedtune.sched_boost_enabled
    echo "0" > /dev/stune/top-app/schedtune.boost
    echo "0" > /dev/stune/top-app/schedtune.prefer_idle

    lock_value "0:1036800 4:0 7:0" /sys/module/cpu_boost/parameters/input_boost_freq
    lock_value "500" /sys/module/cpu_boost/parameters/input_boost_ms
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
    # 1708 * 0.95 / 1785 = 90.9
    # higher sched_downmigrate to use little cluster more
    echo "90 60" > /proc/sys/kernel/sched_downmigrate
    echo "90 85" > /proc/sys/kernel/sched_upmigrate
    echo "90 60" > /proc/sys/kernel/sched_downmigrate

    # do not use lock_value(), libqti-perfd-client.so will fail to override it
    echo "0" > /dev/stune/top-app/schedtune.sched_boost_enabled
    echo "0" > /dev/stune/top-app/schedtune.boost
    echo "0" > /dev/stune/top-app/schedtune.prefer_idle

    lock_value "0:1036800 4:1056000 7:0" /sys/module/cpu_boost/parameters/input_boost_freq
    lock_value "500" /sys/module/cpu_boost/parameters/input_boost_ms
    lock_value "2" /sys/module/cpu_boost/parameters/sched_boost_on_input

    # limit the usage of big cluster
    lock_value "1" /sys/devices/system/cpu/cpu4/core_ctl/enable
    echo "2" > /sys/devices/system/cpu/cpu4/core_ctl/min_cpus
    # task usually doesn't run on cpu7
    lock_value "1" /sys/devices/system/cpu/cpu7/core_ctl/enable
    echo "0" > /sys/devices/system/cpu/cpu7/core_ctl/min_cpus
}

apply_performance()
{
    # 1708 * 0.95 / 1785 = 90.9
    # higher sched_downmigrate to use little cluster more
    echo "90 60" > /proc/sys/kernel/sched_downmigrate
    echo "90 85" > /proc/sys/kernel/sched_upmigrate
    echo "90 60" > /proc/sys/kernel/sched_downmigrate

    # do not use lock_value(), libqti-perfd-client.so will fail to override it
    echo "1" > /dev/stune/top-app/schedtune.sched_boost_enabled
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
    # may be override
    echo "1036800" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
    echo "1401600" > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
    echo "1401600" > /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq

    # easier to boost
    echo "16" > /proc/sys/kernel/sched_min_task_util_for_boost
    echo "16" > /proc/sys/kernel/sched_min_task_util_for_colocation
    echo "40 40" > /proc/sys/kernel/sched_downmigrate
    echo "40 60" > /proc/sys/kernel/sched_upmigrate
    echo "40 40" > /proc/sys/kernel/sched_downmigrate

    # do not use lock_value(), libqti-perfd-client.so will fail to override it
    echo "1" > /dev/stune/top-app/schedtune.sched_boost_enabled
    echo "20" > /dev/stune/top-app/schedtune.boost
    echo "1" > /dev/stune/top-app/schedtune.prefer_idle

    lock_value "0:0 4:1804800 7:1612800" /sys/module/cpu_boost/parameters/input_boost_freq
    lock_value "2000" /sys/module/cpu_boost/parameters/input_boost_ms
    lock_value "1" /sys/module/cpu_boost/parameters/sched_boost_on_input

    # turn off core_ctl to reduce latency
    lock_value "0" /sys/devices/system/cpu/cpu4/core_ctl/enable
    echo "3" > /sys/devices/system/cpu/cpu4/core_ctl/min_cpus
    # turn off core_ctl to reduce latency
    lock_value "0" /sys/devices/system/cpu/cpu7/core_ctl/enable
    echo "1" > /sys/devices/system/cpu/cpu7/core_ctl/min_cpus
}

# $1: power_mode
apply_power_mode()
{
    case "${1}" in
    "powersave") 
        stop_qti_perfd
        apply_common
        apply_powersave
        update_qti_perfd powersave
        start_qti_perfd
        echo "Applying powersave done."
    ;;
    "balance")
        stop_qti_perfd
        apply_common
        apply_balance
        update_qti_perfd balance
        start_qti_perfd
        echo "Applying balance done."
    ;;
    "performance") 
        stop_qti_perfd
        apply_common
        apply_performance
        update_qti_perfd performance
        start_qti_perfd
        echo "Applying performance done."
    ;;
    "fast") 
        stop_qti_perfd
        apply_common
        apply_fast
        update_qti_perfd fast
        start_qti_perfd
        echo "Applying fast done."
    ;;
    *) 
        action="balance"
        stop_qti_perfd
        apply_common
        apply_balance
        update_qti_perfd balance
        start_qti_perfd
        echo "Applying balance done."
    ;;
    esac
}

# suppress stderr
(

echo ""

# we doesn't have the permission to rw "/sdcard" before the user unlocks the screen
while [ ! -e ${panel_path} ] 
do
    touch ${panel_path}
    sleep 2
done

if [ ! -n "$action" ]; then
    # default option is balance
    action="balance"
    # load default mode from file
    default_action=`read_cfg_value default_mode`
    if [ "${default_action}" != "" ]; then
        action=${default_action}
    fi
fi

# perform hotfix
apply_power_mode ${action}

# save mode for automatic applying mode after reboot
echo ""                                                     >  ${panel_path}
echo "sdm855-tune https://github.com/yc9559/sdm855-tune/"   >> ${panel_path}
echo "Author:   Matt Yang"                                  >> ${panel_path}
echo "Platform: sdm855"                                     >> ${panel_path}
echo "Version:  20190712"                                   >> ${panel_path}
echo ""                                                     >> ${panel_path}
echo "[status]"                                             >> ${panel_path}
echo "Power mode:     ${action}"                            >> ${panel_path}
echo "Last performed: `date '+%Y-%m-%d %H:%M:%S'`"          >> ${panel_path}
echo ""                                                     >> ${panel_path}
echo "[settings]"                                           >> ${panel_path}
echo "# Available mode: balance powersave performance fast" >> ${panel_path}
echo "default_mode=${action}"                               >> ${panel_path}

echo "${panel_path} has been updated."

echo ""

# suppress stderr
) 2> /dev/null

exit 0
