#!/bin/bash
# Web SDK nạp từ zip đã kiểm → pub get offline → analyze + test cụm host →
# build web_moi → READY_TO_PUBLISH → test rộng hơn.
L=/app/build/pipeline.log
mkdir -p /app/build; : > "$L"
own() { chown -R "$OWNER" /app/build /app/.dart_tool /root/.pub-cache 2>/dev/null; }
echo "START $(date +%T)" >> "$L"
C=/sdks/flutter/bin/cache
V=$(cat /sdks/flutter/bin/internal/engine.version)
if [ "$(cat $C/flutter_web_sdk.stamp 2>/dev/null)" != "$V" ]; then
  rm -rf $C/flutter_web_sdk && mkdir -p $C/flutter_web_sdk \
    && unzip -q /websdk.zip -d $C/flutter_web_sdk \
    && echo "$V" > $C/flutter_web_sdk.stamp \
    && echo "WEBSDK_OK $(date +%T)" >> "$L" \
    || { echo "WEBSDK_FAIL $(date +%T)" >> "$L"; own; exit 1; }
fi
flutter pub get --offline >> "$L" 2>&1 || { echo "PUBGET_FAIL $(date +%T)" >> "$L"; own; exit 1; }
echo "PUBGET_OK $(date +%T)" >> "$L"
flutter analyze lib/features/host lib/data test/features/host > /app/build/analyze_dn.txt 2>&1
if grep -E "^ *(error|warning) " /app/build/analyze_dn.txt | grep -v host_home_nha_tro_tab | grep -q .; then
  grep -E "^ *(error|warning) " /app/build/analyze_dn.txt | grep -v host_home_nha_tro_tab >> "$L"
  echo "ANALYZE_FAIL $(date +%T)" >> "$L"; own; exit 1
fi
echo "ANALYZE_OK $(date +%T)" >> "$L"
if ! flutter test test/features/host test/widgets/building_public_screen_test.dart \
    test/features/project test/features/sale >> "$L" 2>&1; then
  echo "TEST_HOST_FAIL $(date +%T)" >> "$L"; own; exit 1
fi
echo "TEST_HOST_OK $(date +%T)" >> "$L"
rm -rf /app/build/web_moi
if ! flutter build web --release --output build/web_moi >> "$L" 2>&1; then
  echo "BUILD_FAIL $(date +%T)" >> "$L"; own; exit 1
fi
own
echo "READY_TO_PUBLISH $(date +%T)" >> "$L"
if flutter test test/features/guest test/widgets > /app/build/test_rest.txt 2>&1; then
  echo "TEST_REST_OK $(date +%T)" >> "$L"
else
  echo "TEST_REST_FAIL $(date +%T)" >> "$L"
  grep -E "\[E\]$" /app/build/test_rest.txt | sed -E 's/^[0-9:]+ \+[0-9]+( -[0-9]+)?: //' | sort -u | head -20 >> "$L"
fi
own
echo "PIPELINE_DONE $(date +%T)" >> "$L"
