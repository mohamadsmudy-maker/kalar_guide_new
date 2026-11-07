// lib/models/event.dart

/// 📅 مۆدێلی ڕووداو
class AppEvent {
  final String? id;
  final String titleKu;
  final String? titleAr, titleEn;
  final String? descriptionKu, descriptionAr, descriptionEn;
  final String? imageUrl;
  final List<String> galleryUrls;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isAllDay;
  final String? locationName, address;
  final double? latitude, longitude;
  final String category, color, icon;
  final String? organizer, contactPhone, websiteUrl;
  final bool isPublished, isFeatured, isCancelled;
  final int views, interestedCount;
  final DateTime? createdAt;

  AppEvent({
    this.id,
    required this.titleKu,
    this.titleAr, this.titleEn,
    this.descriptionKu, this.descriptionAr, this.descriptionEn,
    this.imageUrl,
    this.galleryUrls = const [],
    required this.startDate,
    this.endDate,
    this.isAllDay = false,
    this.locationName, this.address,
    this.latitude, this.longitude,
    this.category = 'general',
    this.color = '#6C5CE7',
    this.icon = 'event',
    this.organizer, this.contactPhone, this.websiteUrl,
    this.isPublished = true,
    this.isFeatured = false,
    this.isCancelled = false,
    this.views = 0,
    this.interestedCount = 0,
    this.createdAt,
  });

  // ── helpers ──────────────────────────────────────
  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  static double? _asDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static bool _asBool(dynamic v, {required bool fallback}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
    return fallback;
  }

  factory AppEvent.fromJson(Map<String, dynamic> json) {
    return AppEvent(
      id: json['id']?.toString(),
      titleKu: json['title_ku']?.toString() ?? '',
      titleAr: json['title_ar']?.toString(),
      titleEn: json['title_en']?.toString(),
      descriptionKu: json['description_ku']?.toString(),
      descriptionAr: json['description_ar']?.toString(),
      descriptionEn: json['description_en']?.toString(),
      imageUrl: json['image_url']?.toString(),
      galleryUrls: (json['gallery_urls'] is List)
          ? (json['gallery_urls'] as List).map((e) => e.toString()).toList()
          : [],
      startDate: DateTime.tryParse(json['start_date']?.toString() ?? '') ?? DateTime.now(),
      endDate: json['end_date'] != null ? DateTime.tryParse(json['end_date'].toString()) : null,
      isAllDay: _asBool(json['is_all_day'], fallback: false),
      locationName: json['location_name']?.toString(),
      address: json['address']?.toString(),
      latitude: _asDoubleOrNull(json['latitude']),
      longitude: _asDoubleOrNull(json['longitude']),
      category: json['category']?.toString() ?? 'general',
      color: json['color']?.toString() ?? '#6C5CE7',
      icon: json['icon']?.toString() ?? 'event',
      organizer: json['organizer']?.toString(),
      contactPhone: json['contact_phone']?.toString(),
      websiteUrl: json['website_url']?.toString(),
      isPublished: _asBool(json['is_published'], fallback: true),
      isFeatured: _asBool(json['is_featured'], fallback: false),
      isCancelled: _asBool(json['is_cancelled'], fallback: false),
      views: _asInt(json['views']),
      interestedCount: _asInt(json['interested_count']),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true, bool includeNullables = false}) {
    return {
      if (includeId && id != null) 'id': id,
      'title_ku': titleKu,
      if (includeNullables || titleAr != null) 'title_ar': titleAr,
      if (includeNullables || titleEn != null) 'title_en': titleEn,
      if (includeNullables || descriptionKu != null) 'description_ku': descriptionKu,
      if (includeNullables || descriptionAr != null) 'description_ar': descriptionAr,
      if (includeNullables || descriptionEn != null) 'description_en': descriptionEn,
      if (includeNullables || imageUrl != null) 'image_url': imageUrl,
      'gallery_urls': galleryUrls,
      'start_date': startDate.toUtc().toIso8601String(),
      if (includeNullables || endDate != null) 'end_date': endDate?.toUtc().toIso8601String(),
      'is_all_day': isAllDay,
      if (includeNullables || locationName != null) 'location_name': locationName,
      if (includeNullables || address != null) 'address': address,
      if (includeNullables || latitude != null) 'latitude': latitude,
      if (includeNullables || longitude != null) 'longitude': longitude,
      'category': category,
      'color': color,
      'icon': icon,
      if (includeNullables || organizer != null) 'organizer': organizer,
      if (includeNullables || contactPhone != null) 'contact_phone': contactPhone,
      if (includeNullables || websiteUrl != null) 'website_url': websiteUrl,
      'is_published': isPublished,
      'is_featured': isFeatured,
      'is_cancelled': isCancelled,
      'views': views,
      'interested_count': interestedCount,
    };
  }

