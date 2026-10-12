import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CategoryFallbackHelper {
  static IconData getFallbackIcon(String? name, [String? slug]) {
    final combined = '${name ?? ''} ${slug ?? ''}'.toLowerCase();

    if (combined.contains('motor') ||
        combined.contains('car') ||
        combined.contains('auto') ||
        combined.contains('bike') ||
        combined.contains('vehicle') ||
        combined.contains('boat') ||
        combined.contains('truck')) {
      return Icons.directions_car_rounded;
    }

    if (combined.contains('propert') ||
        combined.contains('real estate') ||
        combined.contains('estate') ||
        combined.contains('house') ||
        combined.contains('apartment') ||
        combined.contains('villa') ||
        combined.contains('flat') ||
        combined.contains('rent') ||
        combined.contains('land')) {
      return Icons.home_work_rounded;
    }

    if (combined.contains('electr') ||
        combined.contains('phone') ||
        combined.contains('mobile') ||
        combined.contains('computer') ||
        combined.contains('laptop') ||
        combined.contains('gadget') ||
        combined.contains('tech') ||
        combined.contains('device') ||
        combined.contains('tablet') ||
        combined.contains('camera')) {
      return Icons.devices_rounded;
    }

    if (combined.contains('job') ||
        combined.contains('career') ||
        combined.contains('hire') ||
        combined.contains('work') ||
        combined.contains('employment') ||
        combined.contains('recruit')) {
      return Icons.work_rounded;
    }

    if (combined.contains('home') ||
        combined.contains('furnitur') ||
        combined.contains('garden') ||
        combined.contains('sofa') ||
        combined.contains('chair') ||
        combined.contains('decor') ||
        combined.contains('appliances')) {
      return Icons.weekend_rounded;
    }

    if (combined.contains('fashion') ||
        combined.contains('cloth') ||
        combined.contains('wear') ||
        combined.contains('apparel') ||
        combined.contains('shoe') ||
        combined.contains('bag') ||
        combined.contains('watch') ||
        combined.contains('jewel') ||
        combined.contains('beauty')) {
      return Icons.checkroom_rounded;
    }

    if (combined.contains('servic') ||
        combined.contains('repair') ||
        combined.contains('fix') ||
        combined.contains('clean') ||
        combined.contains('handyman') ||
        combined.contains('plumb') ||
        combined.contains('paint')) {
      return Icons.build_rounded;
    }

    if (combined.contains('animal') ||
        combined.contains('pet') ||
        combined.contains('dog') ||
        combined.contains('cat') ||
        combined.contains('bird') ||
        combined.contains('fish')) {
      return Icons.pets_rounded;
    }

    if (combined.contains('sport') ||
        combined.contains('fit') ||
        combined.contains('gym') ||
        combined.contains('cycle') ||
        combined.contains('bike') ||
        combined.contains('outdoor')) {
      return Icons.sports_soccer_rounded;
    }

    if (combined.contains('book') ||
        combined.contains('educat') ||
        combined.contains('stationery') ||
        combined.contains('learn') ||
        combined.contains('study')) {
      return Icons.menu_book_rounded;
    }

    if (combined.contains('kid') ||
        combined.contains('baby') ||
        combined.contains('child') ||
        combined.contains('toy')) {
      return Icons.child_care_rounded;
    }

    if (combined.contains('food') ||
        combined.contains('agri') ||
        combined.contains('grocery') ||
        combined.contains('fruit')) {
      return Icons.shopping_basket_rounded;
    }

    if (combined.contains('business') ||
        combined.contains('industr') ||
        combined.contains('equip') ||
        combined.contains('factory')) {
      return Icons.precision_manufacturing_rounded;
    }

    return Icons.category_rounded;
  }

  static Widget buildCategoryIconWidget({
    required String? url,
    required String title,
    String? slug,
    IconData? fallbackIcon,
    required Color iconColor,
    double size = 26,
  }) {
    final effectiveFallbackIcon =
        fallbackIcon ?? getFallbackIcon(title, slug);

    final cleanUrl = url?.trim() ?? '';
    final isInvalidOrPlaceholder = cleanUrl.isEmpty ||
        cleanUrl.toLowerCase().contains('placeholder') ||
        cleanUrl == 'null';

    if (isInvalidOrPlaceholder) {
      return Icon(
        effectiveFallbackIcon,
        size: size,
        color: iconColor,
      );
    }

    final lowerUrl = cleanUrl.toLowerCase();
    final isSvg = lowerUrl.endsWith('.svg') ||
        lowerUrl.contains('.svg?') ||
        lowerUrl.contains('image/svg');

    if (isSvg) {
      return SvgPicture.network(
        cleanUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        placeholderBuilder: (_) => Icon(
          effectiveFallbackIcon,
          size: size,
          color: iconColor,
        ),
        errorBuilder: (_, __, ___) => Icon(
          effectiveFallbackIcon,
          size: size,
          color: iconColor,
        ),
      );
    } else {
      return CachedNetworkImage(
        imageUrl: cleanUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        color: iconColor,
        placeholder: (_, __) => Icon(
          effectiveFallbackIcon,
          size: size,
          color: iconColor,
        ),
        errorWidget: (_, __, ___) => Icon(
          effectiveFallbackIcon,
          size: size,
          color: iconColor,
        ),
      );
    }
  }
}
