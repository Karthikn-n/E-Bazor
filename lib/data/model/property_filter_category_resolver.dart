import 'package:Ebozor/data/model/category_model.dart';

enum PropertyFilterTab { rent, buy, offPlan }

/// Resolves property tabs from the category tree returned by the API.
/// Category IDs and child lists deliberately do not live here.
class PropertyFilterCategoryResolver {
  const PropertyFilterCategoryResolver._();

  static PropertyFilterTab tabFor(CategoryModel category) {
    final value = _searchValue(category);
    if (_isOffPlan(value)) return PropertyFilterTab.offPlan;
    if (_isSale(value)) return PropertyFilterTab.buy;
    return PropertyFilterTab.rent;
  }

  static bool isPropertyCategory(CategoryModel category) {
    final value = _searchValue(category);
    return value.contains('property') ||
        value.contains('residential') ||
        value.contains('commercial') ||
        value.contains('rooms for rent') ||
        _isOffPlan(value);
  }

  static CategoryModel? rootFor({
    required PropertyFilterTab tab,
    required Iterable<CategoryModel> categoryTrees,
    CategoryModel? currentCategory,
  }) {
    final trees = <CategoryModel>[
      ...categoryTrees,
      if (currentCategory != null) currentCategory,
    ];

    for (final category in _flatten(trees)) {
      if (_matchesRoot(category, tab)) return category;
    }

    if (currentCategory != null && tabFor(currentCategory) == tab) {
      return currentCategory;
    }
    return null;
  }

  static List<CategoryModel> propertyTypesFor({
    required PropertyFilterTab tab,
    required Iterable<CategoryModel> categoryTrees,
    CategoryModel? currentCategory,
  }) {
    final root = rootFor(
      tab: tab,
      categoryTrees: categoryTrees,
      currentCategory: currentCategory,
    );
    if (root == null) return const [];

    final children = root.children ?? const <CategoryModel>[];
    final visibleChildren = tab == PropertyFilterTab.buy
        ? children
            .where((category) => !_isOffPlan(_searchValue(category)))
            .toList()
        : List<CategoryModel>.from(children);

    return visibleChildren.isNotEmpty ? visibleChildren : [root];
  }

  static Iterable<CategoryModel> _flatten(
    Iterable<CategoryModel> categories,
  ) sync* {
    for (final category in categories) {
      yield category;
      yield* _flatten(category.children ?? const <CategoryModel>[]);
    }
  }

  static String _searchValue(CategoryModel category) =>
      _normalize('${category.name ?? ''} ${category.slug ?? ''}');

  static bool _matchesRoot(CategoryModel category, PropertyFilterTab tab) {
    final name = _normalize(category.name ?? '');
    final slug = _normalize(category.slug ?? '');
    return switch (tab) {
      PropertyFilterTab.rent =>
        name == 'property for rent' || slug == 'property for rent',
      PropertyFilterTab.buy =>
        name == 'property for sale' || slug == 'property for sale',
      PropertyFilterTab.offPlan =>
        name == 'off plan' || slug == 'property for sale off plan',
    };
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static bool _isSaleRoot(String value) =>
      value.contains('property for sale') && !_isOffPlan(value);

  static bool _isOffPlan(String value) => value.contains('off plan');

  static bool _isSale(String value) =>
      _isSaleRoot(value) ||
      value.contains(' for sale') ||
      value.contains('buy');
}