  Map<String, dynamic> toInsertJson() => toJson(includeId: false, includeNullables: false);

  Map<String, dynamic> toUpdateJson() {
    final json = toJson(includeId: false, includeNullables: true);
    json['updated_at'] = DateTime.now().toUtc().toIso8601String();
    return json;
  }

  AppEvent copyWith({
    String? id, bool clearId = false,
    String? titleKu,
    String? titleAr, bool clearTitleAr = false,
    String? titleEn, bool clearTitleEn = false,
    String? descriptionKu, bool clearDescriptionKu = false,
    String? descriptionAr, bool clearDescriptionAr = false,
    String? descriptionEn, bool clearDescriptionEn = false,
    String? imageUrl, bool clearImageUrl = false,
    List<String>? galleryUrls,
    DateTime? startDate,
    DateTime? endDate, bool clearEndDate = false,
    bool? isAllDay,
    String? locationName, bool clearLocationName = false,
    String? address, bool clearAddress = false,
    double? latitude, bool clearLatitude = false,
    double? longitude, bool clearLongitude = false,
    String? category, String? color, String? icon,
    String? organizer, bool clearOrganizer = false,
    String? contactPhone, bool clearContactPhone = false,
    String? websiteUrl, bool clearWebsiteUrl = false,
    bool? isPublished, bool? isFeatured, bool? isCancelled,
    int? views, int? interestedCount,
    DateTime? createdAt, bool clearCreatedAt = false,
  }) {
    return AppEvent(
      id: clearId ? null : (id ?? this.id),
      titleKu: titleKu ?? this.titleKu,
      titleAr: clearTitleAr ? null : (titleAr ?? this.titleAr),
      titleEn: clearTitleEn ? null : (titleEn ?? this.titleEn),
      descriptionKu: clearDescriptionKu ? null : (descriptionKu ?? this.descriptionKu),
      descriptionAr: clearDescriptionAr ? null : (descriptionAr ?? this.descriptionAr),
      descriptionEn: clearDescriptionEn ? null : (descriptionEn ?? this.descriptionEn),
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      galleryUrls: galleryUrls ?? this.galleryUrls,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      isAllDay: isAllDay ?? this.isAllDay,
      locationName: clearLocationName ? null : (locationName ?? this.locationName),
      address: clearAddress ? null : (address ?? this.address),
      latitude: clearLatitude ? null : (latitude ?? this.latitude),
      longitude: clearLongitude ? null : (longitude ?? this.longitude),
      category: category ?? this.category,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      organizer: clearOrganizer ? null : (organizer ?? this.organizer),
      contactPhone: clearContactPhone ? null : (contactPhone ?? this.contactPhone),
      websiteUrl: clearWebsiteUrl ? null : (websiteUrl ?? this.websiteUrl),
      isPublished: isPublished ?? this.isPublished,
      isFeatured: isFeatured ?? this.isFeatured,
      isCancelled: isCancelled ?? this.isCancelled,
      views: views ?? this.views,
      interestedCount: interestedCount ?? this.interestedCount,
      createdAt: clearCreatedAt ? null : (createdAt ?? this.createdAt),
    );
  }

  bool get hasLocation => latitude != null && longitude != null && latitude != 0 && longitude != 0;
  int get daysUntil => startDate.difference(DateTime.now()).inDays;

  bool get isToday {
    final now = DateTime.now();
    return startDate.year == now.year && startDate.month == now.month && startDate.day == now.day;
  }

  String getFormattedDate() {
    const months = ['کانوونی دووەم','شوبات','ئازار','نیسان','ئایار','حوزەیران',
      'تەممووز','ئاب','ئەیلوول','تشرینی یەکەم','تشرینی دووەم','کانوونی یەکەم'];
    return '${startDate.day} ${months[startDate.month - 1]} ${startDate.year}';
  }

  String getFormattedTime() {
    if (isAllDay) return 'هەموو ڕۆژ';
    return '${startDate.hour.toString().padLeft(2,'0')}:${startDate.minute.toString().padLeft(2,'0')}';
  }
}