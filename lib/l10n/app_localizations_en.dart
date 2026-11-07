// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Kalar Guide';

  @override
  String get nav_home => 'Home';

  @override
  String get nav_places => 'Places';

  @override
  String get nav_categories => 'Categories';

  @override
  String get nav_favorites => 'Favorites';

  @override
  String get nav_daily => 'Daily';

  @override
  String get welcome_guest => 'Dear Guest';

  @override
  String get settings => 'Settings';

  @override
  String get emergency => 'Emergency';

  @override
  String get events => 'Events';
}
