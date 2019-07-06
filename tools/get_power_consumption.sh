#! /vendor/bin/sh
# 由于Oneplus 7 Pro未接电源时电流刷新周期为30s，此测试需要连接电脑USB完成
# 需要ROOT权限执行

nr_seconds=$1

for i in `seq ${nr_seconds}`
do
    current=`cat /sys/class/power_supply/battery/current_now`
    voltage=`cat /sys/class/power_supply/battery/voltage_now`
    power=`expr ${voltage} / 1000000 \* ${current} / 1000`
    echo "${voltage},${current},${power}"
    sleep 1
done
