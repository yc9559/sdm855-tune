#!/system/bin/sh
# Please don't hardcode /magisk/modname/... ; instead, please use $MODDIR/...
# This will make your scripts compatible even if Magisk change its mount point in the future
MODDIR=${0%/*}

sleep 60
/vendor/bin/sh $MODDIR/system/vendor/bin/powercfg.sh
