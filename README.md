# RunAbroadLocal（润学导航 · 纯本地版）

把 [RadishXN/run-abroad](https://github.com/RadishXN/run-abroad)（润学导航）整个站点打包进一个 iOS App 的 WKWebView 壳，**完全离线运行**，无任何网络请求。

- 填 10 项基本信息，从 171 条签证 / 移民路径（51 个国家地区）里筛出适合你的，并告诉你还差什么
- 数据来源：上游仓库 main 分支（2026-10 快照）
- 外链（各路径官网）点击后跳系统 Safari 打开

## 构建产物
- GitHub Actions（macos-15 + XcodeGen）→ 未签名 IPA → Sideloadly 签名安装
- App 名称：润学导航，bundle id `com.minis.runabroadlocal`，v1.0(1)

## 结构
```
Sources/App.swift          # WKWebView 壳（外链跳 Safari）
www/                       # 上游站点原样拷贝（folder reference 打进 bundle）
Support/                   # Info.plist + AppIcon
.github/workflows/build-ipa.yml
```
