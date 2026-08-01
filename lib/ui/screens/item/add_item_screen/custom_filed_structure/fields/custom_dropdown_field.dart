import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/responsiveSize.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/ui/screens/widgets/dynamic_field/dynamic_field.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart';

class CustomFieldDropdown extends CustomField {
  @override
  String type = "dropdown";
  String? selected;

  @override
  void init() {
    if (parameters['isEdit'] == true) {
      if (parameters['value'] != null) {
        if ((parameters['value'] as List).isNotEmpty) {
          selected = parameters['value'][0].toString();
          AbstractField.fieldsData.addAll({
            parameters['id'].toString(): [selected],
          });
        }
      }
    } else {
      /* selected = parameters['values'][0];
      AbstractField.fieldsData.addAll({
        parameters['id'].toString(): [selected],
      });*/

      selected = ""; // Ensure selected is null initially
      // Ensure blank option is included in the values
      /* if (!(parameters['values'] as List).contains("")) {
        (parameters['values'] as List).insert(0, "");
      }*/
    }

    update(() {});
    super.init();
  }

  @override
  Widget render() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (parameters['image'] != null) ...[
              Container(
                width: 32.rw(context),
                height: 32.rh(context),
                decoration: BoxDecoration(
                  color: context.color.territoryColor.withValues(alpha: 
                    0.1,
                  ),
                  borderRadius: BorderRadius.circular(
                    10,
                  ),
                ),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: FittedBox(
                    fit: BoxFit.none,
                    child: UiUtils.imageType(parameters['image'],
                        width: 20,
                        height: 20,
                        fit: BoxFit.cover,
                        color: context.color.textDefaultColor),
                  ),
                ),
              ),
              SizedBox(
                width: 10.rw(
                  context,
                ),
              ),
            ],
            Text(
              parameters['name'],
            )
                .size(
                  context.font.large,
                )
                .bold(weight: FontWeight.w500)
                .color(
                  context.color.textColorDark,
                )
          ],
        ),
        SizedBox(
          height: 14.rh(context),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 0,
          ),
          child: Container(
            decoration: BoxDecoration(
                color: context.color.secondaryColor,
                borderRadius: BorderRadius.circular(
                  10,
                ),
                border: Border.all(
                  width: 1,
                  color: context.color.borderColor.darken(30),
                )),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: SizedBox(
                width: double.infinity,
                child: DropdownButtonFormField(
                  validator: (value) {
                    if (parameters['required'] == 1 &&
                        (selected == "" || selected == null)) {
                      return "This field is required"; // Return validation message if not selected
                    }
                    return null;
                  },

                  value: selected?.isEmpty == true ? null : selected,
                  dropdownColor: context.color.secondaryColor,
                  isExpanded: true,
                  //padding: const EdgeInsets.symmetric(vertical: 5),
                  icon: SvgPicture.asset(
                    AppIcons.downArrow,
                    colorFilter: ColorFilter.mode(
                        context.color.textDefaultColor, BlendMode.srcIn),
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                  ),
                  //underline: SizedBox.shrink(),
                  isDense: true,
                  borderRadius: BorderRadius.circular(10),
                  style: TextStyle(
                    color: context.color.textDefaultColor.withValues(alpha: 0.5),
                    fontSize: context.font.large,
                  ),
                  items: (parameters['values'] as List<dynamic>)
                      .map<DropdownMenuItem<dynamic>>((dynamic e) {
                    return DropdownMenuItem<dynamic>(
                      value: e,
                      child: Text(e),
                    );
                  }).toList(),
                  onChanged: (v) {
                    selected = v.toString();
                    update(() {});
                    AbstractField.fieldsData.addAll({
                      parameters['id'].toString(): [selected],
                    });
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
