import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/responsiveSize.dart';
import 'package:Ebozor/utils/validator.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/ui/screens/widgets/dynamic_field/dynamic_field.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart';

class CustomFileField extends CustomField {
  @override
  String type = "fileinput";

  String? picked;

  @override
  void init() {
    if (parameters['isEdit'] == true) {
      if ((parameters['value'] as List).isNotEmpty) {
        picked = parameters['value'][0].toString();
        update(() {});
      }
    }
    super.init();
  }

  Future<File?> pickFile() async {
    PlatformFile? picker = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'svg', 'pdf'],
    );
    if (picker != null) {
      File selectedFile = File(picker.path!);
      picked = selectedFile.path;

      if (_isImageFile(selectedFile)) {
        if (await selectedFile.length() > Constant.maxSizeInBytes) {
          File compressedFile =
              await HelperUtils.compressImageFile(selectedFile);
          return compressedFile;
        } else {
          return selectedFile;
        }
      } else {
        // Return the selected PDF file without compression
        return selectedFile;
      }
    }
    picked = null;
    return null;
  }

  bool _isImageFile(File file) {
    List<String> imageExtensions = ['png', 'jpg', 'jpeg', 'svg'];
    String extension = file.path.split('.').last.toLowerCase();
    return imageExtensions.contains(extension);
  }

/*  Future<File?> pickFile() async {
    FilePickerResult? picker = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'svg', 'pdf'],
    );
    if (picker != null) {
      File file = File(picker.files.single.path!);
      picked = file.path;
      return file;
    }
    picked = null;
    return null;
  }*/

  @override
  Widget render() {
    return CustomValidator(
      validator: (value) {
        if (parameters['required'] == 1 && (value == null && picked == null)) {
          return "pleaseSelectFile".translate(context);
        }
        return null;
      },
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
                Expanded(
                  child: Text(
                    parameters['name'],
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    maxLines: 3,
                  )
                      .size(context.font.large)
                      .bold(weight: FontWeight.w500)
                      .color(state.hasError
                          ? context.color.error
                          : context.color.textColorDark),
                ),
              ],
            ),
            SizedBox(
              height: 14.rh(context),
            ),
            GestureDetector(
              onTap: () async {
                File? file = await pickFile();
                if (file != null) {
                  MultipartFile multipartFile =
                      await MultipartFile.fromFile(file.path);
                  update(() {});
                  state.didChange(multipartFile);
                  AbstractField.files.addAll({
                    "custom_field_files[${parameters['id']}]": multipartFile
                  });
                }
              },
              child: DottedBorder(
                options: RoundedRectDottedBorderOptions(
                  radius: const Radius.circular(10),
                  color: state.hasError
                      ? context.color.error
                      : context.color.textLightColor.darken(50),
                  strokeCap: StrokeCap.round,
                  padding: const EdgeInsets.all(5),
                  dashPattern: const [3, 3],
                ),
                child: Container(
                  width: double.infinity,
                  height: 43,
                  decoration:
                      BoxDecoration(borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add),
                      const SizedBox(
                        width: 5,
                      ),
                      Text(
                        "addFile".translate(context),
                        style: TextStyle(
                            color: context.color.textDefaultColor
                                .withValues(alpha: 0.5)),
                      ).size(context.font.large),
                    ],
                  ),
                ),
              ),
            ),
            Builder(builder: (context) {
              if (picked == null) {
                return const SizedBox.shrink();
              }
              return Container(
                child: Row(
                  children: [
                    Icon(
                      Icons.insert_drive_file,
                      color: context.color.territoryColor,
                      size: 35,
                    ),
                    const SizedBox(
                      width: 5,
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(picked?.split("/").last ?? "")
                              .setMaxLines(lines: 1)
                              .bold(weight: FontWeight.w500),
                          if (!((picked ?? "").startsWith("http") ||
                              (picked ?? "").startsWith("https")))
                            Text(
                              HelperUtils.getFileSizeString(
                                bytes: File((picked ?? "")).lengthSync(),
                              ).toUpperCase(),
                            ).size(context.font.smaller),
                        ],
                      ),
                    ),
                    const Spacer(flex: 1),
                    IconButton(
                      onPressed: () {
                        state.didChange(null);
                        picked = null;
                        update(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Text(
              'allowedFileTypes'.translate(context),
            ).color(context.color.error).size(context.font.small),
          ],
        );
      },
    );
  }
}
