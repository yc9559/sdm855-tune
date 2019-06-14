#!/system/bin/sh
# sdm855-tune https://github.com/yc9559/sdm855-tune/
# Author: Matt Yang
# Platform: sdm855

# powercfg wrapper for com.omarea.vtools
# MAKE SURE THAT THE MAGISK MODULE OF sdm855-tune HAS BEEN INSTALLED

powercfg_path="/vendor/bin/powercfg.sh"

# suppress stderr
(

sh ${powercfg_path} $1

# suppress stderr
) 2>/dev/null

exit 0
