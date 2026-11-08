// lib/screens/map_screen_ui.dart
// ڕووکاری _MapScreenState — لە map_screen.dart جیاکراوەتەوە

part of 'map_screen.dart';

extension _MapScreenStateUi on _MapScreenState {
  Widget _buildLoadingScreen(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => Transform.scale(
                scale: _pulseAnimation.value,
                child: child,
              ),
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E88E5), Color(0xFF4F5BD5)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _MapScreenState._blue.withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(Icons.map_rounded,
                    color: Colors.white, size: 42),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _t('خەریکی بارکردنی گەڕەکان...', 'Loading neighborhoods...'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _t('کەمێک چاوەڕوان بە', 'Please wait a moment'),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Positioned(
      top: 12,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.3),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _fadeController,
            curve: Curves.easeOutCubic,
          )),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A22) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                  spreadRadius: -4,
                ),
              ],
            ),
            child: SearchBarWidget(
              neighborhoods: _all,
              onSelected: _selectNeighborhood,
            ),
          ),
        ),
      ),
    );
  }

  /// چیپی دووری: «١.٢ کم دوورە لە تۆوە»
  Widget _buildDistanceChip(bool isDark) {
    final d = _distanceToSelected();
    return Positioned(
      top: 76,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: d == null
              ? const SizedBox.shrink()
              : Center(
            key: ValueKey(d.round()),
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A35) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: isDark ? 0.35 : 0.14),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.straighten_rounded,
                      size: 16, color: _color(_selected!)),
                  const SizedBox(width: 6),
                  Text(
                    '${_formatDistance(d)} ${_t('دوورە لە تۆوە', 'away')}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color:
                      isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// compass + zoom (لای چەپ)
  Widget _buildLeftControls(bool isDark) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      left: 16,
      bottom: _bottomOffset,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ValueListenableBuilder<CameraPosition>(
            valueListenable: _cam,
            builder: (context, cam, _) {
              final rotated = cam.bearing.abs() > 1 || cam.tilt > 1;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: rotated
                        ? Padding(
                      key: const ValueKey('compass'),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _miniButton(
                        isDark: isDark,
                        onTap: _resetNorth,
                        child: Transform.rotate(
                          angle: -cam.bearing * math.pi / 180,
                          child: const Icon(Icons.navigation_rounded,
                              color: Color(0xFFDC3545), size: 22),
                        ),
                      ),
                    )
                        : const SizedBox.shrink(key: ValueKey('none')),
                  ),
                  _miniButton(
                    isDark: isDark,
                    onTap: () => _zoomBy(1),
                    child: const Icon(Icons.add_rounded, color: _MapScreenState._blue),
                  ),
                  const SizedBox(height: 8),
                  _miniButton(
                    isDark: isDark,
                    onTap: () => _zoomBy(-1),
                    child: const Icon(Icons.remove_rounded, color: _MapScreenState._blue),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _miniButton({
    required bool isDark,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Material(
      color: isDark ? const Color(0xFF1A1A22) : Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 40, height: 40, child: Center(child: child)),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final failed = _loadFailed;

    return Positioned.fill(
      child: Container(
        color: (isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9))
            .withValues(alpha: 0.92),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A22) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  failed ? Icons.wifi_off_rounded : Icons.map_outlined,
                  size: 60,
                  color: _MapScreenState._blue.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  tr(failed
                      ? _t('کێشە لە بارکردنی گەڕەکەکان',
                      'Problem loading neighborhoods')
                      : _t('هیچ گەڕەکێک نەدۆزرایەوە', 'No neighborhoods found')),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(failed
                      ? _t('ئینتەرنێتەکەت بپشکنە و دووبارە هەوڵبدەوە',
                      'Check your connection and try again')
                      : _t('داتای گەڕەکان لە Supabase نەهاتووە',
                      'No data was returned from Supabase')),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    _init();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    _t('دووبارە هەوڵبدەوە', 'Try again'),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _MapScreenState._blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
