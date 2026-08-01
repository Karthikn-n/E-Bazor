import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/responsiveSize.dart';
import 'package:flutter/material.dart';

import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/ui/screens/widgets/dynamic_field/dynamic_field.dart';
import 'package:Ebozor/ui/screens/widgets/custom_text_form_field.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart';

class CustomFieldText extends CustomField {
  @override
  String type = "textbox";
  String initialValue = "";

  @override
  void init() {
    //
    if (parameters['isEdit'] == true) {
      if (parameters['value'] != null) {
        if ((parameters['value'] as List).isNotEmpty) {
          initialValue = parameters['value'][0].toString();
          AbstractField.fieldsData.addAll({
            parameters['id'].toString(): [initialValue]
          });
          update(() {});
        }
      }
    }
    super.init();
  }

  @override
  Widget render() {
    return Column(
      children: [
        Row(
          children: [
            if (parameters['image'] != null) ...[
              Container(
                width: 48.rw(context),
                height: 48.rh(context),
                decoration: BoxDecoration(
                  color: context.color.territoryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: FittedBox(
                    fit: BoxFit.none,
                    child: UiUtils.imageType(parameters['image'],
                        width: 24,
                        height: 24,
                        fit: BoxFit.cover,
                        color: context.color.textDefaultColor),
                  ),
                ),
              ),
              SizedBox(
                width: 10.rw(context),
              ),
            ],
            Text(parameters['name'])
                .size(context.font.large)
                .bold(weight: FontWeight.w500)
                .color(context.color.textColorDark)
          ],
        ),
        SizedBox(
          height: 14.rh(context),
        ),
        CustomTextFieldDynamic(
          action: TextInputAction.newline,
          initController: parameters['value'] != null ? true : false,
          value: initialValue,
          hintText: "",
          //"writeSomething".translate(context),
          required: parameters['required'] == 1 ? true : false,
          id: parameters['id'],
          maxLen: parameters['max_length'],
          maxLine: 3,
          minLen: parameters['min_length'],
          validator: CustomTextFieldValidator.minAndMixLen,
          keyboardType: TextInputType.multiline,
          capitalization: TextCapitalization.sentences,
        )
      ],
    );
  }
}
