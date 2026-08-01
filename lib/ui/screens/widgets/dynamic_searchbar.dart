// import 'package:Ebozor/ui/theme/theme.dart';
// import 'package:Ebozor/utils/extensions/lib/build_context.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
//
// class DynamicSearchBar extends StatefulWidget {
//   final List categories;
//
//   const DynamicSearchBar({
//     super.key,
//     required this.categories,
//   });
//
//   @override
//   State<DynamicSearchBar> createState() => _DynamicSearchBarState();
// }
// class _DynamicSearchBarState extends State<DynamicSearchBar> {
//   int currentIndex = 0;
//
//   @override
//   void initState() {
//     super.initState();
//     startAutoChange();
//   }
//
//   void startAutoChange() async {
//     while (mounted) {
//       await Future.delayed(const Duration(seconds: 2));
//
//       setState(() {
//         currentIndex =
//             (currentIndex + 1) % widget.categories.length;
//       });
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final category = widget.categories[currentIndex];
//
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//       decoration: BoxDecoration(
//         color: context.color.secondaryColor,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Row(
//         children: [
//           Icon(Icons.search),
//
//           const SizedBox(width: 10),
//
//           Expanded(
//             child: AnimatedSwitcher(
//               duration: const Duration(milliseconds: 400),
//               child: Text(
//                 "Search ${category.name}".toTranslate(context),
//                 key: ValueKey(category.name),
//                 style: TextStyle(
//                   color: context.color.textDefaultColor.withValues(alpha: 0.6),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/extensions/lib/build_context.dart';
import 'package:Ebozor/utils/extensions/lib/translate.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/cupertino.dart';

class _DynamicSearchText extends StatefulWidget {
  final List categories;

  const _DynamicSearchText({
    Key? key,
    required this.categories,
  }) : super(key: key);

  @override
  State<_DynamicSearchText> createState() => _DynamicSearchTextState();
}

class _DynamicSearchTextState extends State<_DynamicSearchText> {
  int index = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        index = (index + 1) % widget.categories.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.categories[index];

    return Row(
      children: [
        /// 🔥 CATEGORY ICON CHANGE
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: UiUtils.getSvg(
            category.url ?? AppIcons.search, // 👈 dynamic icon
            key: ValueKey(category.id),
            color: context.color.textDefaultColor.withValues(alpha: 0.6),
            width: 18,
            height: 18,
          ),
        ),

        const SizedBox(width: 6),

        /// 🔥 CATEGORY NAME CHANGE
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
          child: Text(
            "${"searchIn".translate(context)} ${category.name}",
            key: ValueKey(category.name),
            style: TextStyle(
              color: context.color.textDefaultColor.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }
}