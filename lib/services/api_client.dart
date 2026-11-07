import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiClient {
  static const _tokenKey = 'voltora_api_token';
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost/voltora/backend/public/api',
  );

  final http.Client _http = http.Client();
  String? _token;

  bool get hasToken => _token != null;

  Future<void> init() async {
    final preferences = await SharedPreferences.getInstance();
    _token = preferences.getString(_tokenKey);
  }

  Future<void> setToken(String token) async {
    _token = token;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    _token = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
  }

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? setupKey,
  }) => _send('POST', path, body: body, setupKey: setupKey);

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) =>
      _send('PUT', path, body: body);

  Future<Map<String, dynamic>> delete(String path) => _send('DELETE', path);

  Future<Map<String, dynamic>> upload(
    String path, {
    required Map<String, String> fields,
    required List<XFile> images,
  }) async {
    try {
      final request = http.MultipartRequest('POST', _uri(path));
      _headers(request.headers);
      request.fields.addAll(fields);
      for (final image in images) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'images[]',
            await image.readAsBytes(),
            filename: image.name,
          ),
        );
      }
      return _decode(await _http.send(request).then(http.Response.fromStream));
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Serveur inaccessible. Vérifie l’adresse de l’API et ta connexion.',
      );
    }
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? setupKey,
  }) async {
    final uri = _uri(path);
    final headers = <String, String>{'Accept': 'application/json'};
    _headers(headers);
    if (body != null) headers['Content-Type'] = 'application/json';
    if (setupKey != null) headers['X-Admin-Setup-Key'] = setupKey;

    late final http.Response response;
    try {
      if (method == 'GET') {
        response = await _http.get(uri, headers: headers);
      } else if (method == 'POST') {
        response = await _http.post(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
      } else if (method == 'PUT') {
        response = await _http.put(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
      } else if (method == 'DELETE') {
        response = await _http.delete(uri, headers: headers);
      } else {
        throw const ApiException('Méthode API non prise en charge.');
      }
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Serveur inaccessible. Vérifie l’adresse de l’API et ta connexion.',
      );
    }
    return _decode(response);
  }

  Uri _uri(String path) {
    final normalizedBase = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final normalizedPath = path.replaceFirst(RegExp(r'^/+'), '');
    return Uri.parse('$normalizedBase/$normalizedPath');
  }

  String resolveImageUrl(String url) {
    final imageUri = Uri.parse(url);
    final apiUri = Uri.parse(baseUrl);
    final isLoopbackHost =
        imageUri.host == 'localhost' ||
        imageUri.host == '127.0.0.1' ||
        imageUri.host == '::1';

    if (imageUri.hasScheme && !isLoopbackHost) return url;
    if (imageUri.hasScheme) {
      return apiUri
          .replace(
            path: imageUri.path,
            query: imageUri.hasQuery ? imageUri.query : null,
            fragment: imageUri.hasFragment ? imageUri.fragment : null,
          )
          .toString();
    }
    return apiUri.resolve(url).toString();
  }

  void _headers(Map<String, String> headers) {
    headers['Accept'] = 'application/json';
    final token = _token;
    if (token != null) headers['Authorization'] = 'Bearer $token';
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Réponse JSON invalide.');
      }
      payload = decoded;
    } on FormatException {
      throw ApiException(
        'Réponse invalide du serveur.',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        payload['error'] as String? ??
            'Erreur de communication avec le serveur.',
        statusCode: response.statusCode,
      );
    }
    return payload;
  }

  void dispose() => _http.close();
}

final apiClient = ApiClient();
