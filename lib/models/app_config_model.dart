class AppConfigModel {
  final String storeName;
  final String location;
  final String displayPhone;
  final List<String> whatsappNumbers; // max 2
  final List<String> callNumbers;     // max 2

  const AppConfigModel({
    this.storeName = 'Ma Boutique',
    this.location = '',
    this.displayPhone = '',
    this.whatsappNumbers = const [],
    this.callNumbers = const [],
  });

  /// The first WhatsApp number (or empty string)
  String get primaryWhatsapp =>
      whatsappNumbers.isNotEmpty ? whatsappNumbers[0] : '';

  /// The first call number (or empty string)
  String get primaryCall =>
      callNumbers.isNotEmpty ? callNumbers[0] : '';

  factory AppConfigModel.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic value) {
      if (value is List) return value.cast<String>();
      return [];
    }

    return AppConfigModel(
      storeName: (json['store_name'] as String?) ?? 'Ma Boutique',
      location: (json['location'] as String?) ?? '',
      displayPhone: (json['display_phone'] as String?) ?? '',
      whatsappNumbers: parseList(json['whatsapp_numbers']),
      callNumbers: parseList(json['call_numbers']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': 1, // singleton
        'store_name': storeName,
        'location': location,
        'display_phone': displayPhone,
        'whatsapp_numbers': whatsappNumbers,
        'call_numbers': callNumbers,
      };

  AppConfigModel copyWith({
    String? storeName,
    String? location,
    String? displayPhone,
    List<String>? whatsappNumbers,
    List<String>? callNumbers,
  }) {
    return AppConfigModel(
      storeName: storeName ?? this.storeName,
      location: location ?? this.location,
      displayPhone: displayPhone ?? this.displayPhone,
      whatsappNumbers: whatsappNumbers ?? this.whatsappNumbers,
      callNumbers: callNumbers ?? this.callNumbers,
    );
  }
}
