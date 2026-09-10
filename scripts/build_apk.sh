#!/usr/bin/env bash
# 一键生成安卓 APK（需本机已装好 Flutter，见 README「APK 打包」节）
# 用法:  bash scripts/build_apk.sh
#   - android/ 缺失时先用 flutter create 按你本机 Flutter 版本生成平台工程（与 SDK 版本严格匹配，安全）
#   - 自动往 main AndroidManifest 补 INTERNET 权限（在线视频在 release 包必需；模板只给 debug 包加了它）
#   - flutter pub get -> flutter build apk --release
# 产物: build/app/outputs/flutter-apk/app-release.apk
set -euo pipefail
cd "$(dirname "$0")/.."   # 定位到 xedu 项目根

if ! command -v flutter >/dev/null 2>&1; then
  echo "[错误] 未找到 flutter 命令。请先安装 Flutter 并加入 PATH（见 README「快速开始」）。" >&2
  exit 1
fi

echo "==> Flutter 版本: $(flutter --version 2>/dev/null | head -1)"

if [ ! -d android ]; then
  echo "==> android/ 不存在，用 flutter create 生成（org: com.xedu, 名称: xedu）..."
  flutter create --platforms=android --org com.xedu --project-name xedu .
  # 删掉脚手架自带的示例测试，避免引用不存在的 MyApp
  [ -f test/widget_test.dart ] && rm -f test/widget_test.dart
else
  echo "==> android/ 已存在，跳过 flutter create"
fi

MANIFEST="android/app/src/main/AndroidManifest.xml"
if [ -f "$MANIFEST" ]; then
  if grep -q 'android.permission.INTERNET' "$MANIFEST"; then
    echo "==> INTERNET 权限已在清单中"
  else
    echo "==> 向 main AndroidManifest 补 INTERNET 权限（在线视频 release 必需）..."
    # 在 <application> 之前插入 <uses-permission>
    python3 - "$MANIFEST" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
line = '<uses-permission android:name="android.permission.INTERNET"/>'
if 'android.permission.INTERNET' in s:
    sys.exit(0)
ind = '\n    <application'
if ind in s:
    s = s.replace(ind, '\n    ' + line + ind, 1)
elif '<application' in s:
    s = s.replace('<application', line + '\n    <application', 1)
open(p, "w", encoding="utf-8").write(s)
PY
    echo "==> 已补好:"
    grep -n 'uses-permission' "$MANIFEST" || true
  fi
else
  echo "[警告] 未找到 $MANIFEST，请人工确认安卓清单。" >&2
fi

echo "==> 拉取依赖 (pub get) ..."
flutter pub get

echo "==> 编译 release APK（首次会较久）..."
flutter build apk --release

echo
echo "==== 完成，产物如下 ===="
ls -lh build/app/outputs/flutter-apk/*.apk
echo
echo "把上面的 app-release.apk 传到手机/平板安装即可（release 默认用调试签名，可侧载）。"
