import 'package:flutter/foundation.dart';

/// Environment configuration manager
/// This class handles loading configuration from environment variables
/// or server endpoints to avoid hardcoding sensitive data in source code
class EnvConfig {
  static EnvConfig? _instance;
  
  factory EnvConfig() {
    _instance ??= EnvConfig._internal();
    return _instance!;
  }
  
  EnvConfig._internal();
  
  // Cached configuration values
  Map<String, String>? _config;
  
  // Configuration keys
  static const String keyApiHost = 'API_HOST';
  static const String keyWsHost = 'WS_HOST';
  static const String keyWalletProjectId = 'WALLET_PROJECT_ID';
  static const String keyEncryptionKey = 'ENCRYPTION_KEY';
  
  /// Initialize configuration from environment or server
  Future<void> initialize() async {
    if (kIsWeb) {
      // Web: Load from server endpoint
      await _loadFromServer();
    } else {
      // Mobile: Load from secure storage or build-time config
      await _loadFromPlatform();
    }
  }
  
  /// Load configuration from server (for web)
  Future<void> _loadFromServer() async {
    try {
      // In production, this would fetch from a secure endpoint
      // Example:
      // final response = await http.get('/api/config');
      // _config = jsonDecode(response.body);
      
      // For now, using empty config to avoid exposing keys
      _config = {
        keyApiHost: '',
        keyWsHost: '',
        keyWalletProjectId: '',
        keyEncryptionKey: '',
      };
    } catch (e) {
      debugPrint('Failed to load config from server: $e');
      _config = {};
    }
  }
  
  /// Load configuration from platform-specific secure storage
  Future<void> _loadFromPlatform() async {
    // Mobile platforms can use:
    // - iOS: Keychain
    // - Android: Keystore
    // - Environment variables at build time
    
    _config = {
      keyApiHost: '',
      keyWsHost: '',
      keyWalletProjectId: '',
      keyEncryptionKey: '',
    };
  }
  
  /// Get configuration value
  String? getValue(String key) {
    return _config?[key];
  }
  
  /// Get API host URL
  String get apiHost {
    return getValue(keyApiHost) ?? '';
  }
  
  /// Get WebSocket host URL
  String get wsHost {
    return getValue(keyWsHost) ?? '';
  }
  
  /// Get wallet project ID
  String get walletProjectId {
    return getValue(keyWalletProjectId) ?? '';
  }
  
  /// Get encryption key
  String get encryptionKey {
    return getValue(keyEncryptionKey) ?? '';
  }
  
  /// Check if configuration is loaded
  bool get isConfigured {
    return _config != null && _config!.isNotEmpty;
  }
  
  /// Clear cached configuration
  void clear() {
    _config = null;
  }
}