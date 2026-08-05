class ApiConfig {
  static const String _fallbackBaseUrl = 'https://luilaykhao.com/api/v1';

  static const String _rawBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _fallbackBaseUrl,
  );

  /// ค่าที่เพี้ยนใน `--dart-define` ทำให้แอปที่ปล่อยขึ้นสโตร์ตายทั้งตัว — ทุก
  /// request ยิงไปผิดที่ ทุกหน้าว่างเปล่า และดูจากในเครื่องไม่ออกเพราะตอน
  /// `flutter run` เราพิมพ์คำสั่งถูก (เกิดมาแล้วรอบหนึ่งกับ build 1.12.0+41:
  /// คำสั่งหลายบรรทัดโดนกลืน `\` ท้ายบรรทัด ทั้งก้อนที่เหลือเลยไหลเข้าไปอยู่ใน
  /// API_BASE_URL). กันไว้ตรงนี้: เอาเฉพาะโทเคนแรก แล้วถ้าไม่ใช่ URL http(s)
  /// ที่สมบูรณ์ก็ถอยไปใช้ production แทนที่จะปล่อยให้แอปเป็นก้อนว่าง
  static final String baseUrl = normalizeBaseUrl(_rawBaseUrl);

  static final String reverbAppKey = _firstToken(
    const String.fromEnvironment('REVERB_APP_KEY', defaultValue: ''),
  );

  static final String reverbHost = _firstToken(
    const String.fromEnvironment('REVERB_HOST', defaultValue: ''),
  );

  static const int reverbPort = int.fromEnvironment(
    'REVERB_PORT',
    defaultValue: 443,
  );

  static final String reverbScheme = _firstToken(
    const String.fromEnvironment('REVERB_SCHEME', defaultValue: 'wss'),
  );

  static String _firstToken(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s')).first;
  }

  static String normalizeBaseUrl(String raw) {
    var candidate = _firstToken(raw);
    while (candidate.endsWith('/')) {
      candidate = candidate.substring(0, candidate.length - 1);
    }
    final uri = Uri.tryParse(candidate);
    final usable =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
    return usable ? candidate : _fallbackBaseUrl;
  }

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
