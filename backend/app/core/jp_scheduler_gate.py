"""Cổng bật cron APScheduler của thị trường JP (D9).

Tách thành hàm thuần để test được mà không import `main` (import `main` chạy seed + cần DB).
"""


def should_start_jp_scheduler(region: str, enabled: bool) -> bool:
    """D9: cron JP chỉ chạy khi region jp VÀ bật cờ `jp_scheduler_enabled`."""
    return region.lower() == "jp" and enabled
