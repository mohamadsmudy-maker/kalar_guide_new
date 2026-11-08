// lib/screens/complaints/submit_complaint_ui.dart
// ڕووکاری _SubmitComplaintScreenState — لە submit_complaint.dart جیاکراوەتەوە

part of 'submit_complaint.dart';

extension _SubmitComplaintScreenStateUi on _SubmitComplaintScreenState {
  Widget _sheetHandle() => Container(
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: Colors.grey.shade300,
      borderRadius: BorderRadius.circular(2),
    ),
  );

  Widget _buildSourceCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(tr(label),
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _gradientIcon(IconData icon, List<Color> colors) => Container(
    width: 90,
    height: 90,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(colors: colors),
      boxShadow: [
        BoxShadow(
          color: colors.last.withValues(alpha: 0.35),
          blurRadius: 24,
          spreadRadius: 3,
        ),
      ],
    ),
    child: Icon(icon, color: Colors.white, size: 50),
  );

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      title: Text(
        tr('ناردنی سکاڵای هاوڵاتی'),
        style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
      ),
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          icon: const Icon(Icons.save_rounded),
          tooltip: tr('پاشەکەوتکردنی ڕەشنووس'),
          onPressed: () async {
            await _saveDraft();
            _showSnackBar(tr('💾 ڕەشنووس پاشەکەوت کرا'), const Color(0xFF0F9D7A));
          },
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 Progress
  // ═══════════════════════════════════════════════════════════
  Widget _buildProgressSteps() {
    final labels = ['جۆر', 'وێنە', 'شوێن'];
    final done = [_hasType, _hasImages, _hasLocation];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: List.generate(3, (i) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 2 ? 0 : 6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 5,
                    decoration: BoxDecoration(
                      color: done[i]
                          ? Colors.green.shade500
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ...List.generate(3, (i) {
                return Expanded(
                  child: Row(
                    children: [
                      Icon(
                        done[i]
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 14,
                        color: done[i]
                            ? Colors.green.shade600
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(tr(labels[i]),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: done[i]
                                ? Colors.green.shade700
                                : Colors.grey.shade500,
                          )),
                    ],
                  ),
                );
              }),
              Text(trf('{0} لە ٣', [_ku(_doneCount)]),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Widgets
  // ═══════════════════════════════════════════════════════════
  Widget _buildStepHeader(String step, String title) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(tr(step),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(tr(title),
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A2E))),
        ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    final t = _type;
    final color = t?.color ?? AppColors.primary;

    return InkWell(
      onTap: _showTypeSheet,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: t != null ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: t != null ? color : AppColors.primary.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(t?.icon ?? Icons.search_rounded, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr(t?.name ?? 'جۆری کێشە هەڵبژێرە...'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: t != null ? Colors.black87 : AppColors.primary,
                ),
              ),
            ),
            Text(tr(t != null ? 'گۆڕین' : ''),
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            Icon(Icons.keyboard_arrow_down_rounded, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateInfo() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Column(
        children: [
          Icon(Icons.touch_app_rounded, size: 50, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(tr('تکایە سەرەتا جۆری کێشە هەڵبژێرە'),
              style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
    required List<Color>? gradient,
    Widget? trailing,
  }) {
    final g = gradient;
    final on = g != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: g != null
            ? LinearGradient(
            colors: g,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight)
            : null,
        color: on ? null : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        boxShadow: g != null
            ? [
          BoxShadow(
            color: g.last.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: on
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                color: on ? Colors.white : Colors.grey.shade600, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(label),
                    style: TextStyle(
                        color: on ? Colors.white70 : Colors.grey.shade600,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(tr(value),
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: on ? Colors.white : Colors.grey.shade700,
                        fontSize: 14)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildAuthorityCard() {
    return _infoCard(
      icon: Icons.verified_rounded,
      label: tr('لایەنی پەیوەندیدار'),
      value: _type?.authority ?? '',
      gradient: [Colors.green.shade400, Colors.green.shade600],
    );
  }

  Widget _buildNeighborhoodCard() {
    if (_detectingNeighborhood) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade200, width: 1.5),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF1E88E5)),
            ),
            const SizedBox(width: 12),
            Text(tr('دۆزینەوەی گەڕەک...'),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E88E5),
                    fontSize: 13)),
          ],
        ),
      );
    }

    final has = _neighborhoodName != null && _neighborhoodName!.isNotEmpty;
    return _infoCard(
      icon: Icons.location_city_rounded,
      label: tr('گەڕەک'),
      value: has ? _neighborhoodName! : 'گەڕەک نەدۆزرایەوە',
      gradient: has ? [Colors.blue.shade400, Colors.blue.shade600] : null,
      trailing: has
          ? const Icon(Icons.check_circle_rounded,
          color: Colors.white, size: 22)
          : (_hasLocation
          ? IconButton(
        icon: const Icon(Icons.refresh_rounded),
        onPressed: _detectNeighborhood,
        tooltip: tr('دووبارە بدۆزەرەوە'),
      )
          : null),
    );
  }

  Widget _buildMapSection() {
    final hasFix = _locIssue != _LocIssue.none ||
        (!_hasLocation && !_locationBusy);
    final okColor = _hasLocation ? const Color(0xFF0F9D7A) : const Color(0xFFD9822B);

    return Column(
      children: [
        Container(
          height: 170,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade300, width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                AbsorbPointer(
                  child: gmaps.GoogleMap(
                    initialCameraPosition: gmaps.CameraPosition(
                      target: _hasLocation
                          ? gmaps.LatLng(_lat!, _lng!)
                          : const gmaps.LatLng(34.6189, 45.3156),
                      zoom: 16,
                    ),
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    mapToolbarEnabled: false,
                    scrollGesturesEnabled: false,
                    circles: _hasLocation && (_accuracy ?? 0) > 0
                        ? {
                      gmaps.Circle(
                        circleId: const gmaps.CircleId('accuracy'),
                        center: gmaps.LatLng(_lat!, _lng!),
                        radius: _accuracy!.clamp(5, 200).toDouble(),
                        fillColor: const Color(0xFF1E88E5).withValues(alpha: 0.12),
                        strokeColor: const Color(0xFF1E88E5).withValues(alpha: 0.4),
                        strokeWidth: 1,
                      ),
                    }
                        : {},
                    markers: _hasLocation
                        ? {
                      gmaps.Marker(
                        markerId: const gmaps.MarkerId('current_loc'),
                        position: gmaps.LatLng(_lat!, _lng!),
                        icon: gmaps.BitmapDescriptor
                            .defaultMarkerWithHue(
                            gmaps.BitmapDescriptor.hueRed),
                      ),
                    }
                        : {},
                    onMapCreated: (c) {
                      _mapController = c;
                      if (_hasLocation) {
                        c.moveCamera(gmaps.CameraUpdate.newLatLngZoom(
                            gmaps.LatLng(_lat!, _lng!), 17));
                      }
                    },
                  ),
                ),
                if (_locationBusy)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.6),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Material(
                    color: Colors.white,
                    elevation: 3,
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.my_location_rounded,
                          color: AppColors.primary),
                      tooltip: tr('نوێکردنەوەی شوێن'),
                      onPressed:
                      _locationBusy ? null : _getAutomaticLocation,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: okColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                _hasLocation
                    ? Icons.check_circle_rounded
                    : Icons.access_time_rounded,
                color: okColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(_hasLocation && _accuracy != null
                      ? '$_locationStatusText  (±${_ku(_accuracy!.round())} م)'
                      : _locationStatusText),
                  style: TextStyle(
                      fontSize: 11,
                      color: okColor,
                      fontWeight: FontWeight.bold),
                ),
              ),
              if (hasFix && !_locationBusy)
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 30),
                  ),
                  onPressed: _openLocationFix,
                  child: Text(
                    tr(_locIssue == _LocIssue.serviceOff ||
                        _locIssue == _LocIssue.deniedForever
                        ? 'ڕێکخستن'
                        : 'دووبارە'),
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceConfirmation() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF0F9D7A), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(tr('دەنگەکە تۆمارکرا و ئامادەیە بۆ ناردن'),
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF0F9D7A),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionField() {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: c, width: w),
    );

    return TextField(
      controller: _descCtrl,
      maxLines: 4,
      maxLength: _SubmitComplaintScreenState._maxDescLength,
      textAlign: TextAlign.right,
      textInputAction: TextInputAction.newline,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: tr('ڕووداوەکە لێرە زیاتر باس بکەرەوە...'),
        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        counterStyle: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(bottom: 60),
          child: Icon(Icons.description_outlined, color: AppColors.primary),
        ),
        border: border(Colors.grey.shade300, 1.5),
        enabledBorder: border(Colors.grey.shade300, 1.5),
        focusedBorder: border(AppColors.primary, 2),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _isSubmitting
          ? Container(
        key: const ValueKey('busy'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2.5),
                ),
                const SizedBox(width: 12),
                Text(tr(_submitStage),
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _uploadProgress > 0 ? _uploadProgress : null,
                minHeight: 5,
                color: AppColors.primary,
                backgroundColor: Colors.white,
              ),
            ),
          ],
        ),
      )
          : SizedBox(
        key: const ValueKey('send'),
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _submitComplaint,
          style: ElevatedButton.styleFrom(
            backgroundColor:
            _isReady ? AppColors.primary : Colors.grey.shade500,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)),
            elevation: _isReady ? 4 : 0,
          ),
          icon: const Icon(Icons.send_rounded, size: 22),
          label: Text(tr('ناردنی سکاڵا'),
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: Colors.red.shade300, width: 1.5),
        ),
        onPressed: _isSubmitting ? null : _confirmCancel,
        icon: Icon(Icons.close_rounded, color: Colors.red.shade700, size: 20),
        label: Text(tr('پەشیمانبوونەوە'),
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700)),
      ),
    );
  }
}
