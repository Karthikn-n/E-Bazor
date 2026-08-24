import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/data/model/category_model.dart';
import 'package:flutter/material.dart';

import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';

class SubCategoryFilterScreen extends StatefulWidget {
  final List<CategoryModel> selection;
  final List<CategoryModel> model;

  const SubCategoryFilterScreen(
      {super.key, required this.selection, required this.model});

  @override
  State<SubCategoryFilterScreen> createState() =>
      _SubCategoryFilterScreenState();

  static Route route(RouteSettings routeSettings) {
    Map? args = routeSettings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => SubCategoryFilterScreen(
        selection: args!["selection"],
        model: args["model"],
      ),
    );
  }
}

class _SubCategoryFilterScreenState extends State<SubCategoryFilterScreen>
    with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.color.secondaryColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: context.color.textDefaultColor,
          ),
        ),
        title: Text(
          'classifieds'.translate(context),
          style: TextStyle(
            color: context.color.textDefaultColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: SizedBox(
            width: context.screenWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: 5.0),
              child: Container(
                color: Colors.transparent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'allInClassified'.translate(context),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.color.textDefaultColor,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.25,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Choose a category to continue',
                            style: TextStyle(
                              color: context.color.textLightColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: widget.model.length,
                        padding: const EdgeInsets.only(bottom: 24),
                        shrinkWrap: true,
                        separatorBuilder: (context, index) {
                          return const SizedBox(height: 10);
                        },
                        itemBuilder: (context, index) {
                          CategoryModel category = widget.model[index];
                          final childCount = category.children?.length ??
                              category.subcategoriesCount ??
                              0;

                          return ListTile(
                            tileColor: context.color.secondaryColor,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: context.color.borderColor
                                    .withValues(alpha: 0.55),
                              ),
                            ),
                            onTap: () {
                              widget.selection.add(category);
                              Navigator.pop(context);
                              Navigator.pop(context);
                            },
                            leading: Container(
                                width: 52,
                                height: 52,
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: context.color.territoryColor
                                        .withValues(alpha: 0.09)),
                                child: (category.url != null &&
                                        category.url!.trim().isNotEmpty)
                                    ? UiUtils.imageType(
                                        category.url!,
                                        color: category.url!.endsWith('.svg')
                                            ? context.color.territoryColor
                                            : null,
                                        fit: BoxFit.contain,
                                      )
                                    : Icon(
                                        Icons.category_outlined,
                                        color: context.color.territoryColor,
                                        size: 24,
                                      )),
                            title: Text(
                              category.name ?? '',
                              textAlign: TextAlign.start,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.color.textDefaultColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.1,
                              ),
                            ),
                            subtitle: childCount > 0
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '$childCount subcategories',
                                      style: TextStyle(
                                        color: context.color.textLightColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  )
                                : null,
                            trailing: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: context.color.territoryColor
                                        .withValues(alpha: 0.08)),
                                child: Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 15,
                                  color: context.color.territoryColor,
                                )),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ),
    );
  }
}
