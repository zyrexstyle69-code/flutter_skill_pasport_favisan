class Survey {
  final int id;
  final String title;
  final String description;
  final int categoryId;
  final String categoryName;
  final String? photo;
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;

  const Survey({
    required this.id,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.categoryName,
    this.photo,
    this.latitude,
    this.longitude,
    this.createdAt,
  });

  /// Factory constructor with robust and safe JSON parsing
  factory Survey.fromJson(Map<String, dynamic> json) {
    String categoryName = json['category_name']?.toString() ?? '';
    if (categoryName.isEmpty && json['category'] is Map) {
      categoryName = (json['category'] as Map)['name']?.toString() ?? '';
    }
    if (categoryName.isEmpty) {
      categoryName = 'Tanpa Kategori';
    }

    int categoryId = int.tryParse(json['category_id']?.toString() ?? '') ?? 0;
    if (categoryId == 0 && json['category'] is Map) {
      categoryId =
          int.tryParse((json['category'] as Map)['id']?.toString() ?? '') ?? 0;
    }

    String? photo = json['photo']?.toString();
    if (photo == null || photo.isEmpty || photo == 'null') {
      photo = json['photo_url']?.toString() ?? json['image']?.toString();
    }
    if (photo == 'null' || (photo != null && photo.trim().isEmpty)) {
      photo = null;
    }

    return Survey(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: json['title']?.toString() ?? '-',
      description: json['description']?.toString() ?? '-',
      categoryId: categoryId,
      categoryName: categoryName,
      photo: photo,
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
      createdAt: _parseDate(json['created_at']?.toString()),
    );
  }

  /// Safe date parsing handling 'YYYY-MM-DD HH:mm:ss' and standard ISO formats
  static DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    try {
      final sanitized = dateStr.trim().replaceFirst(' ', 'T');
      return DateTime.tryParse(sanitized);
    } catch (_) {
      return null;
    }
  }

  /// Formatted date in Indonesian locale (e.g., '28 Juli 2026, 19:03')
  String get formattedDate {
    if (createdAt == null) return '-';
    final date = createdAt!;
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    final day = date.day.toString();
    final month = (date.month >= 1 && date.month <= 12)
        ? months[date.month - 1]
        : date.month.toString();
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day $month $year, $hour:$minute';
  }

  /// Formatted coordinate string (e.g., '-7.3490000, 108.2210000')
  String get formattedCoordinates {
    if (latitude == null || longitude == null) {
      return 'Lokasi tidak tersedia';
    }
    return '$latitude, $longitude';
  }

  /// Check if survey has valid coordinates
  bool get hasValidCoordinates => latitude != null && longitude != null;
}
