import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../config/app_colors.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../../services/ai_service.dart';
import 'all_complaints_map.dart';

/// 📋 شاشەی بەڕێوەبردنی سکاڵاکان (Pro Version)
class AdminComplaintsScreen extends StatefulWidget {
  const AdminComplaintsScreen({super.key});

  @override
  State<AdminComplaintsScreen> createState() => _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState extends State<AdminComplaintsScreen> {
  String _filter = 'all';
  String _q = '';
  List<Map<String, dynamic>> _complaints = [];
  bool _loading = true;
  bool _generatingPdf = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchComplaints();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchComplaints() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('complaints')
          .select()
          .order('created_at', ascending: false);

      final List<dynamic> rawList = res as List;
      final complaints = rawList
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (mounted) {
        setState(() {
          _complaints = complaints;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _allCount => _complaints.length;
  int get _pendingCount =>
      _complaints.where((c) => c['status'] == 'pending').length;
  int get _approvedCount => _complaints
      .where((c) =>
  c['status'] == 'approved' || c['status'] == 'in_progress')
      .length;
  int get _rejectedCount =>
      _complaints.where((c) => c['status'] == 'rejected').length;
  int get _completedCount =>
      _complaints.where((c) => c['status'] == 'completed').length;

  List<Map<String, dynamic>> get _list {
    var l = _complaints;
    if (_filter != 'all') {
      if (_filter == 'approved') {
        l = l
            .where((c) =>
        c['status'] == 'approved' || c['status'] == 'in_progress')
            .toList();
      } else {
        l = l.where((c) => c['status'] == _filter).toList();
      }
    }
    if (_q.isNotEmpty) {
      l = l.where((c) {
        final searchText =
        "${c['title']}${c['description']}${c['responsible_authority']}"
            .toLowerCase();
        return searchText.contains(_q);
      }).toList();
    }
    return l;
  }

  Color _color(String? s) {
    switch (s) {
      case 'pending':
        return const Color(0xFFFF9800);
      case 'approved':
      case 'in_progress':
        return const Color(0xFF2ECC71);
      case 'rejected':
        return const Color(0xFFE74C3C);
      case 'completed':
        return const Color(0xFF3498DB);
      default:
        return Colors.grey;
    }
  }

  IconData _icon(String? s) {
    switch (s) {
      case 'pending':
        return Icons.hourglass_top_rounded;
      case 'approved':
      case 'in_progress':
        return Icons.verified_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _text(String? s) {
    switch (s) {
      case 'pending':
        return 'چاوەڕوان';
      case 'approved':
        return 'پەسەندکراو';
      case 'in_progress':
        return 'لە ئارادایە';
      case 'rejected':
        return 'ڕەتکراوە';
      case 'completed':
        return 'جێبەجێکرا';
      default:
        return s ?? '';
    }
  }

  Future<void> _generatePdfReport() async {
    setState(() => _generatingPdf = true);
    try {
      String summaryContext = _list
          .map((c) =>
      "جۆر: ${c['title']}, لایەن: ${c['responsible_authority']}, دۆخ: ${_text(c['status'])}")
          .join('\n');

      String aiAnalysis = "شیکردنەوە بەردەست نییە";
      try {
        aiAnalysis = await AiService.askAdminAI(
          "ئەم کورتەیەی سکاڵاکان شیکار بکە و تەنها ٣ خاڵی گرنگ بە کوردی سۆرانی بنووسە:",
          summaryContext,
        );
      } catch (_) {}

      final pdf = pw.Document();
      final font = await PdfGoogleFonts.amiriRegular();
      final fontBold = await PdfGoogleFonts.amiriBold();

      final headers = [
        'ژمارە',
        'جۆری سکاڵا',
        'لایەنی پەیوەندیدار',
        'بەروار',
        'دۆخ',
      ];

      final data = _list.asMap().entries.map((entry) {
        int index = entry.key + 1;
        var c = entry.value;
        String dateStr = c['created_at'] != null
            ? c['created_at'].toString().substring(0, 10)
            : '';

        return [
          index.toString(),
          c['title'] ?? '-',
          c['responsible_authority'] ?? '-',
          dateStr,
          _text(c['status']),
        ];
      }).toList();

      pdf.addPage(
        pw.MultiPage(
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          header: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 15),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'ڕاپۆرتی زیرەکی سکاڵاکان - ڕێبەری کەلار',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 16,
                    color: PdfColors.indigo900,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Divider(color: PdfColors.grey400),
              ],
            ),
          ),
          build: (context) => [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'کۆی گشتی: ${_list.length} سکاڵا',
                  style: pw.TextStyle(font: fontBold, fontSize: 11),
                ),
                pw.Text(
                  'بەروار: ${DateTime.now().toString().substring(0, 10)}',
                  style: pw.TextStyle(font: font, fontSize: 10),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.purple50,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.purple200),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '🤖 شیکردنەوەی زیرەک (AI Summary):',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 11,
                      color: PdfColors.purple900,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    aiAnalysis,
                    style: pw.TextStyle(font: font, fontSize: 10),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: data,
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(
                font: fontBold,
                color: PdfColors.white,
                fontSize: 10,
              ),
              headerDecoration:
              const pw.BoxDecoration(color: PdfColors.indigo900),
              cellAlignment: pw.Alignment.centerRight,
              cellStyle: pw.TextStyle(font: font, fontSize: 9),
              oddRowDecoration:
              const pw.BoxDecoration(color: PdfColors.grey100),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'ڕاپۆرتی_سکاڵاکان_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("هەڵە: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  Future<void> _deleteComplaint(Map<String, dynamic> complaint) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("سڕینەوەی سکاڵا 🗑"),
          content: const Text("ئایا دڵنیایت لە سڕینەوەی ئەم سکاڵایە؟"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("نەخێر"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("سڕینەوە"),
            ),
          ],
        ),
      ),
    );
    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('complaints')
            .delete()
            .eq('id', complaint['id']);
        setState(() {
          _complaints.removeWhere(
                (c) => c['id'].toString() == complaint['id'].toString(),
          );
        });
      } catch (_) {}
    }
  }

