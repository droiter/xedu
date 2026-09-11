# xEdu · 跨平台教育应用

基于 **Flutter** 的在线教育软件，面向 **平板与手机**，一套代码同时适配 Android / iOS。

![flutter](https://img.shields.io/badge/Flutter-3.x-blue)
![license](https://img.shields.io/badge/license-MIT-lightgrey)

---

## 一、项目简介

xEdu 是一个可直接运行的「在线课程学习」App 骨架与示例实现，覆盖以下完整闭环：

- 引导页 → 注册 / 登录（本地账号，数据存于本机）
- 课程广场：搜索、分类筛选、手机列表 / 平板宫格自适应
- 课程详情：报名、章节目录、学习进度、平板双栏布局
- 课时学习：图文讲义 + **在线视频** + **随堂测验**（即时判分与解析）
- 学习统计：连续打卡、今日时长、累计时长、完成课时
- 个性化：深色模式、学习提醒开关、账号退出

## 二、快速开始

> 本仓库为 **纯 Dart/Flutter 源码**（未附带 Android/iOS 原生工程目录），
> 首次运行需先生成平台工程，一次性操作即可。

**1. 安装 Flutter（≥ 3.24 建议使用最新稳定版）**

见官方文档：<https://docs.flutter.dev/get-started/install>，并完成
`flutter doctor` 检查。

**2. 生成平台工程并运行**

```bash
cd xedu
flutter create --org com.xedu --project-name xedu .   # 生成 android/ ios/ 等
flutter pub get
flutter run       # 选择连接的手机 / 平板 / 模拟器
```

**3. 运行测试与静态检查**

```bash
flutter analyze
flutter test
```

**4.（可选）打包安卓 APK（产物 `build/app/outputs/flutter-apk/app-release.apk`）**

```bash
cd xedu
bash scripts/build_apk.sh
```

脚本会自动完成：生成缺失的 `android/` 平台工程 → 给 main 清单补
`INTERNET` 权限（在线视频在 release 包必需，Flutter 模板默认只给 debug
包加了）→ `pub get` → `flutter build apk --release`，全程一键。

Windows 没有 bash 时，按序手敲等价的四条即可：

```bat
flutter create --platforms=android --org com.xedu --project-name xedu .
flutter pub get
flutter build apk --release
```

说明：

- 生成的 release APK 默认用**调试签名**，直接传到手机 / 平板侧载安装即可；
  若要上应用商店，后续再配置正式 keystore（`build.gradle.kts` 的 signingConfigs）。
- 只想快速自测、不在乎包体大小时，可改用 `flutter build apk --debug`。
- 应用图标目前为 Flutter 默认图标；如需自定义，替换
  `android/app/src/main/res/mipmap-*/ic_launcher.png`。

## 三、功能清单

| 模块 | 说明 |
| --- | --- |
| 引导页 | 3 页轮播，可跳过，状态持久化 |
| 账号 | 本地注册 / 登录 / 退出，自动恢复会话 |
| 首页 | 问候、继续学习、本周精选 Banner、为你推荐 |
| 课程广场 | 关键词搜索 + 分类筛选，宽屏自动切换宫格 |
| 课程详情 | 报名解锁课时、章节目录、学习进度、平板左右分栏 |
| 课时页 | 讲义渲染、在线视频播放、标记完成、自动进入下一节 |
| 随堂测验 | 单选即时反馈 + 答案解析 + 最高分记录 |
| 看图找规律 | 首页入口：4 格规律图挖空一格的题库闯关。每局随机 10 题；答对自动进入下一题（音效 + 震动 + 炫光），答错重排并替换干扰项可重试，通关撒花 |
| 学习进度 | 连续天数 / 今日与累计时长 / 完成课时 / 在学课程 |
| 个人中心 | 深色模式、提醒开关、关于、退出登录 |
| 自适应 | 手机（≤699dp 单列列表）与平板（≥700dp 宫格 / 分栏）两套布局 |

## 四、项目结构

```
lib/
├─ main.dart                    # 入口：注入 SharedPreferences 后启动
├─ app.dart                     # MaterialApp + 登录态路由分发
├─ core/                        # 常量、主题、日期与时长工具
├─ data/
│  └─ models.dart               # 课程 / 章节 / 课时 / 测验 数据模型
├─ state/                       # Riverpod providers（认证 / 学习进度 / 目录 / 主题）
├─ shared/
│  ├─ progress_utils.dart       # “下一节 / 第一个未完成课时”等进度算法
│  └─ widgets/                  # 课程卡片、讲义渲染、章节标题、空态
└─ features/                    # 按业务拆分的页面
    ├─ onboarding/  auth/  shell/
    ├─ home/  catalog/  course/
    ├─ lesson/  quiz/
    ├─ pattern_quiz/            # 「看图找规律」（models + bank + screen + celebration + sfx）
    └─ progress/  profile/
assets/data/courses.json        # 演示课程目录（新增课程只需改这里）
assets/audio/quiz_*.wav         # 答题音效（脚本合成，见下文）
scripts/gen_quiz_sounds.py      # 重新生成上面的音效
```

## 五、数据说明（接入后端前）

当前为**纯本地演示**，没有服务端：

| 内容 | 位置 |
| --- | --- |
| 课程目录 | `assets/data/courses.json`，启动时加载，改文件即可增删课程 |
| 账号 | 保存在 SharedPreferences（`xedu_users` / `xedu_session`） |
| 学习进度 | 按用户保存在 SharedPreferences（`xedu_study_<uid>`） |

视频课时为在线示例视频；断网时课时页会显示兜底占位。

「看图找规律」题库在 `lib/features/pattern_quiz/pattern_quiz_bank.dart`，
每道题由 4 格图 + 干扰项池组成；元素默认用 Flutter 内置圆点 / emoji / 色块
渲染（无需图片资源）。换真实图片时，把题目里的元素换成 `Pic.asset(path)`
并把文件声明到 `pubspec.yaml` 的 `assets:` 即可。

题库按 `PatternAgeGroup` 分 5 档：2–3 岁（40 题）/ 3–4 岁（46 题）/
5–6 岁（43 题）/ 7–8 岁（41 题）/ 9–10 岁（41 题），共 211 题，每档都够抽 30 局以上不重样。
题型参考常见 IQ / 图形推理测试的规律类别：交替、循环、数量增减、大小、深浅、
方向旋转、数列（等差 / 等比 / 平方 / 立方 / 质数 / 交错 / 复合递推 / 对称）、
图形旋转、数量与颜色二维规律，以及「数字 ↔ 数量 / 骰子 / 图形个数」配对。
进入时**可多选年龄段**，`patternBankForAges()` 会把选中的题库合并出题，
再由 `PatternQuizScreen.sessionSize`（默认 10）随机抽题，**每局只做 10 题**。

答题反馈：答对播放 `assets/audio/quiz_*.wav`（由 `scripts/gen_quiz_sounds.py` 合成，
`flutter pub run` 之外无需额外素材）、触发震动并弹出炫光爆发，短暂停留后自动进入下一题；
答错轻音提示并重排备选。成绩按**一次答对**的题数计算，通关页有撒花与星级动画。
音效播放失败会自动静音降级，不影响答题。

**主要扩展点**
- `lib/state/auth.dart`：把假认证换成真实登录接口
- `lib/state/catalog.dart`：把 `courses.json` 换成后端课程列表 API
- `lib/state/study.dart`：把进度持久化换成云端同步
- 课程封面色 `kCoverPalette`、分类图标见 `lib/core/constants.dart` 与
  `lib/shared/widgets/course_card.dart`

## 六、测试

```bash
flutter test
```

- `models_test.dart`：课程 JSON 解析与进度算法
- `study_flow_test.dart`：注册 / 登录 / 学习进度 / 测验最高分（持久化）
- `app_smoke_test.dart`：引导 → 登录 → 注册 → 进入主界面的冒烟测试
- `pattern_quiz_bank_test.dart`：规律题库数据一致性（4 格 / 干扰项 / id 唯一 / 合并题库）
- `pattern_quiz_widget_test.dart`：元素渲染 + 年龄多选与答题流程

## 七、Roadmap 建议

- [ ] 接入真实账号与课程 API
- [ ] 学习提醒本地通知（`flutter_local_notifications`）
- [ ] 下载离线视频与课程收藏
- [ ] 讲师端内容管理
- [ ] Web / 桌面端构建验证
