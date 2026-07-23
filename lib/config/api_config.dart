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

  /// คีย์ Maps SDK ของฝั่งแอป — ตัวเดียวกับที่ใส่ไว้ใน AndroidManifest / Info.plist
  /// (ฝั่ง native ต้องมีคีย์เองอยู่ดี ตรงนี้ใช้เป็นสวิตช์ว่าจะวาดแผนที่ด้วย
  /// Google Maps หรือถอยไปใช้ OSM เหมือนเดิม)
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  /// จอติดตามรถใช้ Google Maps เมื่อมีคีย์เท่านั้น — ถ้าลืมใส่คีย์ให้ถอยไปใช้
  /// แผนที่ OSM เดิม ดีกว่าปล่อยให้ลูกค้าที่กำลังรอรถเจอจอเทาว่างเปล่า
  static bool get useGoogleMaps => googleMapsApiKey.isNotEmpty;

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
