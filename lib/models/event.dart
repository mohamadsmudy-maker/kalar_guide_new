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
      isAllDay: json['is_all_day'] == true,
      locationName: json['location_name']?.toString(),
      address: json['address']?.toString(),
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
      category: json['category']?.toString() ?? 'general',
      color: json['color']?.toString() ?? '#6C5CE7',
      icon: json['icon']?.toString() ?? 'event',
      organizer: json['organizer']?.toString(),
      contactPhone: json['contact_phone']?.toString(),
      websiteUrl: json['website_url']?.toString(),
      isPublished: json['is_published'] != false,
      isFeatured: json['is_featured'] == true,
      isCancelled: json['is_cancelled'] == true,
      views: int.tryParse(json['views']?.toString() ?? '0') ?? 0,
      interestedCount: int.tryParse(json['interested_count']?.toString() ?? '0') ?? 0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
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