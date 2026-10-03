import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

/// Square thumbnail for an owner property card.
///
/// Shows the first uploaded photo (a clean land/house icon when there's none),
/// and overlays a clear status mark when the property is **Booked / Sold**
/// (green tick) or **Archived** (archive icon) so the owner can tell at a glance.
class PropertyThumb extends StatelessWidget {
  final Map<String, dynamic> property;
  final double size;
  final double radius;
  const PropertyThumb({
    super.key,
    required this.property,
    this.size = 48,
    this.radius = 12,
  });

  String _fullUrl(String url) =>
      url.startsWith('http') ? url : '${ApiService.mediaBase}$url';

  @override
  Widget build(BuildContext context) {
    final type = property['propertyType'] as String? ?? '';
    final status = property['status'] as String? ?? '';
    final photos = property['photos'] as List? ?? [];
    final first = photos.isNotEmpty ? (photos.first?.toString() ?? '') : '';
    final sold = status == 'sold';
    final archived = status == 'archived';

    final IconData fbIcon = type == 'pg'
        ? Icons.bed_rounded
        : type == 'guest'
            ? Icons.apartment_rounded
            : Icons.landscape_rounded;

    Widget fallback() => Container(
          width: size,
          height: size,
          color: AppColors.primaryLight,
          alignment: Alignment.center,
          child: Icon(fbIcon, color: AppColors.primary, size: size * 0.5),
        );

    final Widget base = first.isEmpty
        ? fallback()
        : Image.network(
            _fullUrl(first),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback(),
            loadingBuilder: (ctx, child, progress) => progress == null
                ? child
                : Container(
                    width: size,
                    height: size,
                    color: AppColors.primaryLight,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    ),
                  ),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            base,
            if (sold || archived)
              Container(color: Colors.black.withValues(alpha: 0.4)),
            if (sold) _statusMark(Icons.check_rounded, AppColors.success),
            if (archived)
              _statusMark(Icons.inventory_2_rounded, const Color(0xFF555555)),
          ],
        ),
      ),
    );
  }

  Widget _statusMark(IconData icon, Color color) => Center(
        child: Container(
          width: size * 0.52,
          height: size * 0.52,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(icon, color: Colors.white, size: size * 0.3),
        ),
      );
}
