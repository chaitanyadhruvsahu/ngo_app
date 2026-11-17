/// Mirrors the backend's `DocumentSerializer` — deliberately has no
/// storage key/path field; that's never sent to the client (Phase 2
/// mandate, Mandate #1).
class Document {
  const Document({
    required this.id,
    required this.type,
    required this.originalFilename,
    required this.contentType,
    required this.sizeBytes,
    required this.uploadedAt,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'] as String,
      type: json['type'] as String,
      originalFilename: json['original_filename'] as String,
      contentType: json['content_type'] as String,
      sizeBytes: json['size_bytes'] as int,
      uploadedAt: json['uploaded_at'] as String,
    );
  }

  final String id;
  final String type;
  final String originalFilename;
  final String contentType;
  final int sizeBytes;
  final String uploadedAt;

  static const types = [
    'aadhaar',
    'marksheet',
    'bank_statement',
    'photo',
    'other'
  ];
}
