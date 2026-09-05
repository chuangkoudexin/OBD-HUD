import 'dart:convert';

/// 自定义显示项大小
enum GaugeTileSize {
  small('小', 1),
  medium('中', 2),
  large('大', 3);

  const GaugeTileSize(this.label, this.cols);
  final String label;
  final int cols;
}

/// 用户手动添加的显示项
class CustomGaugeItem {
  final String pidCode;
  final String? title;

  /// 占用的网格列数(1~3)
  final GaugeTileSize size;
  final String? accentHex;

  const CustomGaugeItem({
    required this.pidCode,
    this.title,
    this.size = GaugeTileSize.medium,
    this.accentHex,
  });

  Map<String, dynamic> toJson() => {
        'pidCode': pidCode,
        'title': title,
        'size': size.name,
        'accentHex': accentHex,
      };

  factory CustomGaugeItem.fromJson(Map<String, dynamic> json) {
    // 旧版本保存的 kPa 涡轮压力自动迁移为 bar
    final code = json['pidCode'] as String? ?? '';
    return CustomGaugeItem(
      pidCode: code == 'boostKpa' ? 'boostBar' : code,
      title: json['title'] as String?,
      size: GaugeTileSize.values.firstWhere(
        (e) => e.name == json['size'],
        orElse: () => GaugeTileSize.medium,
      ),
      accentHex: json['accentHex'] as String?,
    );
  }

  static String encodeList(List<CustomGaugeItem> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<CustomGaugeItem> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return defaultItems();
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => CustomGaugeItem.fromJson(e as Map<String, dynamic>))
          .where((e) => e.pidCode.isNotEmpty)
          .toList();
    } catch (_) {
      return defaultItems();
    }
  }

  static List<CustomGaugeItem> defaultItems() => const [
        CustomGaugeItem(pidCode: '010D', size: GaugeTileSize.medium),
        CustomGaugeItem(pidCode: '0105', size: GaugeTileSize.medium),
        CustomGaugeItem(pidCode: '010F', size: GaugeTileSize.medium),
        CustomGaugeItem(pidCode: 'boostBar', size: GaugeTileSize.large),
        CustomGaugeItem(pidCode: '0111', size: GaugeTileSize.medium),
        CustomGaugeItem(pidCode: '0110', size: GaugeTileSize.medium),
      ];

  CustomGaugeItem copyWith({
    String? pidCode,
    String? title,
    GaugeTileSize? size,
    String? accentHex,
  }) {
    return CustomGaugeItem(
      pidCode: pidCode ?? this.pidCode,
      title: title ?? this.title,
      size: size ?? this.size,
      accentHex: accentHex ?? this.accentHex,
    );
  }
}
