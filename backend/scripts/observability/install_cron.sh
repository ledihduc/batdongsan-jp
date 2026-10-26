#!/usr/bin/env bash
# install_cron.sh — cài cron chạy pipeline self-heal định kỳ (mặc định 15').
#
# An toàn: pipeline SAFE-BY-DEFAULT. Khi chưa tạo cờ ENABLE_AUTOFIX/ENABLE_AUTODEPLOY,
# cron chỉ PHÁT HIỆN + LƯU BÁO CÁO. Gỡ cron: ./install_cron.sh --uninstall
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INTERVAL_MIN="${INTERVAL_MIN:-15}"
CRON_LOG="${CRON_LOG:-$HERE/../../storage/logs/selfheal_cron.log}"
MARKER="# ancu365-selfheal"
LINE="*/$INTERVAL_MIN * * * * cd $HERE && /usr/bin/env bash $HERE/selfheal.sh >> $CRON_LOG 2>&1 $MARKER"

current="$(crontab -l 2>/dev/null || true)"
cleaned="$(printf '%s\n' "$current" | grep -v "$MARKER" || true)"

if [ "${1:-}" = "--uninstall" ]; then
  printf '%s\n' "$cleaned" | crontab -
  echo "Đã gỡ cron self-heal."
  exit 0
fi

{ printf '%s\n' "$cleaned"; printf '%s\n' "$LINE"; } | crontab -
echo "Đã cài cron: mỗi ${INTERVAL_MIN} phút → $HERE/selfheal.sh"
echo "Log cron: $CRON_LOG"
echo "Trạng thái: SAFE-BY-DEFAULT (chỉ báo cáo cho tới khi bật ENABLE_AUTOFIX)."
