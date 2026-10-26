/// Test khoá cấu trúc màn khảo sát chào mừng sau khi chia 2 mảng nghiệp vụ.
///
/// Khẳng định: câu hỏi "Bạn muốn làm gì?" tách thành 2 nhóm **Bất động sản** và
/// **Xây dựng**; 4 dịch vụ (Thiết kế/Xây dựng/Nội thất/Công nghiệp) hiện NGAY
/// (không cần chọn chip ý định trước như bản cũ); và KHÔNG còn "Mua nhà đất".
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/features/onboarding/intro_survey_screen.dart';
import 'package:house_booking/l10n/app_localizations.dart';

import '../../helpers/pump_app.dart';

void main() {
  setUpAll(() {
    // Màn đọc/ghi prefs qua flutter_secure_storage; trả rỗng để không treo.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'readAll' ? <String, String>{} : null,
    );
  });

  Future<void> pump(WidgetTester tester) async {
    await pumpApp(tester, IntroSurveyScreen(onDone: () {}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('hai nhóm Bất động sản + Xây dựng', (tester) async {
    await pump(tester);
    expect(find.text('Bất động sản'), findsOneWidget);
    // "Xây dựng" xuất hiện HAI lần: nhãn nhóm + chip dịch vụ 'build' (va chạm
    // tên đã biết, chấp nhận theo yêu cầu chủ dự án).
    expect(find.text('Xây dựng'), findsNWidgets(2));
  });

  testWidgets('4 dịch vụ hiện ngay, không cần chọn chip ý định trước',
      (tester) async {
    await pump(tester);
    expect(find.text('Thiết kế'), findsOneWidget);
    expect(find.text('Nội thất'), findsOneWidget);
    expect(find.text('Công nghiệp'), findsOneWidget); // đã đổi từ "BĐS công nghiệp"
    expect(find.text('BĐS công nghiệp'), findsNothing);
  });

  testWidgets('đã bỏ "Mua nhà đất"', (tester) async {
    await pump(tester);
    expect(find.text('Thuê nhà'), findsOneWidget);
    expect(find.text('Mua nhà đất'), findsNothing);
  });

  testWidgets('không còn 2 chip ý định trung gian', (tester) async {
    final l = await _l(tester);
    expect(find.text(l.surveyInterestFindService), findsNothing);
  });
}

Future<AppLocalizations> _l(WidgetTester tester) async {
  late AppLocalizations l;
  await pumpApp(
    tester,
    Builder(builder: (c) {
      l = AppLocalizations.of(c);
      return const SizedBox();
    }),
  );
  return l;
}
