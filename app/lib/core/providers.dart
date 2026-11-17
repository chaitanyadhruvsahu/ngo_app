import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import 'package:ngo_app/core/api/api_client.dart';
import 'package:ngo_app/core/api/token_storage.dart';

final tokenStorageProvider =
    Provider<TokenStorage>((ref) => SecureTokenStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(tokenStorage: ref.watch(tokenStorageProvider));
});

final emailAuthEnabledProvider = FutureProvider<bool>((ref) async {
  final response = await ref
      .watch(apiClientProvider)
      .dio
      .get<Map<String, dynamic>>('/config',
          options:
              Options(extra: {'skipAuthHeader': true, 'skipRefresh': true}));
  return response.data?['email_auth_enabled'] == true;
});
