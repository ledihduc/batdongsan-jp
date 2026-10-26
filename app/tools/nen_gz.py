#!/usr/bin/env python3
"""Nén sẵn build/web cho nginx `gzip_static` VÀ `brotli_static`.

CHẠY SAU MỖI `flutter build web`. Bỏ qua bước này thì nginx phục vụ bản .gz/.br
của lần build TRƯỚC.

Sinh cả `.gz` lẫn `.br`. Brotli nhỏ hơn gzip ~20% trên JS — với `main.dart.js`
là 1,6MB → ~1,25MB, tiết kiệm ~350KB trên đúng tệp nằm trên đường găng trước
khi vẽ được khung hình đầu. Trình duyệt nào không nhận brotli thì nginx tự lùi
về .gz, nên giữ CẢ HAI.

Hai cái bẫy đã trả giá bằng việc /map và /planning chết trắng trên staging:

1. **Bỏ qua tệp nhỏ.** Bản đầu chỉ nén tệp >= 1KB. Một chunk deferred co lại
   dưới 1KB ở lần build sau thì .gz CŨ của nó vẫn nằm đó, và `gzip_static`
   vẫn phục vụ .gz đó — trình duyệt nhận JS của bản build khác, `loadLibrary()`
   ném DeferredLoadException, route hiện "Không tải được trang". Không có
   request nào 4xx nên nhìn log mạng không thấy gì.
   → Nay nén MỌI tệp hợp lệ, không có ngưỡng.

2. **.gz mồ côi.** Tệp nguồn biến mất giữa hai lần build (chunk bị đánh số
   lại) nhưng .gz ở lại. → Nay xoá sạch .gz trước khi nén lại.
"""

import gzip
import pathlib
import sys

try:
    import brotli  # type: ignore
except ImportError:  # pragma: no cover - môi trường chưa cài
    brotli = None

DUOI = ('.js', '.json', '.ttf', '.otf', '.css', '.wasm', '.svg', '.html')
goc = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else 'build/web')

# Xoá SẠCH bản nén cũ trước — xem bẫy "mồ côi" ở đầu tệp. Áp dụng cho cả .br.
xoa = 0
for duoi_nen in ('*.gz', '*.br'):
    for f in goc.rglob(duoi_nen):
        f.unlink()
        xoa += 1

nen = br = 0
tho = gz_tong = br_tong = 0
for f in goc.rglob('*'):
    if not (f.is_file() and f.suffix in DUOI):
        continue
    raw = f.read_bytes()
    tho += len(raw)
    with gzip.open(str(f) + '.gz', 'wb', compresslevel=9) as o:
        o.write(raw)
    gz_tong += (f.parent / (f.name + '.gz')).stat().st_size
    nen += 1
    if brotli is not None:
        # quality 11 = mức cao nhất. Chậm khi nén nhưng chỉ chạy lúc build, còn
        # cái tiết kiệm được thì mọi người dùng đều hưởng.
        (f.parent / (f.name + '.br')).write_bytes(brotli.compress(raw, quality=11))
        br_tong += (f.parent / (f.name + '.br')).stat().st_size
        br += 1

def mb(n: int) -> str:
    return f'{n / 1048576:.1f}MB'


print(f'xoá {xoa} bản nén cũ · gz {nen} tệp · br {br} tệp')
dong = f'thô {mb(tho)} → gz {mb(gz_tong)}'
if brotli is not None:
    dong += f' → br {mb(br_tong)}'
print(dong)
if brotli is None:
    print('!! CHƯA CÀI gói brotli — chỉ sinh .gz. Cài: pip install brotli')
