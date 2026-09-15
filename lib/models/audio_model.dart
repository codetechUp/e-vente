class AudioModel {
  final String? id;
  final String title;
  final String audioUrl;
  final int? durationSeconds;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final String? createdBy;
  final String? imageUrl;

  const AudioModel({
    this.id,
    required this.title,
    required this.audioUrl,
    this.durationSeconds,
    this.expiresAt,
    this.createdAt,
    this.createdBy,
    this.imageUrl,
  });

  factory AudioModel.fromJson(Map<String, dynamic> json) {
    return AudioModel(
      id: json['id'] as String?,
      title: json['title'] as String? ?? 'Sans titre',
      audioUrl: json['audio_url'] as String? ?? '',
      durationSeconds: json['duration_seconds'] as int?,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'audio_url': audioUrl,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (expiresAt != null) 'expires_at': expiresAt!.toUtc().toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
      if (createdBy != null) 'created_by': createdBy,
      if (imageUrl != null) 'image_url': imageUrl,
    };
  }
}
