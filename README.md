# FilmMemory 鸿蒙版

FilmMemory（胶片记忆）的 HarmonyOS 原生版本，使用 ArkTS、ArkUI 和 Stage 模型实现，包名为 `com.example.filmmemory`。

## 已实现功能

- 胶卷首页及“全部 / 拍摄中 / 冲洗完”筛选
- 新增、编辑、查看和删除胶卷
- 胶卷状态切换，以及冲洗完成后的照片导入引导
- 系统照片选择器、多图导入、双列图库、全屏预览和删除确认
- 胶卷和照片数据保存在应用本地，不依赖账号或网络
- 暖奶白、白色卡片和柔和绿色的中文界面

## 开发环境

- DevEco Studio 6.1.1
- HarmonyOS SDK API 24（6.1.1）
- 目标设备：HarmonyOS 手机

## 构建

在 `harmony` 目录执行：

```powershell
& 'F:\HuaweiHarmony\DevEco Studio\tools\hvigor\bin\hvigorw.bat' --mode module -p product=default -p module=entry@default -p buildMode=debug assembleHap
```

已签名 HAP 默认生成在：

```text
entry\build\default\outputs\default\entry-default-signed.hap
```

## 真机安装与启动

```powershell
& 'F:\HuaweiHarmony\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe' app install '.\entry\build\default\outputs\default\entry-default-signed.hap'
& 'F:\HuaweiHarmony\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe' shell aa start -a EntryAbility -b com.example.filmmemory
```

签名材料由本机 DevEco Studio 管理，不应复制到仓库或发送给他人。
