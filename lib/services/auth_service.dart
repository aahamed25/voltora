import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import 'api_client.dart';

class AuthResult {
  final bool ok;
  final String? error;

  const AuthResult.success()
      : ok = true,
        error = null;

  const AuthResult.failure(this.error) : ok = false;
}

class AuthService extends ChangeNotifier {
  static const _userKey = 'voltora_api_user';
  static const _legacyUsersKey = 'voltora_users';
  static const _legacySessionKey = 'voltora_session';

  AppUser? currentUser;
  bool adminSetupAvailable = false;
  String? apiError;

  bool get isLoggedIn => currentUser != null && apiClient.hasToken;
  bool get hasAdmin => !adminSetupAvailable;

  Future<void> init() async {
    await apiClient.init();
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_legacyUsersKey);
    await preferences.remove(_legacySessionKey);
    final rawUser = preferences.getString(_userKey);
    if (apiClient.hasToken && rawUser != null) {
      currentUser = AppUser.fromJson(
        jsonDecode(rawUser) as Map<String, dynamic>,
      );
    } else {
      await clearSession();
    }
  }

  Future<AuthResult> register({
    required String nom,
    required String prenom,
    required DateTime birthDate,
    required String phone,
    required String email,
    required String username,
    required String password,
  }) => _createAccount(
    'auth/register',
    nom: nom,
    prenom: prenom,
    birthDate: birthDate,
    phone: phone,
    email: email,
    username: username,
    password: password,
  );

  Future<AuthResult> registerAdmin({
    required String nom,
    required String prenom,
    required DateTime birthDate,
    required String phone,
    required String email,
    required String username,
    required String password,
    required String setupKey,
  }) => _createAccount(
    'auth/first-admin',
    setupKey: setupKey,
    nom: nom,
    prenom: prenom,
    birthDate: birthDate,
    phone: phone,
    email: email,
    username: username,
    password: password,
  );

  Future<AuthResult> _createAccount(
    String path, {
    String? setupKey,
    required String nom,
    required String prenom,
    required DateTime birthDate,
    required String phone,
    required String email,
    required String username,
    required String password,
  }) async {
    try {
      final response = await apiClient.post(
        path,
        setupKey: setupKey,
        body: {
          'nom': nom.trim(),
          'prenom': prenom.trim(),
          'birth_date': _dateString(birthDate),
          'phone': phone.trim(),
          'email': email.trim(),
          'username': username.trim(),
          'password': password,
        },
      );
      await _saveSession(response);
      return const AuthResult.success();
    } on ApiException catch (error) {
      return AuthResult.failure(error.message);
    }
  }

  Future<AuthResult> login(String identifier, String password) async {
    try {
      final response = await apiClient.post(
        'auth/login',
        body: {'identifier': identifier.trim(), 'password': password},
      );
      await _saveSession(response);
      return const AuthResult.success();
    } on ApiException catch (error) {
      return AuthResult.failure(error.message);
    }
  }

  Future<void> _saveSession(Map<String, dynamic> response) async {
    final token = response['token'];
    final userData = response['user'];
    if (token is! String || userData is! Map<String, dynamic>) {
      throw const ApiException('Réponse de connexion incomplète.');
    }
    currentUser = AppUser.fromJson(userData);
    await apiClient.setToken(token);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_userKey, jsonEncode(userData));
    notifyListeners();
  }

  Future<void> logout() async {
    ApiException? logoutError;
    if (apiClient.hasToken) {
      try {
        await apiClient.post('auth/logout');
      } on ApiException catch (error) {
        logoutError = error;
      }
    }
    await clearSession();
    if (logoutError != null) throw logoutError;
  }

  Future<void> clearSession() async {
    currentUser = null;
    await apiClient.clearToken();
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_userKey);
    notifyListeners();
  }

  Future<void> refreshAdminSetupStatus() async {
    try {
      final status = await apiClient.get('auth/admin-setup-status');
      adminSetupAvailable = status['available'] as bool? ?? false;
      apiError = null;
    } on ApiException catch (error) {
      apiError = error.message;
    }
    notifyListeners();
  }

  String _dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

final authService = AuthService();
