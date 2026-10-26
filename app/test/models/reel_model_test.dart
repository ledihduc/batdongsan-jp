/// Unit test cho model Reel — lớp chuyển JSON → object.
///
/// Đây là chỗ app hay vỡ nhất khi backend đổi payload: một trường thiếu hoặc
/// null lọt vào là màn hình trắng ngay. Lỗi đăng nhập từng gặp ở dự án này
/// (`null is not a subtype of int`) chính là kiểu này.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/reel_model.dart';

Map<String, dynamic> _day({Map<String, dynamic> them = const {}}) => {
      'id': 5,
      'user_id': 9,
      'author_name': 'Chị Hoa',
      'author_avatar': '/uploads/a.jpg',
      'video_url': '/uploads/reel_5.mp4',
      'thumbnail_url': '/uploads/reel_5.jpg',
      'caption': 'Căn hộ view sông',
      'category': 'lease',
      'like_count': 3,
      'view_count': 12,
      'comment_count': 4,
      'liked_by_me': true,
      'created_at': '2026-07-18T10:00:00',
      ...them,
    };

void main() {
  group('Reel.fromMap — payload đầy đủ', () {
    test('đọc đúng mọi trường', () {
      final r = Reel.fromMap(_day());
      expect(r.id, 5);
      expect(r.userId, 9);
      expect(r.authorName, 'Chị Hoa');
      expect(r.videoUrl, '/uploads/reel_5.mp4');
      expect(r.caption, 'Căn hộ view sông');
      expect(r.category, 'lease');
      expect(r.likeCount, 3);
      expect(r.viewCount, 12);
      expect(r.commentCount, 4);
      expect(r.likedByMe, isTrue);
      expect(r.createdAt, DateTime.parse('2026-07-18T10:00:00'));
    });
  });

  group('Reel.fromMap — payload THIẾU trường (không được ném lỗi)', () {
    test('thiếu hết trường tuỳ chọn vẫn dựng được object', () {
      final r = Reel.fromMap({'id': 1});
      expect(r.userId, 0);
      expect(r.authorName, 'Người dùng');
      expect(r.authorAvatar, isNull);
      expect(r.videoUrl, '');
      expect(r.thumbnailUrl, isNull);
      expect(r.caption, '');
      expect(r.category, 'all');
      expect(r.likeCount, 0);
      expect(r.viewCount, 0);
      expect(r.commentCount, 0);
      expect(r.likedByMe, isFalse);
      expect(r.createdAt, isNull);
    });

    test('trường null tường minh cũng an toàn', () {
      final r = Reel.fromMap(_day(them: {
        'author_avatar': null,
        'thumbnail_url': null,
        'caption': null,
        'category': null,
        'like_count': null,
        'comment_count': null,
        'liked_by_me': null,
        'created_at': null,
      }));
      expect(r.authorAvatar, isNull);
      expect(r.caption, '');
      expect(r.category, 'all');
      expect(r.likeCount, 0);
      expect(r.commentCount, 0);
      expect(r.likedByMe, isFalse);
      expect(r.createdAt, isNull);
    });

    test('comment_count thiếu → 0, KHÔNG nổ (trường mới thêm ở P2)', () {
      final khong_co = Map<String, dynamic>.from(_day())..remove('comment_count');
      expect(Reel.fromMap(khong_co).commentCount, 0);
    });

    test('created_at rác → null chứ không ném FormatException', () {
      expect(Reel.fromMap(_day(them: {'created_at': 'khong-phai-ngay'})).createdAt,
          isNull);
    });

    test('số gửi dạng double vẫn đọc được', () {
      final r = Reel.fromMap(_day(them: {'like_count': 3.0, 'view_count': 12.0}));
      expect(r.likeCount, 3);
      expect(r.viewCount, 12);
    });
  });

  group('Reel.copyWith', () {
    test('chỉ đổi trường được truyền, giữ nguyên phần còn lại', () {
      final goc = Reel.fromMap(_day());
      final moi = goc.copyWith(likeCount: 99, likedByMe: false);
      expect(moi.likeCount, 99);
      expect(moi.likedByMe, isFalse);
      // giữ nguyên
      expect(moi.id, goc.id);
      expect(moi.caption, goc.caption);
      expect(moi.viewCount, goc.viewCount);
      expect(moi.commentCount, goc.commentCount);
      expect(moi.videoUrl, goc.videoUrl);
    });

    test('không truyền gì thì mọi trường giữ nguyên', () {
      final goc = Reel.fromMap(_day());
      final moi = goc.copyWith();
      expect(moi.likeCount, goc.likeCount);
      expect(moi.likedByMe, goc.likedByMe);
      expect(moi.commentCount, goc.commentCount);
    });

    test('cập nhật commentCount (dùng khi đóng sheet bình luận)', () {
      final goc = Reel.fromMap(_day());
      expect(goc.copyWith(commentCount: 10).commentCount, 10);
    });

    test('bỏ thích rồi thích lại — mô phỏng cập nhật lạc quan trên UI', () {
      var r = Reel.fromMap(_day());
      r = r.copyWith(likedByMe: false, likeCount: r.likeCount - 1);
      expect((r.likedByMe, r.likeCount), (false, 2));
      r = r.copyWith(likedByMe: true, likeCount: r.likeCount + 1);
      expect((r.likedByMe, r.likeCount), (true, 3));
    });
  });
}
