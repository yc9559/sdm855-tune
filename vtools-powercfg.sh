#!/system/bin/sh
# sdm855-tune https://github.com/yc9559/sdm855-tune/
# Author: Matt Yang
# Platform: sdm855

# powercfg wrapper for com.omarea.vtools
# MAKE SURE THAT THE MAGISK MODULE OF sdm855-tune HAS BEEN INSTALLED

powercfg_path="/vendor/bin/powercfg.sh"

# suppress stderr
(

action=$1
# default option is balance
if [ ! -n "$action" ]; then
    action="balance"
fi

if [ ! -f ${powercfg_path} ]; then
    exit 1
fi

if [ "$action" = "powersave" ]; then
    sh ${powercfg_path} powersave
fi

if [ "$action" = "balance" ]; then
    sh ${powercfg_path} balance
fi

if [ "$action" = "performance" ]; then
    sh ${powercfg_path} performance
fi

if [ "$action" = "fast" ]; then
    sh ${powercfg_path} fast
fi

# suppress stderr
) 2>/dev/null

exit 0
