/// ⚙️ نەخشە و نرخی جێگیر
class AppConstants {
  // 📍 کۆئۆردینەیتی شاری کەلار
  static const double kalarLatitude = 34.6189;
  static const double kalarLongitude = 45.3156;

  // 🗺️ زوومی سەرەتایی نەخشە
  static const double defaultMapZoom = 14.0;

  // 📏 سنووری دووری بۆ پیشاندانی شوێنەکان (بە کیلۆمەتر)
  static const double maxDistanceKm = 50.0;

  // 🖼️ قەبارەی وێنەکان
  static const int maxImageSizeKB = 800;
  static const int imageQuality = 70;
  static const int maxProductImages = 4;
  static const int maxNewsImages = 4;
  static const int maxStoreImages = 3;
  static const int maxComplaintImages = 2;

  // ⏱️ کاتەکان
  static const Duration flashSaleDuration = Duration(hours: 24);
  static const Duration bannerAutoPlayInterval = Duration(seconds: 4);

  // 📱 پاکێج ناوەکان
  static const String appName = 'ڕێبەری کەلار';
  static const String appVersion = '1.0.0';
}