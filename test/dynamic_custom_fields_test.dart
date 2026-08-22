import 'package:Ebozor/data/model/custom_field/custom_field_model.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/widgets/dynamic_custom_fields_form.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/widgets/posting_form_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the get-customfields-by-category-id response keys', () {
    final field = CustomFieldModel.fromMap({
      'category_id': 356,
      'custom_field_id': '150',
      'label_name': 'Skills',
      'field_type': 'dropdown',
      'field_values': ['Accounting', 'Python'],
      'is_required': true,
      'is_field_multiselect': '1',
    });

    expect(field.id, 150);
    expect(field.name, 'Skills');
    expect(field.label, 'Skills');
    expect(field.type, 'dropdown');
    expect(field.values, ['Accounting', 'Python']);
    expect(field.required, 1);
    expect(field.isFieldMultiselect, isTrue);
  });

  test('controller validates and submits only active field IDs', () {
    final requiredText = CustomFieldModel(
      id: 145,
      label: 'Company name',
      type: 'text',
      required: 1,
      minLength: 5,
    );
    final skills = CustomFieldModel(
      id: 150,
      label: 'Skills',
      type: 'dropdown',
      values: ['Python', 'SQL'],
      isFieldMultiselect: true,
    );
    final controller = DynamicCustomFieldsController()
      ..replaceFields([requiredText, skills]);

    expect(controller.validate(), 'Company name is required');
    controller.textController(requiredText).text = 'Ebozor';
    controller.toggleMultiselect(skills);
    expect(controller.isMultiselectExpanded(skills), isTrue);
    controller.toggleOption(skills, 'Python');
    controller.toggleOption(skills, 'SQL');
    expect(controller.selected(skills), containsAll(['Python', 'SQL']));
    expect(controller.validate(), isNull);
    expect(controller.toSubmissionMap(), {
      '145': ['Ebozor'],
      '150': ['Python', 'SQL'],
    });

    controller.replaceFields([skills]);
    expect(controller.toSubmissionMap().containsKey('145'), isFalse);
    controller.dispose();
  });

  test('map route result becomes the submitted location fields', () {
    final location = PostingLocationData.fromRouteResult(
      {
        'area': 'Al Barsha',
        'city': 'Dubai',
        'state': 'Dubai',
        'country': 'United Arab Emirates',
        'latitude': 25.1122,
        'longitude': 55.1888,
      },
      const PostingLocationData.dubai(),
    );

    expect(location.label, 'Al Barsha');
    expect(location.toItemDetails(), {
      'country': 'United Arab Emirates',
      'state': 'Dubai',
      'city': 'Dubai',
      'latitude': 25.1122,
      'longitude': 55.1888,
      'address': 'Al Barsha, Dubai, United Arab Emirates',
    });
  });

  test('required posting media URLs validate by field type', () {
    expect(
      validateRequiredPostingMediaUrl('', youtubeOnly: true),
      'YouTube URL is required',
    );
    expect(
      validateRequiredPostingMediaUrl(
        'https://youtu.be/abc123',
        youtubeOnly: true,
      ),
      isNull,
    );
    expect(
      validateRequiredPostingMediaUrl(
        'https://www.youtube.com/watch?v=abc123',
        youtubeOnly: true,
      ),
      isNull,
    );
    expect(
      validateRequiredPostingMediaUrl(
        'https://vimeo.com/abc123',
        youtubeOnly: true,
      ),
      'Enter a valid YouTube URL',
    );
    expect(
      validateRequiredPostingMediaUrl(
        'https://tour.example.com/property/42',
        youtubeOnly: false,
      ),
      isNull,
    );
    expect(
      validateRequiredPostingMediaUrl(
        'tour.example.com/property/42',
        youtubeOnly: false,
      ),
      'Enter a valid URL starting with http:// or https://',
    );
  });
}
