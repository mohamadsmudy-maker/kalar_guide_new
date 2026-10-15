import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/fuel_service.dart';
import '../screens/fuel/fuel_chart_screen.dart';

/// 📈 چارتی پرۆفیشناڵی نرخی سووتەمەنی — Preview Widget
/// ✅ RenderFlex Overflow چارەسەرکرا
class FuelChartWidget extends StatelessWidget {
final List<Map<String, dynamic>> history;
final String fuelType;
final bool isDark;

const FuelChartWidget({
super.key,
required this.history,
required this.fuelType,
required this.isDark,
});

@override
Widget build(BuildContext context) {
if (history.isEmpty || history.length < 2) {
return _buildEmptyState();
}

final color = _hexToColor(FuelService.getColorForType(fuelType));

final sorted = List<Map<String, dynamic>>.from(history)
..sort((a, b) {
final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '');
final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '');
if (dateA == null || dateB == null) return 0;
return dateA.compareTo(dateB);
});

final previewData = sorted.length > 8
? sorted.sublist(sorted.length - 8)
: sorted;

final spots = List.generate(previewData.length, (i) {
final price = (previewData[i]['new_price'] as num?)?.toDouble() ?? 0;
return FlSpot(i.toDouble(), price);
});

final prices = spots.map((s) => s.y).toList();
final minPrice = prices.reduce((a, b) => a < b ? a : b);
final maxPrice = prices.reduce((a, b) => a > b ? a : b);
final padding = (maxPrice - minPrice) * 0.2;

final firstPrice = prices.first;
final lastPrice = prices.last;
final diff = lastPrice - firstPrice;


return GestureDetector(
onTap: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => FuelChartScreen(
history: history,
fuelType: fuelType,
),
),
);
},
child: Container(
padding: const EdgeInsets.all(14),
decoration: BoxDecoration(
gradient: LinearGradient(
colors: isDark
? [const Color(0xFF1A1B2E), const Color(0xFF232D3F)]
: [Colors.white, const Color(0xFFF8F9FA)],
begin: Alignment.topLeft,
end: Alignment.bottomRight,
),
borderRadius: BorderRadius.circular(18),
border: Border.all(
color: color.withValues(alpha: 0.3),
width: 1.5,
),
boxShadow: [
BoxShadow(
color: color.withValues(alpha: 0.15),
blurRadius: 15,
offset: const Offset(0, 6),
),
],
),
// ✅ mainAxisSize.min — گرنگترین گۆڕانکاری
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// ═══ Header — height ی سنووردار ═══
SizedBox(
height: 48,
child: Row(
children: [
Container(
padding: const EdgeInsets.all(8),
decoration: BoxDecoration(
gradient: LinearGradient(
colors: [color, color.withValues(alpha: 0.7)],
),
borderRadius: BorderRadius.circular(10),
),
child: const Icon(
Icons.show_chart_rounded,
color: Colors.white,
size: 16,
),
),
const SizedBox(width: 10),
Expanded(
child: Column(
mainAxisSize: MainAxisSize.min,
mainAxisAlignment: MainAxisAlignment.center,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'گۆڕانکاری نرخ',
style: TextStyle(
fontSize: 13,
fontWeight: FontWeight.w900,
color: isDark ? Colors.white : Colors.black87,
),
maxLines: 1,
overflow: TextOverflow.ellipsis,
),
const SizedBox(height: 2),
Text(
'کرتە بکە بۆ بینینی تەواو',
style: TextStyle(
fontSize: 10,
color: isDark ? Colors.white54 : Colors.grey,
),
maxLines: 1,
overflow: TextOverflow.ellipsis,
),
],
),
),
Column(
crossAxisAlignment: CrossAxisAlignment.end,
mainAxisSize: MainAxisSize.min,
mainAxisAlignment: MainAxisAlignment.center,
children: [
Text(
lastPrice.toStringAsFixed(0),
style: TextStyle(
fontSize: 16,
fontWeight: FontWeight.w900,
color: color,
),
),
Text(
'د.ع',
style: TextStyle(
fontSize: 9,
fontWeight: FontWeight.bold,
color: color.withValues(alpha: 0.7),
),
),
],
),
],
),
),

const SizedBox(height: 10),

