import 'package:Ebozor/data/model/category_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses dynamic category filter definitions from the API payload', () {
    final category = FilterCategory.fromJson({
      'category_id': '365',
      'name': 'Armoires & Wardrobes',
      'slug': 'classified-furniture-armoires-wardrobes',
      'children': const [],
      'filters': [
        {
          'name': 'Seating Capacity',
          'type': 'button',
          'values': [1, 2, '6+'],
          'values_obj': [
            {'label': 'One', 'value': 1},
          ],
          'multiselect': 0,
          'sort_order': '2',
          'is_active': 1,
        },
        {
          'name': 'Model number',
          'type': 'NUMBER',
          'values': const [],
          'multiselect': '1',
          'sort_order': 1,
          'is_active': '0',
          'placeholder': 'Enter model number',
        },
      ],
    });

    expect(category.id, 365);
    expect(category.slug, 'classified-furniture-armoires-wardrobes');
    expect(category.filters, hasLength(2));

    final choice = category.filters.first;
    expect(choice.values, ['1', '2', '6+']);
    expect(choice.valuesObject.single['value'], 1);
    expect(choice.multiSelect, isFalse);
    expect(choice.sortOrder, 2);
    expect(choice.isActive, isTrue);

    final number = category.filters.last;
    expect(number.type, 'number');
    expect(number.multiSelect, isTrue);
    expect(number.isActive, isFalse);
    expect(number.placeholder, 'Enter model number');

    final objectChoices = FilterItem.fromJson({
      'name': 'Colour',
      'type': 'button',
      'values': const [],
      'values_obj': [
        {'label': 'Midnight Blue', 'value': 'blue'},
        {'name': 'Pearl White', 'value': 'white'},
      ],
      'multiselect': false,
    });
    expect(objectChoices.values, ['Midnight Blue', 'Pearl White']);

    expect(
      FilterItem.fromJson({
        'name': 'Model name',
        'type': 'textbox',
        'multiselect': false,
      }).type,
      'text',
    );
    expect(
      FilterItem.fromJson({
        'name': 'Condition',
        'type': 'select',
        'values': ['New', 'Used'],
        'multiselect': false,
      }).type,
      'dropdown',
    );
  });
}
