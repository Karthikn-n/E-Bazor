import 'dart:developer';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/data/repositories/category_repository.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/utils/cloudState/cloud_state.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';

class CommonTitleInputScreen extends StatefulWidget {
  final CategoryModel rootCategory;
  final String? verticalType; // 'property-for-rent', 'property-for-sale', 'classified'

  const CommonTitleInputScreen({
    super.key,
    required this.rootCategory,
    this.verticalType,
  });

  static Route route(RouteSettings settings) {
    Map<String, dynamic>? arguments =
        settings.arguments as Map<String, dynamic>?;
    return BlurredRouter(
      builder: (context) => CommonTitleInputScreen(
        rootCategory: arguments?['rootCategory'] ??
            CategoryModel(id: 2, name: 'Property for Rent', slug: 'property-for-rent'),
        verticalType: arguments?['verticalType'],
      ),
    );
  }

  @override
  CloudState<CommonTitleInputScreen> createState() =>
      _CommonTitleInputScreenState();
}

class _CommonTitleInputScreenState extends CloudState<CommonTitleInputScreen> {
  final TextEditingController _titleController = TextEditingController();
  final CategoryRepository _categoryRepository = CategoryRepository();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _getHintText() {
    final slug = widget.rootCategory.slug?.toLowerCase() ?? '';
    if (slug.contains('rent')) {
      return "e.g. Studio apt. available for monthly rental in Dubai Marina";
    } else if (slug.contains('sale')) {
      return "e.g. Luxury 3BR Villa with pool in Palm Jumeirah";
    } else if (slug.contains('classif')) {
      return "e.g. iPhone 15 Pro Max 256GB Brand New in Box";
    }
    return "e.g. Enter a short description for your listing";
  }

  Future<void> _handleLetsGo() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please enter a title for your listing",
        type: MessageType.warning,
      );
      return;
    }

    if (title.length < 3) {
      HelperUtils.showSnackBarMessage(
        context,
        "Title must be at least 3 characters",
        type: MessageType.warning,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final catSlug = widget.rootCategory.slug ?? 'property-for-rent';
      final catId = widget.rootCategory.id ?? 2;

      // 1. Fetch category tree & children
      final treeRes = await _categoryRepository.fetchCategoryTreeBySlug(
        categorySlug: catSlug,
      );

      List<CategoryModel> children = [];
      if (treeRes is List &&
          treeRes.isNotEmpty &&
          treeRes[0]['children'] != null) {
        final rawChildren = treeRes[0]['children'] as List;
        children = rawChildren.map((e) => CategoryModel.fromJson(e)).toList();
      } else {
        children = await _categoryRepository.fetchCategoryChildrenByParent(
        parentId: catId,
      );
      }

      final categoryWithChildren = widget.rootCategory.copyWith(
        children: children,
      );

      addCloudData("breadCrumb", [categoryWithChildren]);
      addCloudData("prefilled_listing_title", title);

      if (!mounted) return;

      Navigator.pushNamed(
        context,
        Routes.selectNestedCategoryScreen,
        arguments: {
          "current": categoryWithChildren,
          "breadcrumbs": [categoryWithChildren],
          "initialTitle": title,
        },
      );
    } catch (e) {
      log("❌ [TITLE SCREEN ERROR] $e");
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          "Error loading categories: $e",
          type: MessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: SafeArea(
        child: Scaffold(
          backgroundColor: context.color.backgroundColor,
          appBar: AppBar(
            backgroundColor: context.color.secondaryColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: context.color.textDefaultColor,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 12),
                Text(
                  "Enter a short title to describe your listing",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Make your title informative and attractive.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    color: context.color.textLightColor,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    color: context.color.secondaryColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: context.color.borderColor.withValues(alpha: 0.7),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _titleController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _handleLetsGo(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.color.textDefaultColor,
                    ),
                    decoration: InputDecoration(
                      hintText: _getHintText(),
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: context.color.textLightColor.withValues(alpha: 0.6),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 18,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLetsGo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD31027),
                      disabledBackgroundColor:
                          const Color(0xFFD31027).withValues(alpha: 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "Let's Go",
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
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
