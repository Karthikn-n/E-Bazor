
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/responsiveSize.dart';
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
    final extension = url.split(".").last.toLowerCase();
    final bool isFullImage = !(extension == "png" || extension == "svg");

    return Card(
      elevation: 1,
      color: context.color.secondaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Flexible(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: UiUtils.imageType(
                    url,
                    fit: isFullImage ? BoxFit.contain : BoxFit.cover,
                  ),
                ),
              ),
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
                      fontWeight: FontWeight.w500,
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


