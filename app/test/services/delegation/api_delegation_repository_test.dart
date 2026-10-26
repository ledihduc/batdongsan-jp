/// Unit tests for ApiDelegationRepository — verifies correct API paths,
/// request body construction, and response deserialization.
///
/// Uses mocktail to mock ApiClient — no real HTTP calls.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:house_booking/data/models/operator_delegation_model.dart';
import 'package:house_booking/data/models/delegation_invitation_model.dart';
import 'package:house_booking/data/repositories/api_delegation_repository.dart';
import 'package:house_booking/data/services/api_client.dart';

// ── Mock ──────────────────────────────────────────────────────────────────────

class MockApiClient extends Mock implements ApiClient {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

Map<String, dynamic> _delegationJson({
  String id = 'deleg-001',
  String status = 'active',
  String rolePreset = 'operator_full',
}) =>
    {
      'id': id,
      'owner_user_id': 'owner-1',
      'operator_user_id': 'operator-1',
      'role_preset': rolePreset,
      'status': status,
      'created_at': '2026-01-01T00:00:00.000Z',
      'owner_name': 'Nguyễn Văn A',
      'property_count': 3,
      'pending_approval_count': 1,
      'mtd_revenue_vnd': 15000000.0,
      'permission_set': ['contract.create', 'expense.approve'],
    };

Map<String, dynamic> _invitationJson({
  String id = 'inv-001',
  String status = 'pending',
}) =>
    {
      'id': id,
      'owner_user_id': 'owner-1',
      'operator_email': 'op@example.com',
      'status': status,
      'created_at': '2026-01-01T00:00:00.000Z',
      'owner_name': 'Nguyễn Văn A',
    };

void main() {
  late MockApiClient mockClient;
  late ApiDelegationRepository repository;

  setUp(() {
    mockClient = MockApiClient();
    repository = ApiDelegationRepository(client: mockClient);
  });

  group('fetchDelegationsAsOperator', () {
    test('calls GET /api/delegations?role=operator', () async {
      when(() => mockClient.getList(
            '/api/delegations',
            queryParameters: {'role': 'operator'},
          )).thenAnswer((_) async => [_delegationJson()]);

      final result = await repository.fetchDelegationsAsOperator();

      expect(result, hasLength(1));
      expect(result.first.id, equals('deleg-001'));
      expect(result.first.ownerName, equals('Nguyễn Văn A'));
      expect(result.first.propertyCount, equals(3));
      expect(result.first.mtdRevenueVnd, equals(15000000.0));

      verify(() => mockClient.getList(
            '/api/delegations',
            queryParameters: {'role': 'operator'},
          )).called(1);
    });

    test('returns empty list on empty API response', () async {
      when(() => mockClient.getList(
            '/api/delegations',
            queryParameters: {'role': 'operator'},
          )).thenAnswer((_) async => []);

      final result = await repository.fetchDelegationsAsOperator();
      expect(result, isEmpty);
    });

    test('propagates ApiException on HTTP error', () async {
      when(() => mockClient.getList(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(ApiException(500, 'Server error'));

      expect(
        () => repository.fetchDelegationsAsOperator(),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('fetchDelegationsAsOwner', () {
    test('calls GET /api/delegations?role=owner', () async {
      when(() => mockClient.getList(
            '/api/delegations',
            queryParameters: {'role': 'owner'},
          )).thenAnswer((_) async => [_delegationJson(status: 'active')]);

      final result = await repository.fetchDelegationsAsOwner();
      expect(result, hasLength(1));
      expect(result.first.status, equals(DelegationStatus.active));
    });
  });

  group('sendInvitation', () {
    test('POSTs to /api/delegation-invitations with correct body', () async {
      when(() => mockClient.post(
            '/api/delegation-invitations',
            body: any(named: 'body'),
          )).thenAnswer((_) async => _invitationJson());

      final result = await repository.sendInvitation(
        operatorEmail: 'op@example.com',
        rolePreset: 'operator_full',
      );

      expect(result.id, equals('inv-001'));
      expect(result.operatorEmail, equals('op@example.com'));
      expect(result.status, equals(InvitationStatus.pending));

      final captured = verify(() => mockClient.post(
            '/api/delegation-invitations',
            body: captureAny(named: 'body'),
          )).captured.single as Map<String, dynamic>;

      expect(captured['operator_email'], equals('op@example.com'));
      expect(captured['role_preset'], equals('operator_full'));
    });

    test('includes thresholds in body when provided', () async {
      when(() => mockClient.post(
            any(),
            body: any(named: 'body'),
          )).thenAnswer((_) async => _invitationJson());

      await repository.sendInvitation(
        operatorEmail: 'op@example.com',
        rolePreset: 'operator_full',
        thresholds: const DelegationThresholds(
          contractCreate: 50000000,
          expenseApproval: 10000000,
        ),
      );

      final captured = verify(() => mockClient.post(
            any(),
            body: captureAny(named: 'body'),
          )).captured.single as Map<String, dynamic>;

      expect(captured['thresholds'], isNotNull);
      expect(
        (captured['thresholds'] as Map)['contract_create'],
        equals(50000000.0),
      );
    });
  });

  group('acceptInvitation', () {
    test('POSTs to /api/delegation-invitations/:id/accept', () async {
      when(() => mockClient.post(
            '/api/delegation-invitations/inv-001/accept',
          )).thenAnswer((_) async => _delegationJson());

      final result = await repository.acceptInvitation('inv-001');
      expect(result.id, equals('deleg-001'));

      verify(() => mockClient.post(
            '/api/delegation-invitations/inv-001/accept',
          )).called(1);
    });
  });

  group('terminateDelegation', () {
    test('POSTs to /api/delegations/:id/terminate with reason', () async {
      when(() => mockClient.post(
            '/api/delegations/deleg-001/terminate',
            body: any(named: 'body'),
          )).thenAnswer((_) async =>
          _delegationJson(id: 'deleg-001', status: 'terminated'));

      final result = await repository.terminateDelegation(
        'deleg-001',
        reason: 'Operator không phản hồi',
      );

      expect(result.status, equals(DelegationStatus.terminated));

      final captured = verify(() => mockClient.post(
            '/api/delegations/deleg-001/terminate',
            body: captureAny(named: 'body'),
          )).captured.single as Map<String, dynamic>;

      expect(captured['reason'], equals('Operator không phản hồi'));
    });
  });

  group('OperatorDelegationModel.fromJson', () {
    test('parses active delegation correctly', () {
      final model = OperatorDelegationModel.fromJson(_delegationJson());
      expect(model.id, equals('deleg-001'));
      expect(model.status, equals(DelegationStatus.active));
      expect(model.rolePreset, equals(DelegationRolePreset.operatorFull));
      expect(model.permissionSet, contains('contract.create'));
      expect(model.isActive, isTrue);
      expect(model.isPaused, isFalse);
    });

    test('parses paused delegation correctly', () {
      final model = OperatorDelegationModel.fromJson(
        _delegationJson(status: 'paused'),
      );
      expect(model.isPaused, isTrue);
      expect(model.isActive, isFalse);
    });

    test('handles missing optional fields gracefully', () {
      final minimal = {
        'id': 'deleg-min',
        'owner_user_id': 'owner-1',
        'operator_user_id': 'op-1',
        'role_preset': 'viewer',
        'status': 'pending',
        'created_at': '2026-01-01T00:00:00.000Z',
      };
      final model = OperatorDelegationModel.fromJson(minimal);
      expect(model.ownerName, isNull);
      expect(model.permissionSet, isEmpty);
      expect(model.propertyCount, equals(0));
      expect(model.thresholds, isNull);
    });
  });
}
