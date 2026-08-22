
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:flutter/material.dart';

import 'package:Ebozor/utils/ui_utils.dart';

class CategoryHomeCard extends StatelessWidget {
  final String title;
  final String url;
  final VoidCallback onTap;

  const CategoryHomeCard({
    super.key,
    required this.title,
    required this.url,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasValidUrl = url.trim().isNotEmpty;

    return Card(
      elevation: 0.5,
      color: context.color.secondaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.color.territoryColor.withValues(alpha: 0.1),
                ),
                child: hasValidUrl
                    ? UiUtils.imageType(
                        url,
                        fit: BoxFit.contain,
                        // color: url.endsWith('.svg')
                        //     ? context.color.territoryColor
                        //     : null,
                      )
                    : Icon(
                        Icons.category_outlined,
                        size: 26,
                        color: context.color.territoryColor,
                      ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: context.font.small,
                      color: context.color.textDefaultColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



