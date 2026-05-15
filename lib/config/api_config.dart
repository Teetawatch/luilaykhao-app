class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://luilaykhao.com/api/v1',
  );

  static const String reverbAppKey = String.fromEnvironment(
    'REVERB_APP_KEY',
    defaultValue: '',
  );

  static const String reverbHost = String.fromEnvironment(
    'REVERB_HOST',
    defaultValue: '',
  );

  static const int reverbPort = int.fromEnvironment(
    'REVERB_PORT',
    defaultValue: 443,
  );

  static const String reverbScheme = String.fromEnvironment(
    'REVERB_SCHEME',
    defaultValue: 'wss',
  );

  static String get siteUrl {
    final uri = Uri.parse(baseUrl);
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }

  static String mediaUrl(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return '$siteUrl$raw';
    return '$siteUrl/$raw';
  }

  static bool get hasRealtimeConfig =>
      reverbAppKey.isNotEmpty && reverbHost.isNotEmpty;

  static Uri get reverbUri {
    const port = reverbPort > 0 ? ':$reverbPort' : '';
    return Uri.parse('$reverbScheme://$reverbHost$port/app/$reverbAppKey');
  }
}
