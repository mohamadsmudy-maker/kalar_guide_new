import 'osm_import_service.dart';

/// ڕیزێکی لیستی هێنان لە OpenStreetMap
class OsmImportRow {
  OsmImportRow(this.place, this.match, this.category, {this.neighborhood})
      : selected = match == OsmMatch.none && category != null;

  final OsmPlace place;
  final OsmMatch match;

  /// بەشی ئەپەکە کە شوێنەکەی تێدا زیاد دەکرێت (`null` = هێشتا دیاری نەکراوە)
  String? category;

  /// گەڕەک بەپێی سنوورەکان (`null` = دەرەوەی هەموو گەڕەکەکان)
  String? neighborhood;
  bool selected;
}

/// فلتەرەکانی لیستی هێنان. `null` واتە «هەموو»؛ [none] واتە «بێ بەش / دەرەوەی گەڕەک».
class OsmImportFilter {
  const OsmImportFilter({
    this.query = '',
    this.category,
    this.kind,
    this.neighborhood,
    this.onlyNew = true,
    this.hasPhone = false,
    this.governmentOnly = false,
    this.selectedOnly = false,
  });

  static const String none = '\u0000none';

  final String query;
  final String? category;
  final String? kind;
  final String? neighborhood;
  final bool onlyNew;
  final bool hasPhone;
  final bool governmentOnly;
  final bool selectedOnly;

  /// چەند فلتەر چالاکە (بێ «تەنها نوێکان» کە بنەڕەتییە)
  int get activeCount =>
      (query.trim().isEmpty ? 0 : 1) +
      (category == null ? 0 : 1) +
      (kind == null ? 0 : 1) +
      (neighborhood == null ? 0 : 1) +
      (hasPhone ? 1 : 0) +
      (governmentOnly ? 1 : 0) +
      (selectedOnly ? 1 : 0);

  OsmImportFilter copyWith({
    String? query,
    String? Function()? category,
    String? Function()? kind,
    String? Function()? neighborhood,
    bool? onlyNew,
    bool? hasPhone,
    bool? governmentOnly,
    bool? selectedOnly,
  }) =>
      OsmImportFilter(
        query: query ?? this.query,
        category: category != null ? category() : this.category,
        kind: kind != null ? kind() : this.kind,
        neighborhood: neighborhood != null ? neighborhood() : this.neighborhood,
        onlyNew: onlyNew ?? this.onlyNew,
        hasPhone: hasPhone ?? this.hasPhone,
        governmentOnly: governmentOnly ?? this.governmentOnly,
        selectedOnly: selectedOnly ?? this.selectedOnly,
      );

  /// تەنها «تەنها نوێکان» دەهێڵێتەوە
  OsmImportFilter cleared() => OsmImportFilter(onlyNew: onlyNew);

  bool matches(OsmImportRow r) {
    if (onlyNew && r.match == OsmMatch.same) return false;
    if (hasPhone && (r.place.phone ?? '').trim().isEmpty) return false;
    if (governmentOnly && !r.place.isGovernment) return false;
    if (selectedOnly && !r.selected) return false;
    if (category != null && (r.category ?? none) != category) return false;
    if (kind != null && r.place.kind != kind) return false;
    if (neighborhood != null && (r.neighborhood ?? none) != neighborhood) {
      return false;
    }
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      final hay = '${r.place.name} ${r.place.address ?? ''} ${r.place.kind}'
          .toLowerCase();
      if (!hay.contains(q)) return false;
    }
    return true;
  }

  List<OsmImportRow> apply(Iterable<OsmImportRow> rows) =>
      rows.where(matches).toList();

  /// `(بەها، ژمارە)` بۆ هەڵبژێرەکان — زۆرترین لە پێشەوە، [none] لە کۆتایی
  static List<MapEntry<String, int>> counts(
    Iterable<OsmImportRow> rows,
    String? Function(OsmImportRow) keyOf,
  ) {
    final map = <String, int>{};
    for (final r in rows) {
      final k = keyOf(r) ?? none;
      map[k] = (map[k] ?? 0) + 1;
    }
    return map.entries.toList()
      ..sort((a, b) {
        if (a.key == none) return 1;
        if (b.key == none) return -1;
        final c = b.value.compareTo(a.value);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
  }
}
