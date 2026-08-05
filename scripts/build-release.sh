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
TARGET="${1:-all}"

EXPECTED_BASE_URL="$(
  python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['API_BASE_URL'])" "$DEFINES_FILE"
)"

echo "==> ใช้ค่าจาก $DEFINES_FILE (API_BASE_URL=$EXPECTED_BASE_URL)"

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
  local ipa work app
  ipa="build/ios/ipa/Luilaykhao.ipa"
  work="$(mktemp -d)"
  unzip -q -o "$ipa" 'Payload/*/Frameworks/App.framework/App' -d "$work"
  app="$(find "$work" -path '*App.framework/App' -type f)"
  verify_snapshot "ipa ($ipa)" "$app"
  rm -rf "$work"
}

verify_appbundle() {
  local aab work
  aab="build/app/outputs/bundle/release/app-release.aab"
  work="$(mktemp -d)"
  unzip -q -o "$aab" 'base/lib/arm64-v8a/libapp.so' -d "$work"
  verify_snapshot "appbundle ($aab)" "$work/base/lib/arm64-v8a/libapp.so"
  rm -rf "$work"
}

build_ipa() {
  echo "==> flutter build ipa"
  flutter build ipa --release --dart-define-from-file="$DEFINES_FILE"
  verify_ipa
}

build_appbundle() {
  echo "==> flutter build appbundle"
  flutter build appbundle --release --dart-define-from-file="$DEFINES_FILE"
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
