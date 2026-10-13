#!/usr/bin/env bash
#
# สร้างไฟล์ขึ้นสโตร์ (ipa / appbundle) แล้ว "ตรวจของจริง" ว่าค่าคอนฟิกถูกฝัง
# เข้าไปในไบนารีถูกต้อง
#
# ทำไมต้องมีสคริปต์นี้: build 1.12.0+41 ถูกสร้างด้วยคำสั่งหลายบรรทัดที่ `\`
# ท้ายบรรทัดหายไป ทั้งก้อนที่เหลือเลยกลายเป็นค่าเดียวของ API_BASE_URL
# (`https://luilaykhao.com/api/v1 --dart-define=REVERB_APP_KEY=...`) แอปที่
# ปล่อยออกไปเลยยิง API ไม่ออกสักเส้น ทั้งที่ตอน `flutter run` ทุกอย่างปกติ
# ต่อไปนี้ค่าอ่านจาก dart_defines/prod.json ไฟล์เดียว ไม่ต้องพิมพ์มือ
#
#   ./scripts/build-release.sh            # ทั้ง ipa และ appbundle
#   ./scripts/build-release.sh ipa
#   ./scripts/build-release.sh appbundle
#
set -euo pipefail

cd "$(dirname "$0")/.."

DEFINES_FILE="dart_defines/prod.json"
# คีย์ที่ห้ามขึ้น git (gitignored) — อ่านคู่กับ prod.json ตอน build
SECRETS_FILE="dart_defines/secrets.json"
TARGET="${1:-all}"

EXPECTED_BASE_URL="$(
  python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['API_BASE_URL'])" "$DEFINES_FILE"
)"

echo "==> ใช้ค่าจาก $DEFINES_FILE (API_BASE_URL=$EXPECTED_BASE_URL)"

# เวอร์ชันที่ไฟล์ที่ได้ต้องเป็น — อ่านจาก pubspec ("1.15.0+49")
PUBSPEC_VERSION="$(sed -n 's/^version: *//p' pubspec.yaml | tr -d '[:space:]')"
EXPECTED_NAME="${PUBSPEC_VERSION%%+*}"
EXPECTED_CODE="${PUBSPEC_VERSION##*+}"
echo "==> เวอร์ชันใน pubspec: $EXPECTED_NAME ($EXPECTED_CODE)"

# ไม่มีคีย์ CARTO = แผนที่ flutter_map ทุกจอกลายเป็นลายน้ำ "API KEY REQUIRED"
# (CARTO เริ่มบังคับคีย์ ก.ย. 2026) — หยุดตั้งแต่ก่อน build ดีกว่าไปเจอในสโตร์
if [ "$TARGET" != "verify" ]; then
  CARTO_KEY="$(
    python3 -c "import json,os,sys; p=sys.argv[1]; print(json.load(open(p)).get('CARTO_API_KEY', '') if os.path.exists(p) else '')" "$SECRETS_FILE"
  )"
  if [ -z "$CARTO_KEY" ]; then
    echo "!! ไม่มี CARTO_API_KEY ใน $SECRETS_FILE — แผนที่จะขึ้น 'API KEY REQUIRED'" >&2
    echo '   สร้างไฟล์เป็น {"CARTO_API_KEY": "<คีย์>"} (ไฟล์นี้ไม่ขึ้น git)' >&2
    exit 1
  fi
fi

# ตรวจ AOT snapshot ว่ามีสตริง base URL ตรงเป๊ะ และไม่มีเศษคำสั่ง build หลุดเข้าไป
verify_snapshot() {
  local label="$1" binary="$2"

  if [ ! -f "$binary" ]; then
    echo "!! ตรวจ $label ไม่ได้: ไม่พบ $binary" >&2
    exit 1
  fi

  # ดัมป์ลงไฟล์ก่อนค่อย grep — ถ้าต่อไปป์ตรง ๆ `grep -q` จะปิดไปป์ทันทีที่เจอ
  # strings โดน SIGPIPE แล้ว `set -o pipefail` จะรายงานว่าทั้งไปป์ไลน์ล้มเหลว
  # ทั้งที่ "เจอ" คือผลลัพธ์ที่เราต้องการ
  local dump
  dump="$(mktemp)"
  strings -a "$binary" > "$dump"

  if grep -q -- '--dart-define' "$dump"; then
    rm -f "$dump"
    echo "!! $label: เจอสตริง '--dart-define' ฝังอยู่ในไบนารี" >&2
    echo "   แปลว่าค่า define ถูกกลืนรวมเป็นค่าเดียว — อย่าส่งไฟล์นี้ขึ้นสโตร์" >&2
    exit 1
  fi

  if ! grep -qx -- "$EXPECTED_BASE_URL" "$dump"; then
    rm -f "$dump"
    echo "!! $label: ไม่พบ '$EXPECTED_BASE_URL' แบบตรงเป๊ะในไบนารี" >&2
    exit 1
  fi

  rm -f "$dump"

  echo "==> ตรวจ $label ผ่าน"
}

