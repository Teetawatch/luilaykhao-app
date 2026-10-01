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

  /// คีย์ CARTO Basemaps — ตั้งแต่ ก.ย. 2026 CARTO ไม่เสิร์ฟ tile ให้คำขอที่
  /// ไม่มีคีย์แล้ว (ได้ภาพลายน้ำ "API KEY REQUIRED" แทนแผนที่ ทั้งที่ตอบ 200)
  static const String cartoApiKey = String.fromEnvironment(
    'CARTO_API_KEY',
    defaultValue: '',
  );

  /// tile ของแผนที่ flutter_map ทุกจอ — แก้ที่นี่ที่เดียว
  static String get mapTileUrl {
    const base =
        'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
    if (cartoApiKey.isEmpty) return base;
    return '$base?key=${Uri.encodeQueryComponent(cartoApiKey)}';
  }

  /// คีย์ CARTO ของเราจำกัดให้ใช้ได้เฉพาะโดเมน luilaykhao.com (ตอบ 403 ถ้าไม่มี
  /// Referer) แต่แอปมือถือไม่ส่ง Referer เอง เลยต้องแนบให้ทุกคำขอ tile
  /// ใช้โดเมนจริงตายตัว ไม่ใช่ siteUrl — build dev ชี้ localhost ซึ่งคีย์ไม่รับ
  /// คืน Map ใหม่ทุกครั้ง เพราะ TileLayer จะเติม User-Agent ลงไปเอง
  static Map<String, String> get mapTileHeaders => {
    'Referer': 'https://luilaykhao.com/',
  };

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
