import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ItemModel listing status', () {
    test('treats a package-backed blank status as active', () {
      final item = ItemModel.fromJson({
        'id': 132,
        'name': 'Paid job',
        'status': '',
        'package_id': 6,
      });

      expect(item.status, 'active');
    });

    test('keeps an explicit payment-pending status', () {
      final item = ItemModel.fromJson({
        'id': 106,
        'name': 'Unpaid ad',
        'status': 'pending payment',
        'package_id': 6,
      });

      expect(item.status, 'pending payment');
    });

    test('does not promote an unassigned blank listing', () {
      final item = ItemModel.fromJson({
        'id': 999,
        'name': 'Draft listing',
        'status': '',
      });

      expect(item.status, isEmpty);
    });
  });
}
