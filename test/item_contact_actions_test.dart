import 'package:Ebozor/data/cubits/item/fetch_my_promoted_items_cubit.dart';
import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/data/model/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('item contact actions', () {
    test('uses root category ids from all_category_ids', () {
      final property = ItemModel(
        allCategoryIds: '78,66,65,3',
        category: CategoryModel(id: 78, name: 'Apartment'),
      );
      final motor = ItemModel(
        allCategoryIds: '6,5,1',
        category: CategoryModel(id: 6, name: 'Used Cars'),
      );
      final mobile = ItemModel(
        allCategoryIds: '379,349,220,2',
        category: CategoryModel(id: 379, name: 'Apple'),
      );

      expect(property.isPropertyCategory, isTrue);
      expect(property.isClassifiedsCategory, isFalse);
      expect(motor.isMotorsCategory, isTrue);
      expect(motor.isClassifiedsCategory, isFalse);
      expect(motor.supportsChatContact, isTrue);
      expect(property.supportsChatContact, isFalse);
      expect(mobile.isClassifiedsCategory, isTrue);
      expect(mobile.supportsChatContact, isTrue);
    });

    test('exposes phone actions only when the item phone is visible', () {
      final visible = ItemModel(
        contact: '+971501234567',
        hidePhoneNumber: false,
      );
      final hidden = ItemModel(
        contact: '+971501234567',
        hidePhoneNumber: true,
      );

      expect(visible.hasVisiblePhoneNumber, isTrue);
      expect(hidden.hasVisiblePhoneNumber, isFalse);
    });
  });

  group('user display name', () {
    test('includes the API last_name value', () {
      final user = UserModel.fromJson({
        'name': 'karthi',
        'last_name': 'ios',
      });

      expect(user.displayName, 'karthi ios');
      expect(user.toJson()['last_name'], 'ios');
    });

    test('does not duplicate a last name already present in name', () {
      final user = UserModel(name: 'Karthi IOS', lastName: 'ios');

      expect(user.displayName, 'Karthi IOS');
    });
  });

  test('promoted-items reset is safe after cubit close', () async {
    final cubit = FetchMyPromotedItemsCubit();
    await cubit.close();

    expect(cubit.resetState, returnsNormally);
    expect(FetchMyPromotedItemsCubit.globalInstance, isNull);
  });
}
