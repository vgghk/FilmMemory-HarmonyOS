# 卷迹（FilmMemory）HarmonyOS

卷迹（FilmMemory）的 HarmonyOS 原生版本，使用 ArkTS、ArkUI 和 Stage 模型实现，包名为 `com.example.filmmemory`。它延续 Android 版的本地优先设计：不需要账号或网络，启动后直接进入胶卷首页。

## 已实现功能

- 胶卷首页及“全部 / 拍摄中 / 冲洗完”筛选
- 新增、编辑、查看和删除胶卷
- 胶卷状态切换，以及冲洗完成后的照片导入引导
- 系统照片选择器、多图导入、胶卷条检片、整卷检片、全屏预览和删除确认
- 照片顺序管理：保留导入顺序，并支持按胶卷实际曝光顺序整理
- 胶卷和照片数据保存在应用本地，不依赖账号或网络
- 暖奶白、白色卡片和柔和绿色的中文界面

## 项目结构

```text
entry/src/main/ets/
├── pages/Index.ets       # 主页面、胶卷表单、详情和图库交互
├── model/Roll.ets        # 胶卷数据模型
├── store/FilmStore.ets   # 本地数据保存与读取
├── theme/FilmTheme.ets   # 视觉主题
└── entryability/         # 应用入口
```

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

## 相关版本

- Android 版：https://github.com/vgghk/FilmMemory
- HarmonyOS 版（本仓库）：https://github.com/vgghk/FilmMemory-HarmonyOS
