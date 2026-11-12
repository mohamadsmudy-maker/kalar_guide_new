import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../../l10n/tr.dart';
import 'complaint_details_pro_sheet.dart';   // ✅ چاککرا

/// 🗺️ نەخشەی گشتی سکاڵاکان (Pro Version)
class AllComplaintsMapScreen extends StatefulWidget {
  const AllComplaintsMapScreen({super.key});

  @override
  State<AllComplaintsMapScreen> createState() =>
      _AllComplaintsMapScreenState();
}

class _AllComplaintsMapScreenState extends State<AllComplaintsMapScreen> {
  gmaps.GoogleMapController? _mapController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allComplaints = [];
  Set<gmaps.Marker> _markers = {};
  gmaps.MapType _currentMapType = gmaps.MapType.normal;
  String _selectedStatusFilter = 'all';
  String? _selectedComplaintId;

  @override
  void initState() {
    super.initState();
    _fetchComplaints();
  }

  // ═══════════════════════════════════════════════════════════
  // 📡 هێنانی سکاڵاکان
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchComplaints() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('complaints')
          .select()
          .not('latitude', 'is', null)
          .not('longitude', 'is', null);

      final List<dynamic> rawList = res as List;
      final complaints = rawList
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (mounted) {
        setState(() {
          _allComplaints = complaints;
          _isLoading = false;
        });
        _updateMarkers();
      }
    } catch (e) {
      debugPrint('❌ Fetch error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 فلتەرکردن
  // ═══════════════════════════════════════════════════════════
  List<Map<String, dynamic>> get _filteredComplaints {
    if (_selectedStatusFilter == 'all') return _allComplaints;

    if (_selectedStatusFilter == 'approved') {
      return _allComplaints
          .where((c) =>
      c['status'] == 'approved' || c['status'] == 'in_progress')
          .toList();
    }
    return _allComplaints
        .where((c) => c['status'] == _selectedStatusFilter)
        .toList();
  }

  // ═══════════════════════════════════════════════════════════
  // 📍 دروستکردنی پینەکان
  // ═══════════════════════════════════════════════════════════
  void _updateMarkers() {
    Set<gmaps.Marker> markers = {};

    for (var c in _filteredComplaints) {
      double? lat = double.tryParse(c['latitude']?.toString() ?? '');
      double? lng = double.tryParse(c['longitude']?.toString() ?? '');
      if (lat == null || lng == null) continue;

      String status = c['status'] ?? 'pending';
      double markerHue = gmaps.BitmapDescriptor.hueOrange;
      if (status == 'approved' || status == 'in_progress') {
        markerHue = gmaps.BitmapDescriptor.hueGreen;
      } else if (status == 'completed') {
        markerHue = gmaps.BitmapDescriptor.hueAzure;
      } else if (status == 'rejected') {
        markerHue = gmaps.BitmapDescriptor.hueRed;
      }

      markers.add(
        gmaps.Marker(
          markerId: gmaps.MarkerId(c['id'].toString()),
          position: gmaps.LatLng(lat, lng),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(markerHue),
          infoWindow: gmaps.InfoWindow(
            title: c['title'] ?? tr('سکاڵا'),
            snippet: "کلیک بکە بۆ وردەکاری",
          ),
          onTap: () {
            setState(() => _selectedComplaintId = c['id'].toString());
            _showComplaintDetails(c);
          },
        ),
      );
    }

    if (mounted) {
      setState(() => _markers = markers);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 پیشاندانی وردەکاری
  // ═══════════════════════════════════════════════════════════
  void _showComplaintDetails(Map<String, dynamic> complaint) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ComplaintDetailsProSheet(   // ✅ چاککرا
        complaint: complaint,
        onStatusChanged: () {
          _fetchComplaints();
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Helpers
  // ═══════════════════════════════════════════════════════════
  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFD9822B);
      case 'approved':
      case 'in_progress':
        return const Color(0xFF0F9D7A);
      case 'rejected':
        return const Color(0xFFDC3545);
      case 'completed':
        return const Color(0xFF1E88E5);
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'pending':
        return 'چاوەڕوان';
      case 'approved':
        return 'پەسەندکراو';
      case 'in_progress':
        return 'لە ئارادایە';
      case 'rejected':
        return 'ڕەتکراو';
      case 'completed':
        return 'جێبەجێکرا';
      default:
        return '';
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1B2E),
        body: Stack(
          children: [
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            else
              gmaps.GoogleMap(
                initialCameraPosition: const gmaps.CameraPosition(
                  target: gmaps.LatLng(34.6189, 45.3156),
                  zoom: 14,
                ),
                mapType: _currentMapType,
                markers: _markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: false,
                onMapCreated: (controller) => _mapController = controller,
              ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1B2E), Color(0xFF2D2A45)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tr("نەخشەی گشتی سکاڵاکان"),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentMapType = _currentMapType ==
                              gmaps.MapType.satellite
                              ? gmaps.MapType.normal
                              : gmaps.MapType.satellite;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _currentMapType == gmaps.MapType.satellite
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _currentMapType == gmaps.MapType.satellite
                              ? Icons.map_rounded
                              : Icons.satellite_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 12,
              right: 12,
              child: SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildFilterChip(
                      'هەموو',
                      'all',
                      Icons.apps_rounded,
                      Colors.white,
                    ),
                    _buildFilterChip(
                      'چاوەڕوان',
                      'pending',
                      Icons.hourglass_top_rounded,
                      const Color(0xFFD9822B),
                    ),
                    _buildFilterChip(
                      'پەسەندکراو',
                      'approved',
                      Icons.verified_rounded,
                      const Color(0xFF0F9D7A),
                    ),
                    _buildFilterChip(
                      'جێبەجێکرا',
                      'completed',
                      Icons.check_circle_rounded,
                      const Color(0xFF1E88E5),
                    ),
                    _buildFilterChip(
                      'ڕەتکراو',
                      'rejected',
                      Icons.cancel_rounded,
                      const Color(0xFFDC3545),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: _selectedComplaintId != null ? 220 : 100,
              left: 12,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('ڕەنگەکان:'),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildLegendItem(
                      const Color(0xFFD9822B),
                      'چاوەڕوان',
                    ),
                    _buildLegendItem(
                      const Color(0xFF0F9D7A),
                      'پەسەندکراو',
                    ),
                    _buildLegendItem(
                      const Color(0xFF1E88E5),
                      'جێبەجێکرا',
                    ),
                    _buildLegendItem(
                      const Color(0xFFDC3545),
                      'ڕەتکراو',
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: _selectedComplaintId != null ? 220 : 100,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  _mapController?.animateCamera(
                    gmaps.CameraUpdate.newLatLngZoom(
                      const gmaps.LatLng(34.6189, 45.3156),
                      14,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.center_focus_strong_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
              ),
            ),
            if (_selectedComplaintId != null)
              Positioned(
                bottom: 90,
                left: 16,
                right: 16,
                child: _buildSelectedComplaintCard(),
              ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1B2E), Color(0xFF2D2A45)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.assignment_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('سکاڵاکان لەسەر نەخشە'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            trf('{0} سکاڵا', [_filteredComplaints.length]),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedStatusFilter != 'all')
                      GestureDetector(
                        onTap: () {
                          setState(() => _selectedStatusFilter = 'all');
                          _updateMarkers();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                tr('سڕینەوە'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
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
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedComplaintCard() {
    final complaint = _allComplaints.firstWhere(
          (c) => c['id'].toString() == _selectedComplaintId,
      orElse: () => {},
    );
    if (complaint.isEmpty) return const SizedBox.shrink();

    String status = complaint['status'] ?? 'pending';
    Color statusColor = _getStatusColor(status);
    String statusLabel = _getStatusLabel(status);

    return GestureDetector(
      onTap: () => _showComplaintDetails(complaint),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: statusColor, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.circle,
                        color: Colors.white,
                        size: 8,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tr(statusLabel),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () =>
                      setState(() => _selectedComplaintId = null),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (complaint['images'] != null &&
                    complaint['images'] is List &&
                    (complaint['images'] as List).isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: OptimizedNetworkImage(
                      imageUrl:
                      (complaint['images'] as List).first.toString(),
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(complaint['title'] ?? ''),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: Color(0xFF1A1A2E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        trf('📍 {0}', [tr(complaint['responsible_authority'] ?? 'کەلار')]),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
      String label,
      String value,
      IconData icon,
      Color color,
      ) {
    bool isSelected = _selectedStatusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedStatusFilter = value);
          _updateMarkers();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : color,
                size: 14,
              ),
              const SizedBox(width: 5),
              Text(
                tr(label),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            tr(label),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}