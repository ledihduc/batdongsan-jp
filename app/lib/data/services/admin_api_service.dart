import 'package:house_booking/data/services/api_client.dart';

class AdminApiService {
  final ApiClient _client = const ApiClient();

  Future<List<Map<String, dynamic>>> getUsers() async {
    final response = await _client.get('/api/users');
    return List<Map<String, dynamic>>.from(response['users'] as List);
  }
}
