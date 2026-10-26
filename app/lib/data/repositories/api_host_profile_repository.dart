import 'package:image_picker/image_picker.dart' show XFile;
import 'package:house_booking/data/models/host_profile_model.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/session_service.dart';
import 'package:house_booking/domain/repositories/i_host_profile_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:house_booking/core/config/api_config.dart';

class ApiHostProfileRepository implements IHostProfileRepository {
  final ApiClient _client = const ApiClient();

  @override
  Future<HostProfileModel?> fetchProfile() async {
    try {
      final resp = await _client.get('/api/host/profile');
      final json = Map<String, dynamic>.from(resp);
      return HostProfileModel.fromJson(json);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<HostProfileModel> updateProfile({
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountHolder,
    String? taxId,
    String? payoutSchedule,
  }) async {
    final body = <String, dynamic>{};
    if (bankName != null) body['bank_name'] = bankName;
    if (bankAccountNumber != null)
      body['bank_account_number'] = bankAccountNumber;
    if (bankAccountHolder != null)
      body['bank_account_holder'] = bankAccountHolder;
    if (taxId != null) body['tax_id'] = taxId;
    if (payoutSchedule != null) body['payout_schedule'] = payoutSchedule;

    final resp = await _client.patch('/api/host/profile', body: body);
    return HostProfileModel.fromJson(Map<String, dynamic>.from(resp));
  }

  @override
  Future<void> uploadCccd({XFile? front, XFile? back}) async {
    if (front == null && back == null) {
      throw ArgumentError('front or back must be provided');
    }

    final token = await SessionService.instance.getToken();
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/host/profile/cccd');
    final request = http.MultipartRequest('POST', uri);

    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    if (front != null) {
      request.files.add(await _toMultipart('front', front));
    }
    if (back != null) {
      request.files.add(await _toMultipart('back', back));
    }

    final streamed = await request.send();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final body = await streamed.stream.bytesToString();
      throw ApiException(streamed.statusCode, 'Tải CCCD thất bại: $body');
    }
  }

  /// Build a MultipartFile from an XFile by reading its bytes (works on web + native).
  /// Resolves MIME type from XFile.mimeType (set by image_picker) or filename extension.
  Future<http.MultipartFile> _toMultipart(String field, XFile file) async {
    final bytes = await file.readAsBytes();
    final name = file.name.isNotEmpty ? file.name : '$field.jpg';
    final mime = file.mimeType ?? _mimeFromName(name);
    return http.MultipartFile.fromBytes(
      field,
      bytes,
      filename: name,
      contentType: MediaType.parse(mime),
    );
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  @override
  Future<String> upgradeToHost() async {
    final resp = await _client.post('/api/host/upgrade-to-host');
    return resp['token'] as String;
  }

  /// Update the host's monthly revenue goal via PATCH /api/host/profile.
  ///
  /// The backend PATCH /api/host/profile accepts any subset of profile fields;
  /// passing {"monthly_revenue_goal": null} clears the goal.
  @override
  Future<HostProfileModel> updateMonthlyGoal(double? goal) async {
    final resp = await _client.patch(
      '/api/host/profile',
      body: {'monthly_revenue_goal': goal},
    );
    return HostProfileModel.fromJson(Map<String, dynamic>.from(resp));
  }

  @override
  Future<HostProfileModel> updateCover(String? coverPath) async {
    final resp = await _client.patch(
      '/api/host/profile',
      body: {'cover_path': coverPath},
    );
    return HostProfileModel.fromJson(Map<String, dynamic>.from(resp));
  }
}
