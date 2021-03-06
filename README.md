# sdm855-tune

在过去的[Project WIPE](https://github.com/yc9559/cpufreq-interactive-opt)中，借助仿真和启发式优化算法自动调参`interactive`参数，实现了对所有主流机型的适配。在近期的[wipe v2](https://github.com/yc9559/wipe-v2)中，改进了仿真支持了内核的更多特性以及重点满足渲染性能需求，自动调参`interactive`+`HMP`+`input boost`参数，显著改进了流畅度。但是在EAS合入主线之后，自动调参依赖的仿真难度变大，很难仿真调度器所有主体的逻辑，此外，EAS在设计之初就为了避免调参，因此例如`schedutil`的调参没有明显效果。  

在[wipe v2](https://github.com/yc9559/wipe-v2)中，重点满足与手机交互时的性能需求，而降低非交互式的卡顿权重，使得在流畅性和省电的权衡上更近一步。而`QTI Boost Framework`，这个此前在应用调参前要求先禁用的模块，因为它根据当前事件动态覆盖参数，导致冲突。基于这一点，此项目借助`QTI Boost Framework`，扩展了它能更改参数的范围，在APP启动和滑动屏幕时，动态应用较为激进的参数，在可接受的功耗代价下改善响应，在没有交互时，使用保守的参数，尽可能利用小核集群，并在重负载时运行在能效比更优的频点。  

具体的调整和解释见[历史commit信息](https://github.com/yc9559/sdm855-tune/commits/master)  

## 模式区别

- 卡顿：基础1.6+2.0，UI交互1.8+0.8，突发2.0+2.6，最低0.3+0.7+0.8，低基础频率低动态频率，但是基本不影响APP启动时间
- 均衡：基础1.8+2.4，UI交互2.0+2.4，突发2.4+2.7，最低0.5+0.7+0.8，低基础频率高动态频率
- 费电：基础2.4+2.7，UI交互2.4+2.8，突发2.4+2.8，最低0.5+0.7+0.8，基本不做频率限制，2.8g相比2.7g，性能+3.5%功耗+13.6%
- 低延：基础2.0+2.6，UI交互2.4+2.8，突发2.4+2.8，最低1.0+1.4+1.4，压缩频率变化范围，散热允许TDP下的稳定持续性能

## 如何使用

### 环境要求

1. 高通骁龙855(SM8150)平台
2. 已ROOT
3. Magisk >= 17.0
4. 自动化切换辅助APP(可选)
   - 微工具箱
   - Tasker
   - Edge
   - ...

### 静态配置步骤(不需要根据前台APP自动切换)

1. 在[Release页面](https://github.com/yc9559/sdm855-tune/releases)下载magisk模块
2. 在Magisk Manager内刷入
3. 重启
4. 修改`/sdcard/powercfg_panel.txt`的内容来选择开机后默认设置的模式，可选的字段有`balance`，`powersave`，`performance`，`fast`
5. 重启

### 动态配置步骤(微工具箱)

1. 在[Release页面](https://github.com/yc9559/sdm855-tune/releases)下载magisk模块
2. 在Magisk Manager内刷入
3. 重启
4. 在[Release页面](https://github.com/yc9559/sdm855-tune/releases)下载`vtools-powercfg.sh`
5. 在微工具箱内，导入本地配置，选择`vtools-powercfg.sh`
6. 在微工具箱内，选择APP的默认配置

### 动态配置步骤(Tasker等)

1. 在[Release页面](https://github.com/yc9559/sdm855-tune/releases)下载magisk模块
2. 在Magisk Manager内刷入
3. 重启
4. 在Tasker等APP内，添加动作，执行命令`/vendor/bin/sh /vendor/bin/powercfg.sh balance`，其中balance替换为你需要的模式
5. 在Tasker等APP内，把动作绑定到如顶部下拉菜单开关或者滑动手势等事件

### 检查是否生效

打开`/sdcard/powercfg_panel.txt`，内容为如下形式：  
```
sdm855-tune https://github.com/yc9559/sdm855-tune/
Author:   Matt Yang
Platform: sdm855
Version:  20190712

[status]
Power mode:     balance
Last performed: 2019-06-28 15:13:12

[settings]
# Available mode: balance powersave performance fast
default_mode=balance

```

`[status]`是最近一次执行的时间和结果，如果跟最近一次开机时间或者最近一次切换时间接近，则表示已生效  
修改`default_mode`来选择下次执行的默认设置，注意执行`/vendor/bin/sh /vendor/bin/powercfg.sh fast`也会把`default_mode`设置为`fast`  
