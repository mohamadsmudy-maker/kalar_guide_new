import 'package:flutter/material.dart';

/// ⭐ ویدجێتی ئەستێرە
class RatingStars extends StatelessWidget {
  final double rating;
  final double size;
  final Color? color;
  final bool showValue;
  final int? totalReviews;

  const RatingStars({
    super.key,
    required this.rating,
    this.size = 16,
    this.color,
    this.showValue = false,
    this.totalReviews,
  });

  @override
  Widget build(BuildContext context) {
    final starColor = color ?? const Color(0xFFFFC107);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          final starValue = i + 1;
          IconData icon;

          if (rating >= starValue) {
            icon = Icons.star_rounded;
          } else if (rating >= starValue - 0.5) {
            icon = Icons.star_half_rounded;
          } else {
            icon = Icons.star_border_rounded;
          }

          return Icon(icon, size: size, color: starColor);
        }),
        if (showValue) ...[
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: size * 0.85,
              fontWeight: FontWeight.w900,
              color: starColor,
            ),
          ),
        ],
        if (totalReviews != null) ...[
          const SizedBox(width: 4),
          Text(
            '($totalReviews)',
            style: TextStyle(
              fontSize: size * 0.75,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ],
      ],
    );
  }
}

/// ⭐ ویدجێتی هەڵبژاردنی ئەستێرە
class RatingInput extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  const RatingInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final starValue = i + 1;
        final isSelected = starValue <= value;

        return GestureDetector(
          onTap: () => onChanged(starValue),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedScale(
              scale: isSelected ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSelected ? Icons.star_rounded : Icons.star_border_rounded,
                size: size,
                color: isSelected
                    ? const Color(0xFFFFC107)
                    : Colors.grey.shade400,
              ),
            ),
          ),
        );
      }),
    );
  }
}