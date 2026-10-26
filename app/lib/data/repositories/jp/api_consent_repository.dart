/// HTTP implementation of [IConsentRepository].
///
/// Hits /api/jp/consent (see phase-02-transactions-backend.md).
/// Uses the app's base HTTP client and auth headers.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:house_booking/domain/repositories/jp/i_consent_repository.dart';
import 'package:house_booking/features/consent/models/consent_purpose.dart';

class ApiConsentRepository implements IConsentRepository {
  ApiConsentRepository({
    required this.baseUrl,
    required this.authToken,
  });

  final String baseUrl;
  final String authToken;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  @override
  Future<List<ConsentRecord>> listConsents() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/jp/consent'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to list consents: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => ConsentRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<ConsentRecord>> grantConsents(ConsentGrantRequest request) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/jp/consent'),
      headers: _headers,
      body: jsonEncode(request.toJson()),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to grant consents: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => ConsentRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> revokeConsent(ConsentPurpose purpose) async {
    final wire = consentPurposeToWireValue(purpose);
    final response = await http.delete(
      Uri.parse('$baseUrl/api/jp/consent/$wire'),
      headers: _headers,
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to revoke consent: ${response.statusCode}');
    }
  }

  @override
  Future<String> requestExport() async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/jp/consent/export'),
      headers: _headers,
    );
    if (response.statusCode != 200 && response.statusCode != 202) {
      throw Exception('Failed to request export: ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['job_id'] as String;
  }

  @override
  Future<({String status, String? downloadUrl})> getExportStatus(
      String jobId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/jp/consent/export/$jobId'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to get export status: ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      status: body['status'] as String,
      downloadUrl: body['download_url'] as String?,
    );
  }

  @override
  Future<void> requestDeletion() async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/jp/consent/delete-request'),
      headers: _headers,
    );
    if (response.statusCode != 200 && response.statusCode != 202) {
      throw Exception('Failed to request deletion: ${response.statusCode}');
    }
  }
}
