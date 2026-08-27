import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/data/model/property_filter_category_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final offPlan = CategoryModel(
    id: 900,
    name: 'Off-Plan',
    slug: 'property-for-sale-off-plan',
    children: [
      CategoryModel(id: 901, name: 'Apartment', slug: 'dynamic-apartment'),
    ],
  );
  final rent = CategoryModel(
    id: 700,
    name: 'Property for Rent',
    slug: 'property-for-rent',
    children: [
      CategoryModel(id: 701, name: 'Residential', slug: 'dynamic-residential'),
      CategoryModel(id: 702, name: 'Rooms for Rent', slug: 'rooms-for-rent'),
    ],
  );
  final sale = CategoryModel(
    id: 800,
    name: 'Property for Sale',
    slug: 'property-for-sale',
    children: [
      CategoryModel(id: 801, name: 'Commercial', slug: 'dynamic-commercial'),
      offPlan,
    ],
  );
  final trees = [rent, sale];

  test('maps entry categories to tabs without relying on category IDs', () {
    expect(
      PropertyFilterCategoryResolver.isPropertyCategory(
        CategoryModel(name: 'Classifieds', slug: 'classified'),
      ),
      isFalse,
    );
    expect(PropertyFilterCategoryResolver.tabFor(rent), PropertyFilterTab.rent);
    expect(
      PropertyFilterCategoryResolver.tabFor(rent.children!.last),
      PropertyFilterTab.rent,
    );
    expect(PropertyFilterCategoryResolver.tabFor(sale), PropertyFilterTab.buy);
    expect(
      PropertyFilterCategoryResolver.tabFor(offPlan),
      PropertyFilterTab.offPlan,
    );
  });

  test('uses API children and keeps off-plan out of Buy', () {
    final rentTypes = PropertyFilterCategoryResolver.propertyTypesFor(
      tab: PropertyFilterTab.rent,
      categoryTrees: trees,
    );
    final buyTypes = PropertyFilterCategoryResolver.propertyTypesFor(
      tab: PropertyFilterTab.buy,
      categoryTrees: trees,
    );
    final offPlanTypes = PropertyFilterCategoryResolver.propertyTypesFor(
      tab: PropertyFilterTab.offPlan,
      categoryTrees: trees,
    );

    expect(rentTypes.map((category) => category.id), [701, 702]);
    expect(buyTypes.map((category) => category.id), [801]);
    expect(offPlanTypes.map((category) => category.id), [901]);
  });
}
