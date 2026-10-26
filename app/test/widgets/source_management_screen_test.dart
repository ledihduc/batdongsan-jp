/// Widget tests for SourceManagementScreen — CRUD states and interactions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:house_booking/data/models/revenue_source_model.dart';
import 'package:house_booking/domain/repositories/i_analytics_repository.dart';
import 'package:house_booking/features/host/analytics/screens/source_management_screen.dart';
import 'package:house_booking/providers/report_provider.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockReportProvider extends Mock implements ReportProvider {}

// ---------------------------------------------------------------------------
// Fake data helpers
// ---------------------------------------------------------------------------

RevenueSourceModel _fakeSource({
  int id = 1,
  String displayName = 'Booking.com',
  String colorHex = '#1E88E5',
  bool isArchived = false,
}) {
  final now = DateTime.now();
  return RevenueSourceModel(
    id: id,
    hostId: 1,
    name: displayName,
    displayName: displayName,
    colorHex: colorHex,
    isArchived: isArchived,
    createdAt: now,
    updatedAt: now,
  );
}

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

Future<void> _pumpScreen(
  WidgetTester tester,
  ReportProvider provider,
) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => ChangeNotifierProvider<ReportProvider>.value(
          value: provider,
          child: const SourceManagementScreen(),
        ),
      ),
    ],
  );

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump(); // let post-frame initState fire
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Default stub setup
// ---------------------------------------------------------------------------

