/// xEdu 应用级常量。
library;

import 'package:flutter/material.dart' show Color;

const String kAppName = 'xEdu';
const String kAppTagline = '跨平台在线学习 · 平板 / 手机';
const String kVersion = '0.1.0';

// SharedPreferences 存储键
const String kUsersKey = 'xedu_users'; // email -> {id,name,password}
const String kSessionKey = 'xedu_session'; // 当前登录用户
const String kSeenOnboardingKey = 'xedu_seen_onboarding';
const String kDarkModeKey = 'xedu_dark';
const String kRemindKey = 'xedu_remind_lesson';

/// 每个用户的个人学习数据都保存在单独的 key 下。
String studyKeyFor(String uid) => 'xedu_study_$uid';

/// 每个用户的「看图找规律」做题记录（错题 / 分类统计）单独保存。
String patternStatsKeyFor(String uid) => 'xedu_pattern_$uid';

/// 「看视频」视频库：分类 + 视频。全机共用一份（家长加片，孩子看）。
const String kVideoLibraryKey = 'xedu_video_lib';

// 底部选项卡下标
const int kQuizTab = 0;
const int kQaTab = 1;
const int kVideoTab = 2;
const int kCourseTab = 3;
const int kProgressTab = 4;
const int kProfileTab = 5;

/// 当前开放的选项卡：看图找规律 / 看图问答 / 看视频 / 我的；
/// 课程与进度只见其形、点不进去。
const Set<int> kOpenTabs = {kQuizTab, kQaTab, kVideoTab, kProfileTab};

/// 「看图问答」的朗读语速（倍速，1.0 为原速）。
const String kQaSpeechRateKey = 'xedu_qa_speech_rate';

// 课程封面渐变调色板（seed 取模得到稳定配色）
const List<List<Color>> kCoverPalette = [
  [Color(0xFF4F6BFF), Color(0xFF9A5CFF)], // 靛紫
  [Color(0xFF00B8A9), Color(0xFF0F8B8D)], // 青绿
  [Color(0xFFFF7043), Color(0xFFFF3D6E)], // 橙红
  [Color(0xFF7E57C2), Color(0xFF4A148C)], // 深紫
  [Color(0xFF26A69A), Color(0xFF00897B)], // 绿松
  [Color(0xFFFFA726), Color(0xFFF57C00)], // 琥珀
  [Color(0xFF42A5F5), Color(0xFF1565C0)], // 天蓝
  [Color(0xFFEC407A), Color(0xFFAD1457)], // 玫红
];
