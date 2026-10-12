import 'package:Ebozor/data/cubits/category/fetch_category_cubit.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:Ebozor/app/routes.dart';

import 'package:Ebozor/ui/screens/home/home_screen.dart';
import 'package:flutter_svg/svg.dart';

class HomeSearchField extends StatelessWidget {
  const HomeSearchField({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FetchCategoryCubit, FetchCategoryState>(
      builder: (context, state) {
        List categories = [];

        if (state is FetchCategorySuccess) {
          categories = state.categories;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: sidePadding,
            vertical: 8,
          ),
          child: GestureDetector(
            onTap: () {
              Navigator.pushNamed(
                context,
                Routes.searchScreenRoute,
                arguments: const {"autoFocus": true},
              );
            },
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: context.color.secondaryColor,
                border: Border.all(
                  width: 1,
                  color: context.color.borderColor.withValues(alpha: 0.7),
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: 22,
                    color: context.color.textColorDark.withValues(alpha: 0.45),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DynamicSearchText(
                      categories: categories,
                    ),
                  ),
                  Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 20,
                    color: context.color.textColorDark.withValues(alpha: 0.55),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DynamicSearchText extends StatefulWidget {
  final List categories;

  const _DynamicSearchText({
    Key? key,
    required this.categories,
  }) : super(key: key);

  @override
  State<_DynamicSearchText> createState() => _DynamicSearchTextState();
}

class _DynamicSearchTextState extends State<_DynamicSearchText>
    with SingleTickerProviderStateMixin {
  int index = 0;

  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1), // from bottom
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_controller);

    _startLoop();
  }

  void _startLoop() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      // 🔥 ENTER animation
      await _controller.forward();
      if (!mounted) return;

      // 🔥 STAY visible
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      // 🔥 EXIT animation (go up + fade)
      await _controller.reverse();
      if (!mounted) return;

      // 🔁 CHANGE TEXT
      if (widget.categories.isNotEmpty) {
        setState(() {
          index = (index + 1) % widget.categories.length;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    /// SVG

    if (widget.categories.isEmpty) {
      return Text(
        "search".translate(context),
        style: TextStyle(
          color: context.color.textDefaultColor,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final category = widget.categories[index];

    return Row(
      children: [
        /// 🔍 FIXED ICON
        _buildCategoryIcon(category.url),

        const SizedBox(width: 12),

        /// 🔍 FIXED TEXT
        Text(
          "${"search".translate(context)} ",
          style: TextStyle(
            color: context.color.textDefaultColor,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        const SizedBox(width: 4),

        /// 🔥 ANIMATED CATEGORY TEXT
        Expanded(
          child: ClipRect(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Text(
                  category.name ?? "",
                  style: TextStyle(
                    color:
                        context.color.textDefaultColor.withValues(alpha: 0.6),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryIcon(String? url) {
    if (url == null || url.isEmpty) {
      return const Icon(Icons.image, size: 18);
    }

    /// 🔥 SVG from NETWORK
    if (url.endsWith(".svg")) {
      return SvgPicture.network(
        url,
        width: 18,
        height: 18,
        placeholderBuilder: (context) => const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    /// 🔥 PNG / JPG
    return Image.network(
      url,
      width: 18,
      height: 18,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 18),
    );
  }
}