void _stubDefaults(MockReportProvider p) {
  when(() => p.sourcesLoading).thenReturn(false);
  when(() => p.sourcesError).thenReturn(null);
  when(() => p.sources).thenReturn(null);
  when(
    () => p.fetchSources(
      includeArchived: any(named: 'includeArchived'),
      force: any(named: 'force'),
    ),
  ).thenAnswer((_) async {});
  when(() => p.createSource(
        name: any(named: 'name'),
        colorHex: any(named: 'colorHex'),
      )).thenAnswer((_) async {});
  when(() => p.updateSource(
        id: any(named: 'id'),
        name: any(named: 'name'),
        colorHex: any(named: 'colorHex'),
      )).thenAnswer((_) async {});
  when(() => p.archiveSource(any())).thenAnswer((_) async {});
  when(() => p.deleteSource(any())).thenAnswer((_) async {});
  when(() => p.patchSourcesOptimistic(any())).thenReturn(null);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockReportProvider provider;

  setUpAll(() {
    registerFallbackValue(<RevenueSourceModel>[]);
  });

  setUp(() {
    provider = MockReportProvider();
    _stubDefaults(provider);
  });

  // ── Loading state ──────────────────────────────────────────────────────────

  group('Loading state', () {
    testWidgets('shows skeleton when sourcesLoading=true and no sources',
        (tester) async {
      when(() => provider.sourcesLoading).thenReturn(true);
      when(() => provider.sources).thenReturn(null);

      await _pumpScreen(tester, provider);

      // Skeleton renders a ListView with Container placeholders (no FAB label visible)
      // The FAB is still shown but the content area shows skeletons
      expect(find.byType(ListView), findsOneWidget);
    });
  });

  // ── Error state ────────────────────────────────────────────────────────────

  group('Error state', () {
    testWidgets('shows error + retry button when sourcesError set',
        (tester) async {
      when(() => provider.sourcesLoading).thenReturn(false);
      when(() => provider.sourcesError).thenReturn('Network error');
      when(() => provider.sources).thenReturn(null);

      await _pumpScreen(tester, provider);

      expect(find.text('Network error'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });

    testWidgets('retry button calls fetchSources', (tester) async {
      when(() => provider.sourcesLoading).thenReturn(false);
      when(() => provider.sourcesError).thenReturn('Network error');
      when(() => provider.sources).thenReturn(null);

      await _pumpScreen(tester, provider);

      await tester.tap(find.text('Thử lại'));
      await tester.pump();

      verify(
        () => provider.fetchSources(includeArchived: true, force: true),
      ).called(greaterThanOrEqualTo(1));
    });
  });

  // ── Data state ─────────────────────────────────────────────────────────────

  group('Data state', () {
    testWidgets('active sources rendered', (tester) async {
      final sources = [
        _fakeSource(id: 1, displayName: 'Booking.com'),
        _fakeSource(id: 2, displayName: 'Zalo OA'),
      ];
      when(() => provider.sources).thenReturn(sources);

      await _pumpScreen(tester, provider);

      expect(find.text('Booking.com'), findsOneWidget);
      expect(find.text('Zalo OA'), findsOneWidget);
    });

    testWidgets('archived sources in collapsed ExpansionTile', (tester) async {
      final sources = [
        _fakeSource(id: 1, displayName: 'Active'),
        _fakeSource(id: 2, displayName: 'Old Source', isArchived: true),
      ];
      when(() => provider.sources).thenReturn(sources);

      await _pumpScreen(tester, provider);

      // Archived section renders
      expect(find.byKey(const Key('archived_section')), findsOneWidget);

      // Expand the archived section
      await tester.tap(find.byKey(const Key('archived_section')));
      await tester.pumpAndSettle();

      expect(find.text('Old Source'), findsOneWidget);
    });
  });

  // ── FAB → create dialog ────────────────────────────────────────────────────

  group('FAB', () {
    testWidgets('FAB tap opens SourceEditDialog in create mode', (tester) async {
      when(() => provider.sources).thenReturn([]);

      await _pumpScreen(tester, provider);

      await tester.tap(find.byKey(const Key('add_source_fab')));
      await tester.pumpAndSettle();

      expect(find.text('Thêm nguồn mới'), findsOneWidget);
    });
  });

  // ── Edit menu ──────────────────────────────────────────────────────────────

  group('Edit menu', () {
    testWidgets('edit menu item opens dialog pre-filled with source data',
        (tester) async {
      final source = _fakeSource(id: 1, displayName: 'Booking.com');
      when(() => provider.sources).thenReturn([source]);

      await _pumpScreen(tester, provider);

      // Open the popup menu
      await tester.tap(find.byKey(Key('source_menu_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(Key('menu_edit_1')));
      await tester.pumpAndSettle();

      // Edit dialog should show title "Sửa nguồn" and pre-filled name
      expect(find.text('Sửa nguồn'), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const Key('source_name_field')),
      );
      expect(field.controller!.text, equals('Booking.com'));
    });
  });

  // ── Archive ────────────────────────────────────────────────────────────────

  group('Archive', () {
    testWidgets('archive menu → confirm dialog → provider.archiveSource called',
        (tester) async {
      final source = _fakeSource(id: 1, displayName: 'Booking.com');
      when(() => provider.sources).thenReturn([source]);

      await _pumpScreen(tester, provider);

      await tester.tap(find.byKey(Key('source_menu_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(Key('menu_archive_1')));
      await tester.pumpAndSettle();

      // Confirm archive
      expect(find.text('Lưu trữ nguồn?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('archive_confirm')));
      await tester.pumpAndSettle();

      verify(() => provider.archiveSource(1)).called(1);
    });

    testWidgets('cancel archive → provider.archiveSource NOT called',
        (tester) async {
      final source = _fakeSource(id: 1, displayName: 'Test');
      when(() => provider.sources).thenReturn([source]);

      await _pumpScreen(tester, provider);

      await tester.tap(find.byKey(Key('source_menu_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('menu_archive_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('archive_cancel')));
      await tester.pumpAndSettle();

      verifyNever(() => provider.archiveSource(1));
    });
  });

  // ── Delete ─────────────────────────────────────────────────────────────────

  group('Delete', () {
    testWidgets('delete success → provider.deleteSource called', (tester) async {
      final source = _fakeSource(id: 1, displayName: 'To delete');
      when(() => provider.sources).thenReturn([source]);

      await _pumpScreen(tester, provider);

      await tester.tap(find.byKey(Key('source_menu_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(Key('menu_delete_1')));
      await tester.pumpAndSettle();

      // Confirm delete
      expect(find.text('Xoá vĩnh viễn nguồn?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('delete_confirm')));
      await tester.pumpAndSettle();

      verify(() => provider.deleteSource(1)).called(1);
    });

    testWidgets('delete with SourceInUseException → SnackBar shown',
        (tester) async {
      final source = _fakeSource(id: 2, displayName: 'In use');
      when(() => provider.sources).thenReturn([source]);
      when(() => provider.deleteSource(2)).thenThrow(const SourceInUseException());

      await _pumpScreen(tester, provider);

      await tester.tap(find.byKey(Key('source_menu_2')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(Key('menu_delete_2')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('delete_confirm')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Đang được sử dụng'),
        findsOneWidget,
      );
    });

    testWidgets('cancel delete → provider.deleteSource NOT called',
        (tester) async {
      final source = _fakeSource(id: 1, displayName: 'Keep me');
      when(() => provider.sources).thenReturn([source]);

      await _pumpScreen(tester, provider);

      await tester.tap(find.byKey(Key('source_menu_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('menu_delete_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('delete_cancel')));
      await tester.pumpAndSettle();

      verifyNever(() => provider.deleteSource(any()));
    });
  });

  // ── SourceEditDialog (integration via screen) ──────────────────────────────

  group('SourceEditDialog via FAB', () {
    testWidgets('create with valid name calls provider.createSource',
        (tester) async {
      when(() => provider.sources).thenReturn([]);

      await _pumpScreen(tester, provider);

      await tester.tap(find.byKey(const Key('add_source_fab')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('source_name_field')), 'New Source');
      await tester.pump();

      await tester.tap(find.byKey(const Key('source_edit_save')));
      await tester.pumpAndSettle();

      verify(() => provider.createSource(
            name: 'New Source',
            colorHex: any(named: 'colorHex'),
          )).called(1);
    });
  });
}