  void _showComplaintDetails(Map<String, dynamic> c) {
    showDialog(
      context: context,
      builder: (ctx) => ComplaintDetailsDialog(
        complaint: c,
        onStatusChanged: _fetchComplaints,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        body: CustomScrollView(
          slivers: [
            // ═══════════════════════════════════════
            // 🎨 AppBar + Stats
            // ═══════════════════════════════════════
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              backgroundColor: const Color(0xFF1E1B2E),
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                // 🗺️ دوگمەی نەخشە
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AllComplaintsMapScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3498DB), Color(0xFF2980B9)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3498DB)
                                .withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.map_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Text(
                            "نەخشە",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // 📄 دوگمەی PDF
                IconButton(
                  icon: _generatingPdf
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Colors.redAccent,
                  ),
                  tooltip: "ڕاپۆرتی PDF",
                  onPressed: _generatingPdf ? null : _generatePdfReport,
                ),
                // 🔄 دوگمەی نوێکردنەوە
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _fetchComplaints,
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
                                  color: AppColors.primary
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.assignment_late_rounded,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                "بەڕێوەبردنی سکاڵاکان",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              _buildStatItem(
                                _allCount.toString(),
                                "هەموو",
                                Colors.white,
                                'all',
                              ),
                              _buildStatItem(
                                _pendingCount.toString(),
                                "چاوەڕوان",
                                const Color(0xFFFF9800),
                                'pending',
                              ),
                              _buildStatItem(
                                _approvedCount.toString(),
                                "پەسەندکراو",
                                const Color(0xFF2ECC71),
                                'approved',
                              ),
                              _buildStatItem(
                                _rejectedCount.toString(),
                                "ڕەتکراو",
                                const Color(0xFFE74C3C),
                                'rejected',
                              ),
                              _buildStatItem(
                                _completedCount.toString(),
                                "جێبەجێکرا",
                                const Color(0xFF3498DB),
                                'completed',
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

            // ═══════════════════════════════════════
            // 🔍 گەڕان
            // ═══════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                    onChanged: (v) => setState(() => _q = v.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: "گەڕان بەدوای ناوەڕۆک، لایەنی پەیوەندیدار...",
                      hintStyle: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      suffixIcon: _q.isNotEmpty
                          ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _q = '');
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

            // ═══════════════════════════════════════
            // 📊 ژمارەی ئەنجام
            // ═══════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.assignment_rounded,
                            color: AppColors.primary,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "${_list.length} سکاڵا",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (_filter != 'all')
                      GestureDetector(
                        onTap: () => setState(() => _filter = 'all'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Colors.black54,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "لابردنی فلتەر",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ═══════════════════════════════════════
            // 📋 لیستی سکاڵاکان
            // ═══════════════════════════════════════
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_list.isEmpty)
              SliverFillRemaining(child: _buildEmptyState())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildComplaintCard(_list[index]),
                    childCount: _list.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String count,
      String label,
      Color color,
      String filterKey,
      ) {
    final bool isSelected = _filter == filterKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = filterKey),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: color, width: 1.5)
                : null,
          ),
          child: Column(
            children: [
              Text(
                count,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComplaintCard(Map<String, dynamic> complaint) {
    final status = complaint['status'] ?? 'pending';
    final color = _color(status);
    final icon = _icon(status);
    final statusText = _text(status);

    List images = [];
    try {
      if (complaint['images'] is List) {
        images = complaint['images'];
      } else if (complaint['images'] is String) {
        images = [complaint['images']];
      }
    } catch (_) {}

    String date = complaint['created_at'] != null
        ? complaint['created_at'].toString().substring(0, 10)
        : '';

    String authority = complaint['responsible_authority'] ?? 'نەدیاریکراو';

    return GestureDetector(
      onTap: () => _showComplaintDetails(complaint),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (images.isNotEmpty)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: OptimizedNetworkImage(
                      imageUrl: images.first.toString(),
                      width: double.infinity,
                      height: 160,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, color: Colors.white, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 12,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          date,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      date,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    complaint['title'] ?? 'بێ ناونیشان',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: Color(0xFF1A1A2E),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.account_balance_rounded,
                          color: Colors.indigo,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            authority,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.indigo,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (complaint['description'] != null &&
                      complaint['description'].toString().isNotEmpty)
                    Text(
                      complaint['description'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showComplaintDetails(complaint),
                          child: Container(
                            padding:
                            const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.primary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.visibility_rounded,
                                  color: AppColors.primary,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  "وردەکاری",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _deleteComplaint(complaint),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.delete_rounded,
                            color: Colors.red,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.primary.withValues(alpha: 0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assignment_outlined,
              size: 70,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "هیچ سکاڵایەک نەدۆزرایەوە 📭",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "لەم فلتەرەدا هیچ سکاڵایەک نییە",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🎨 دیالۆگی وردەکاری سکاڵا (PUBLIC)
// ═══════════════════════════════════════════════════════════
class ComplaintDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> complaint;
  final VoidCallback? onStatusChanged;

  const ComplaintDetailsDialog({
    super.key,
    required this.complaint,
    this.onStatusChanged,
  });

  /// 🖼️ پیشاندانی وێنە بە گەورەی (Full Screen + Zoom)
  void _showFullScreenImage(
      BuildContext context,
      String imageUrl,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(
          imageUrl: imageUrl,
        ),
      ),
    );
  }

  /// ✅ پەسەندکردن + ناردنی WhatsApp + Notification خۆکار
  Future<void> _approveAndSend(BuildContext context) async {
    try {
      String imageUrl = '';
      if (complaint['images'] != null) {
        List imgs = complaint['images'] is List
            ? complaint['images']
            : [complaint['images']];
        if (imgs.isNotEmpty) imageUrl = imgs.first.toString();
      }

      double? lat = double.tryParse(complaint['latitude']?.toString() ?? '');
      double? lng = double.tryParse(complaint['longitude']?.toString() ?? '');
      String mapLink = (lat != null && lng != null)
          ? 'https://maps.google.com/?q=$lat,$lng'
          : 'لۆکەیشن بەردەست نییە';

      String message = "📢 *سکاڵای نوێ بۆ جێبەجێکردن*\n\n"
          "🔹 جۆر: ${complaint['title']}\n"
          "📝 ڕوونکردنەوە: ${complaint['description']}\n\n"
          "🖼 وێنەی کێشە: $imageUrl\n\n"
          "📍 لۆکەیشن: $mapLink";

      final whatsappUrl = Uri.parse(
        "https://wa.me/?text=${Uri.encodeComponent(message)}",
      );
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      }

      // ✅ گۆڕینی status — Trigger لە Supabase خۆکار Notification دەنێرێت
      await Supabase.instance.client
          .from('complaints')
          .update({'status': 'in_progress'}).eq('id', complaint['id']);

      if (context.mounted) {
        Navigator.pop(context);
        onStatusChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "سکاڵا پەسەندکرا ✅ — Notification نێردرا بۆ هاوڵاتی",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("هەڵە: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// ✅ تەواوکردن + Notification خۆکار
  Future<void> _markCompleted(BuildContext context) async {
    try {
      await Supabase.instance.client
          .from('complaints')
          .update({'status': 'completed'}).eq('id', complaint['id']);

      if (context.mounted) {
        Navigator.pop(context);
        onStatusChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "سکاڵا جێبەجێکرا ✅ — Notification نێردرا",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("هەڵە: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// ❌ ڕەتکردنەوە + Notification خۆکار
  Future<void> _reject(BuildContext context) async {
    try {
      await Supabase.instance.client
          .from('complaints')
          .update({'status': 'rejected'}).eq('id', complaint['id']);

      if (context.mounted) {
        Navigator.pop(context);
        onStatusChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.cancel_rounded, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "سکاڵا ڕەتکرایەوە ❌ — Notification نێردرا",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("هەڵە: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String status = complaint['status'] ?? 'pending';
    double? lat = double.tryParse(complaint['latitude']?.toString() ?? '');
    double? lng = double.tryParse(complaint['longitude']?.toString() ?? '');

    List images = [];
    try {
      if (complaint['images'] is List) {
        images = complaint['images'];
      } else if (complaint['images'] is String) {
        images = [complaint['images']];
      }
    } catch (_) {}

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🎯 Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1B2E), Color(0xFF2D2A45)],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.assignment_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        "وردەکاری سکاڵا",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 📄 ناوەڕۆک
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🖼️ وێنەکان
                      if (images.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.photo_library_rounded,
                              color: AppColors.primary,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              "وێنەکانی کێشە (کلیک بکە بۆ گەورەکردنەوە)",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 140,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: images.length,
                            itemBuilder: (ctx, i) => GestureDetector(
                              onTap: () => _showFullScreenImage(
                                context,
                                images[i].toString(),
                              ),
                              child: Container(
                                width: 140,
                                margin: const EdgeInsets.only(left: 8),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius:
                                      BorderRadius.circular(12),
                                      child: OptimizedNetworkImage(
                                        imageUrl: images[i].toString(),
                                        width: 140,
                                        height: 140,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding:
                                        const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.6),
                                          borderRadius:
                                          BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.zoom_in_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 🗺️ نەخشە
                      if (lat != null && lng != null) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              color: Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              "شوێن لەسەر نەخشە",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 160,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.grey.shade300),
                            boxShadow: [
                              BoxShadow(
                                color:
                                Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: gmaps.GoogleMap(
                              initialCameraPosition: gmaps.CameraPosition(
                                target: gmaps.LatLng(lat, lng),
                                zoom: 16,
                              ),
                              markers: {
                                gmaps.Marker(
                                  markerId: const gmaps.MarkerId('loc'),
                                  position: gmaps.LatLng(lat, lng),
                                  icon: gmaps.BitmapDescriptor
                                      .defaultMarkerWithHue(
                                    gmaps.BitmapDescriptor.hueRed,
                                  ),
                                ),
                              },
                              zoomControlsEnabled: false,
                              scrollGesturesEnabled: false,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 📋 زانیاری
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow(
                              'جۆری سکاڵا',
                              complaint['title'] ?? '-',
                              Icons.category_rounded,
                              Colors.purple,
                            ),
                            const Divider(height: 16),
                            _buildInfoRow(
                              'لایەنی پەیوەندیدار',
                              complaint['responsible_authority'] ?? '-',
                              Icons.account_balance_rounded,
                              Colors.indigo,
                            ),
                            if (complaint['description'] != null &&
                                complaint['description']
                                    .toString()
                                    .isNotEmpty) ...[
                              const Divider(height: 16),
                              _buildInfoRow(
                                'ڕوونکردنەوە',
                                complaint['description'],
                                Icons.description_rounded,
                                Colors.teal,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 🎯 دوگمەکانی کردار
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (status == 'pending') ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2ECC71),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                              ),
                              onPressed: () => _approveAndSend(context),
                              icon: const Icon(Icons.check_rounded,
                                  size: 18),
                              label: const Text(
                                "پەسەندکردن",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                              ),
                              onPressed: () => _reject(context),
                              icon: const Icon(Icons.close_rounded,
                                  size: 18),
                              label: const Text(
                                "ڕەتکردنەوە",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (status == 'in_progress' ||
                        status == 'approved') ...[
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3498DB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _markCompleted(context),
                          icon: const Icon(
                              Icons.check_circle_rounded,
                              size: 18),
                          label: const Text(
                            "تەواوکردن و جێبەجێکردن ✅",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ] else if (status == 'completed') ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Colors.green,
                              size: 20,
                            ),
                            SizedBox(width: 6),
                            Text(
                              "ئەم سکاڵایە جێبەجێکراوە ✅",
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (status == 'rejected') ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cancel_rounded,
                              color: Colors.red,
                              size: 20,
                            ),
                            SizedBox(width: 6),
                            Text(
                              "ئەم سکاڵایە ڕەتکراوەتەوە ❌",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      String label,
      String value,
      IconData icon,
      Color color,
      ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🖼️ شاشەی بینینی وێنە بە گەورەی (PUBLIC)
// ═══════════════════════════════════════════════════════════
class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;

  const FullScreenImageViewer({super.key, required this.imageUrl});

  @override
  State<FullScreenImageViewer> createState() =>
      _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  final TransformationController _transformationController =
  TransformationController();
  bool _isZoomed = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
    setState(() => _isZoomed = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "بینینی وێنە",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        actions: [
          if (_isZoomed)
            IconButton(
              icon: const Icon(Icons.zoom_out_map_rounded),
              tooltip: "گەڕاندنەوە بۆ شێوازی ئاسایی",
              onPressed: _resetZoom,
            ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: GestureDetector(
        onDoubleTap: () {
          if (_isZoomed) {
            _resetZoom();
          } else {
            _transformationController.value = Matrix4.identity()
              ..scale(2.5);
            setState(() => _isZoomed = true);
          }
        },
        child: Center(
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.5,
            maxScale: 5.0,
            panEnabled: true,
            scaleEnabled: true,
            child: OptimizedNetworkImage(
              imageUrl: widget.imageUrl,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        color: Colors.black,
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.pinch_rounded,
                      color: Colors.white70,
                      size: 14,
                    ),
                    SizedBox(width: 6),
                    Text(
                      "بە دوو پەنجە گەورە بکە • دوو کلیک بۆ Zoom",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}