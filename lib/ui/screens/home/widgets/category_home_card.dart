import 'package:Ebozor/app/app_theme.dart';
import 'package:Ebozor/data/cubits/system/app_theme_cubit.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/utils/category_fallback_helper.dart';

class CategoryHomeCard extends StatelessWidget {
  final String title;
  final String? url;
  final Widget? customIcon;
  final Color? bgColor;
  final Color? iconColor;
  final IconData? fallbackIcon;
  final VoidCallback onTap;

  const CategoryHomeCard({
    super.key,
    required this.title,
    this.url,
    this.customIcon,
    this.bgColor,
    this.iconColor,
    this.fallbackIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark =
        context.watch<AppThemeCubit>().state.appTheme == AppTheme.dark;
    final bool hasValidUrl = url != null && url!.trim().isNotEmpty;
    final Color effectiveIconColor = iconColor ?? const Color(0xFF007AFF);
    final Color containerColor = isDark
        ? (bgColor != null
            ? bgColor!.withValues(alpha: 0.18)
            : context.color.secondaryColor)
        : (bgColor ?? const Color(0xFFF2F5F9));

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: containerColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: customIcon ??
                  CategoryFallbackHelper.buildCategoryIconWidget(
                    url: url,
                    title: title,
                    fallbackIcon: fallbackIcon,
                    iconColor: effectiveIconColor,
                    size: 26,
                  ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 72,
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: context.color.textColorDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

