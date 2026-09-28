import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// ═══════════════════════════════════════════════════════════
// 🇮🇶 Kurdish Material Localizations Delegate
// ═══════════════════════════════════════════════════════════
class KurdishMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const KurdishMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ku';

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    return GlobalMaterialLocalizations.delegate.load(
      const Locale('ar', 'AE'),
    );
  }

  @override
  bool shouldReload(_) => false;
}

// ═══════════════════════════════════════════════════════════
// 🍎 Kurdish Cupertino Localizations Delegate — نوێ
// ═══════════════════════════════════════════════════════════
class KurdishCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const KurdishCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ku';

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    return GlobalCupertinoLocalizations.delegate.load(
      const Locale('ar', 'AE'),
    );
  }

  @override
  bool shouldReload(_) => false;
}

// ═══════════════════════════════════════════════════════════
// 🌍 Kurdish Widgets Localizations Delegate — نوێ
// ═══════════════════════════════════════════════════════════
class KurdishWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const KurdishWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ku';

  @override
  Future<WidgetsLocalizations> load(Locale locale) {
    return GlobalWidgetsLocalizations.delegate.load(
      const Locale('ar', 'AE'),
    );
  }

  @override
  bool shouldReload(_) => false;
}