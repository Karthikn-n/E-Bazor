import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/ui/screens/ad_details_screen.dart';
import 'package:Ebozor/ui/screens/advertisement/my_advertisment_screen.dart';
import 'package:Ebozor/ui/screens/item/items_list.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hiring owner-action screens compile with a hiring post', () {
    final hiringPost = ItemModel.fromJson({
      'id': 132,
      'user_id': 368,
      'status': 'active',
      'category_id': 440,
      'all_category_ids': '4,356,404,440',
    });

    const myAds = MyAdvertisementScreen();
    const itemsList = ItemsList(
      categoryId: '356',
      categoryName: 'Jobs',
    );
    final details = AdDetailsScreen(model: hiringPost);

    expect(hiringPost.isHiringPost, isTrue);
    expect(myAds.fromProfile, isFalse);
    expect(itemsList.categoryId, '356');
    expect(details.model, same(hiringPost));
  });
}