verify_ipa() {
  local ipa work app plist name code
  ipa="build/ios/ipa/Luilaykhao.ipa"
  if [ ! -f "$ipa" ]; then
    echo "!! ไม่พบ $ipa — export จาก archive ไม่สำเร็จ ดู error ของ flutter ด้านบน" >&2
    echo "   (เคยเจอ 'PLA Update available' = ต้องกดยอมรับข้อตกลงใหม่ที่ developer.apple.com" >&2
    echo "    ด้วยบัญชี Account Holder ก่อน Xcode ถึงจะเซ็นแบบ Distribution ได้)" >&2
    exit 1
  fi
  work="$(mktemp -d)"
  unzip -q -o "$ipa" 'Payload/*/Frameworks/App.framework/App' 'Payload/*/Info.plist' -d "$work"
  app="$(find "$work" -path '*App.framework/App' -type f)"
  verify_snapshot "ipa ($ipa)" "$app"

  # ไฟล์ต้องเป็นรุ่นที่เพิ่ง build ไม่ใช่ของค้างจากรอบก่อน
  plist="$(find "$work" -maxdepth 3 -path '*/Payload/*.app/Info.plist' -type f)"
  name="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$plist")"
  code="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$plist")"
  rm -rf "$work"
  if [ "$name" != "$EXPECTED_NAME" ] || [ "$code" != "$EXPECTED_CODE" ]; then
    echo "!! ipa เป็นเวอร์ชัน $name ($code) แต่ pubspec คือ $EXPECTED_NAME ($EXPECTED_CODE)" >&2
    exit 1
  fi
  echo "==> ipa เป็นเวอร์ชัน $name ($code) ตรงกับ pubspec"
}

verify_appbundle() {
  local aab work
  aab="build/app/outputs/bundle/release/app-release.aab"
  work="$(mktemp -d)"
  if [ ! -f "$aab" ]; then
    echo "!! ไม่พบ $aab — ดู error ของ flutter ด้านบน" >&2
    exit 1
  fi
  unzip -q -o "$aab" 'base/lib/arm64-v8a/libapp.so' 'base/manifest/AndroidManifest.xml' -d "$work"
  verify_snapshot "appbundle ($aab)" "$work/base/lib/arm64-v8a/libapp.so"
  # manifest ใน aab เป็น protobuf — versionName เก็บเป็นสตริงอ่านได้ด้วย strings
  # (ดัมป์ลงไฟล์ก่อน ด้วยเหตุผลเรื่อง SIGPIPE เดียวกับ verify_snapshot)
  strings -a "$work/base/manifest/AndroidManifest.xml" > "$work/manifest.txt"
  if ! grep -qF -- "$EXPECTED_NAME" "$work/manifest.txt"; then
    rm -rf "$work"
    echo "!! appbundle ไม่ใช่เวอร์ชัน $EXPECTED_NAME ตาม pubspec" >&2
    exit 1
  fi
  rm -rf "$work"
  echo "==> appbundle เป็นเวอร์ชัน $EXPECTED_NAME ตรงกับ pubspec"
}

build_ipa() {
  echo "==> flutter build ipa"
  # ลบของเก่าก่อน — flutter จบด้วย exit 0 แม้ export ipa ไม่สำเร็จ แล้วไฟล์เก่า
  # ที่ค้างอยู่จะถูกตรวจแทนและผ่าน (1.15.0 เกือบส่ง ipa ของ 1.14.0 ไปแล้ว)
  rm -f build/ios/ipa/*.ipa
  flutter build ipa --release --dart-define-from-file="$DEFINES_FILE" \
    --dart-define-from-file="$SECRETS_FILE"
  verify_ipa
}

build_appbundle() {
  echo "==> flutter build appbundle"
  rm -f build/app/outputs/bundle/release/app-release.aab
  flutter build appbundle --release --dart-define-from-file="$DEFINES_FILE" \
    --dart-define-from-file="$SECRETS_FILE"
  verify_appbundle
}

case "$TARGET" in
  ipa) build_ipa ;;
  appbundle|aab) build_appbundle ;;
  all) build_ipa; build_appbundle ;;
  # ตรวจไฟล์ที่ build ไว้แล้วโดยไม่ build ใหม่
  verify) verify_ipa; verify_appbundle ;;
  *) echo "ใช้: $0 [ipa|appbundle|all|verify]" >&2; exit 2 ;;
esac

echo "==> เสร็จแล้ว พร้อมส่งขึ้นสโตร์"
