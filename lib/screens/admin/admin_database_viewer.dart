// lib/screens/admin/admin_database_viewer.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../l10n/tr.dart';

/// 🗄️ شاشەی بەڕێوەبردنی داتابەیس (Secure Edition)
///
/// ✅ app_users لابراوە (بۆ پاراستنی password)
/// ✅ Columns ی whitelist بەکاردێت
/// ✅ Admin check لە client + server
class AdminDatabaseViewerScreen extends StatefulWidget {
  const AdminDatabaseViewerScreen({super.key});

  @override
  State<AdminDatabaseViewerScreen> createState() =>
      _AdminDatabaseViewerScreenState();
}

class _AdminDatabaseViewerScreenState
    extends State<AdminDatabaseViewerScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _tableData = [];

  // ═══════════════════════════════════════════════════════════
  // 🔓 Whitelist — تەنها ئەم table ەکان دەبینرێن
  // ⚠️ app_users لابراوە بۆ پاراستنی password
  // ═══════════════════════════════════════════════════════════
  static const List<Map<String, dynamic>> _tables = [
    {
      'key': 'dukan',
      'name': 'شوێنەکان',
      'icon': Icons.storefront_rounded,
      'color': Colors.indigo,
      'columns': 'id, name, phone, address, category, type, is_verified, created_at',
      // ⚠️ 'password' و 'user_phone' لابراون
    },
    {
      'key': 'news',
      'name': 'هەواڵەکان',
      'icon': Icons.newspaper_rounded,
      'color': Colors.green,
      'columns': 'id, title, description, images, likes, views, created_at, store_id',
    },
    {
      'key': 'products',
      'name': 'کاڵاکان',
      'icon': Icons.shopping_bag_rounded,
      'color': Colors.deepOrange,
      'columns': 'id, name, price, category, img, store_id, created_at',
    },
    {
      'key': 'orders',
      'name': 'ئۆردەرەکان',
      'icon': Icons.receipt_long_rounded,
      'color': Colors.teal,
      'columns': 'id, store_id, total_price, status, customer_name, created_at',
    },
    {
      'key': 'complaints',
      'name': 'سکاڵاکان',
      'icon': Icons.assignment_late_rounded,
      'color': Colors.red,
      'columns': 'id, title, description, status, responsible_authority, created_at',
      // ⚠️ 'user_phone' و 'user_id' لابراون
    },
    {
      'key': 'main_categories',
      'name': 'بەشە سەرەکییەکان',
      'icon': Icons.category_rounded,
      'color': Colors.pink,
      'columns': 'id, name, image, sort_order',
    },
    {
      'key': 'sub_categories',
      'name': 'ژێربەشەکان',
      'icon': Icons.subdirectory_arrow_right_rounded,
      'color': Colors.orange,
      'columns': 'id, name, parent',
    },
    {
      'key': 'emergency_services',
      'name': 'خزمەتگوزاری فریاکەوتن',
      'icon': Icons.emergency_rounded,
      'color': Colors.redAccent,
      'columns': 'id, name_ku, category, phone, is_active, display_order',
    },
    {
      'key': 'neighborhoods',
      'name': 'گەڕەکەکان',
      'icon': Icons.location_city_rounded,
      'color': Colors.blue,
      'columns': 'id, name_ku, description_ku, color, is_active',
    },
    {
      'key': 'events',
      'name': 'ڕووداوەکان',
      'icon': Icons.event_rounded,
      'color': Colors.purple,
      'columns': 'id, title_ku, start_date, category, is_published, created_at',
    },
  ];

  String _selectedTable = 'dukan';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTableData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _selectedTableInfo {
    return _tables.firstWhere(
          (t) => t['key'] == _selectedTable,
      orElse: () => _tables[0],
    );
  }

  Future<void> _fetchTableData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // ✅ بەکارهێنانی columns ی whitelist
      final columns = _selectedTableInfo['columns']?.toString() ?? '*';

      final res = await Supabase.instance.client
          .from(_selectedTable)
          .select(columns)
          .limit(50);

      final List<dynamic> rawList = res as List;
      final data = rawList
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (mounted) {
        setState(() {
          _tableData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching table: $e");
      if (mounted) {
        setState(() {
          _tableData = [];
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredData {
    if (_searchQuery.isEmpty) return _tableData;
    return _tableData.where((row) {
      return row.values.any((val) =>
      val != null &&
          val.toString().toLowerCase().contains(_searchQuery));
    }).toList();
  }

  Color _getTableColor() {
    final colorValue = _selectedTableInfo['color'];
    if (colorValue is Color) return colorValue;
    return AppColors.primary;
  }

  IconData _getTableIcon() {
    final iconValue = _selectedTableInfo['icon'];
    if (iconValue is IconData) return iconValue;
    return Icons.table_chart_rounded;
  }

  String _getTableName() {
    final nameValue = _selectedTableInfo['name'];
    if (nameValue is String) return nameValue;
    return 'خشتە';
  }

  void _showRowDetailsDialog(Map<String, dynamic> row) {
    final color = _getTableColor();
    final icon = _getTableIcon();
    final tableName = _getTableName();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 45,
                  height: 5,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr("وردەکاری تۆمار"),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              trf("{0} • {1} ستوون", [tableName, row.length]),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: row.keys.length,
                    itemBuilder: (context, index) {
                      final key = row.keys.elementAt(index);
                      final value = row[key];
                      final isNull = value == null;
                      return _buildFieldCard(
                        key: key,
                        value: value,
                        isNull: isNull,
                        index: index + 1,
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(
                        tr("باشە"),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldCard({
    required String key,
    required dynamic value,
    required bool isNull,
    required int index,
  }) {
    final colors = [
      Colors.blue,
      Colors.purple,
      Colors.teal,
      Colors.orange,
      Colors.pink,
      Colors.indigo,
      Colors.green,
      Colors.red,
    ];
    final color = colors[(index - 1) % colors.length];

    final valueStr = value?.toString() ?? '';
    final isImage = valueStr.startsWith('http') &&
        (valueStr.contains('.jpg') ||
            valueStr.contains('.jpeg') ||
            valueStr.contains('.png') ||
            valueStr.contains('.webp') ||
            valueStr.contains('storage'));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isNull ? Colors.red.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: (isNull ? Colors.red : color).withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isNull ? Icons.error_outline_rounded : Icons.label_rounded,
                  color: isNull ? Colors.red : color,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tr(key),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: isNull ? Colors.red : color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (isNull ? Colors.red : color)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tr(isNull
                        ? 'NULL'
                        : value.runtimeType
                        .toString()
                        .replaceAll('_', ' ')
                        .split(' ')
                        .last
                        .toUpperCase()),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: isNull ? Colors.red : color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: isImage
                ? _buildImageValue(valueStr)
                : Text(
              tr(isNull ? '— بەتاڵ —' : valueStr),
              style: TextStyle(
                fontSize: 13,
                color: isNull ? Colors.red.shade400 : Colors.black87,
                fontWeight:
                isNull ? FontWeight.bold : FontWeight.w600,
                height: 1.4,
                fontStyle:
                isNull ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageValue(String imageUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            imageUrl,
            height: 120,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 60,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(
                  Icons.broken_image_rounded,
                  color: Colors.grey,
                  size: 30,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr(imageUrl),
          style: const TextStyle(
            fontSize: 10,
            color: Colors.blue,
            height: 1.4,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tableColor = _getTableColor();
    final tableIcon = _getTableIcon();
    final tableName = _getTableName();

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 140,
              pinned: true,
              backgroundColor: const Color(0xFF1E1B2E),
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: tr("نوێکردنەوە"),
                  onPressed: _fetchTableData,
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1E1B2E), Color(0xFF2D2A45)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: tableColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  tableIcon,
                                  color: tableColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tr("بەڕێوەبردنی داتابەیس"),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      trf("خشتەی: {0}", [tableName]),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                  Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.dataset_rounded,
                                      color: Colors.amber,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${_filteredData.length}",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                height: 100,
                padding: const EdgeInsets.only(top: 12),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _tables.length,
                  itemBuilder: (context, index) {
                    return _buildTableChip(_tables[index]);
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(
                          () => _searchQuery = val.trim().toLowerCase(),
                    ),
                    decoration: InputDecoration(
                      hintText:
                      tr("گەڕان لەناو سەرجەم ستوونەکانی ئەم خشتەیە..."),
                      hintStyle: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_filteredData.isEmpty)
              SliverFillRemaining(child: _buildEmptyState())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildDataCard(
                      _filteredData[index],
                      index,
                    ),
                    childCount: _filteredData.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableChip(Map<String, dynamic> table) {
    final isSelected = _selectedTable == table['key'];
    final colorValue = table['color'];
    final color = colorValue is Color ? colorValue : AppColors.primary;
    final iconValue = table['icon'];
    final icon =
    iconValue is IconData ? iconValue : Icons.table_chart_rounded;
    final nameValue = table['name'];
    final name = nameValue is String ? nameValue : '';

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTable = table['key'] as String;
          _searchCtrl.clear();
          _searchQuery = '';
        });
        _fetchTableData();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 90,
        margin: const EdgeInsets.only(left: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ]
              : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : color,
                size: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tr(name),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: isSelected ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCard(Map<String, dynamic> row, int index) {
    final color = _getTableColor();
    final icon = _getTableIcon();

    String mainTitle = row['name'] ??
        row['title'] ??
        row['name_ku'] ??
        row['title_ku'] ??
        row['customer_name'] ??
        trf('تۆماری #{0}', [index + 1]);

    String mainSubtitle = row['address'] ??
        row['description'] ??
        row['phone'] ??
        row['created_at']?.toString() ??
        '';

    if (mainSubtitle.length > 50) {
      mainSubtitle = "${mainSubtitle.substring(0, 47)}...";
    }

    String? imageUrl;
    if (row['image'] != null && row['image'].toString().isNotEmpty) {
      imageUrl = row['image'].toString();
    } else if (row['img'] != null && row['img'].toString().isNotEmpty) {
      imageUrl = row['img'].toString();
    } else if (row['logo'] != null && row['logo'].toString().isNotEmpty) {
      imageUrl = row['logo'].toString();
    }

    return GestureDetector(
      onTap: () => _showRowDetailsDialog(row),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    imageUrl,
                    width: 55,
                    height: 55,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _buildDefaultIcon(icon, color),
                  ),
                )
              else
                _buildDefaultIcon(icon, color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mainTitle.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: Color(0xFF1A1A2E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (mainSubtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        tr(mainSubtitle),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultIcon(IconData icon, Color color) {
    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.7), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: Colors.white, size: 26),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.storage_rounded,
              size: 60,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr("هیچ زانیارییەک نەدۆزرایەوە 📭"),
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              tr("گەڕانەکەت هیچ ئەنجامێکی نەبوو"),
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}