// ═══ Chart — height ی کەمکراوە ═══
SizedBox(
height: 100,
child: LineChart(
LineChartData(
gridData: const FlGridData(show: false),
titlesData: const FlTitlesData(show: false),
borderData: FlBorderData(show: false),
minX: 0,
maxX: (spots.length - 1).toDouble(),
minY: minPrice - padding,
maxY: maxPrice + padding,
lineTouchData: const LineTouchData(enabled: false),
lineBarsData: [
LineChartBarData(
spots: spots,
isCurved: true,
curveSmoothness: 0.3,
color: color,
barWidth: 3,
isStrokeCapRound: true,
dotData: FlDotData(
show: true,
checkToShowDot: (spot, barData) {
return spot.x == 0 ||
spot.x == spots.length - 1.0;
},
getDotPainter: (spot, percent, bar, index) {
return FlDotCirclePainter(
radius: 4,
color: color,
strokeWidth: 2,
strokeColor: isDark
? const Color(0xFF1A1B2E)
: Colors.white,
);
},
),
belowBarData: BarAreaData(
show: true,
gradient: LinearGradient(
colors: [
color.withValues(alpha: 0.4),
color.withValues(alpha: 0.0),
],
begin: Alignment.topCenter,
end: Alignment.bottomCenter,
),
),
),
],
),
),
),

const SizedBox(height: 8),

// ═══ Mini Stats — height ی سنووردار ═══
Container(
height: 42,
padding: const EdgeInsets.symmetric(
horizontal: 8,
vertical: 4,
),
decoration: BoxDecoration(
color: color.withValues(alpha: 0.05),
borderRadius: BorderRadius.circular(10),
),
child: Row(
children: [
Expanded(
child: _buildMiniStatItem(
'نزمترین',
minPrice,
const Color(0xFF10B981),
isDark,
),
),
Container(
width: 1,
height: 20,
color: isDark
? Colors.white.withValues(alpha: 0.1)
: Colors.grey.shade200,
),
Expanded(
child: _buildMiniStatItem(
'تێکڕا',
prices.reduce((a, b) => a + b) / prices.length,
const Color(0xFF1E88E5),
isDark,
),
),
Container(
width: 1,
height: 20,
color: isDark
? Colors.white.withValues(alpha: 0.1)
: Colors.grey.shade200,
),
Expanded(
child: _buildMiniStatItem(
'بەرزترین',
maxPrice,
const Color(0xFFEF4444),
isDark,
),
),
],
),
),
],
),
),
);
}

Widget _buildMiniStatItem(
String label,
double value,
Color color,
bool isDark,
) {
return Column(
mainAxisSize: MainAxisSize.min,
mainAxisAlignment: MainAxisAlignment.center,
children: [
Text(
label,
style: TextStyle(
fontSize: 8,
color: isDark ? Colors.white54 : Colors.grey,
fontWeight: FontWeight.bold,
),
maxLines: 1,
overflow: TextOverflow.ellipsis,
),
const SizedBox(height: 1),
Text(
value.toStringAsFixed(0),
style: TextStyle(
fontSize: 11,
fontWeight: FontWeight.w900,
color: color,
),
maxLines: 1,
overflow: TextOverflow.ellipsis,
),
],
);
}

Widget _buildEmptyState() {
return Container(
padding: const EdgeInsets.all(24),
decoration: BoxDecoration(
color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
borderRadius: BorderRadius.circular(18),
border: Border.all(
color: isDark
? Colors.white.withValues(alpha: 0.1)
: Colors.grey.shade200,
),
),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Icon(
Icons.show_chart_rounded,
size: 40,
color: isDark ? Colors.white24 : Colors.grey.shade300,
),
const SizedBox(height: 10),
Text(
'پێویست بە لانیکەم ٢ گۆڕانکاری هەیە',
style: TextStyle(
fontSize: 12,
color: isDark ? Colors.white54 : Colors.grey,
fontWeight: FontWeight.bold,
),
textAlign: TextAlign.center,
),
],
),
);
}

Color _hexToColor(String hex) {
try {
hex = hex.replaceAll('#', '');
if (hex.length == 6) hex = 'FF$hex';
return Color(int.parse(hex, radix: 16));
} catch (_) {
return const Color(0xFFFFD700);
}
}
}