import 'package:Ebozor/data/cubits/report/item_report_cubit.dart';
import 'package:Ebozor/data/cubits/report/update_report_items_list_cubit.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReportCategoryOption {
  final String label;
  final String key;

  const ReportCategoryOption({required this.label, required this.key});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportCategoryOption &&
          runtimeType == other.runtimeType &&
          key == other.key;

  @override
  int get hashCode => key.hashCode;
}

class ReportListingDialog extends StatefulWidget {
  final int itemId;
  final ItemModel? itemModel;

  const ReportListingDialog({
    super.key,
    required this.itemId,
    this.itemModel,
  });

  static Future<void> show(
    BuildContext context, {
    required int itemId,
    ItemModel? itemModel,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => BlocProvider(
        create: (_) => ItemReportCubit(),
        child: Dialog(
          backgroundColor: ctx.color.secondaryColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ReportListingDialog(
            itemId: itemId,
            itemModel: itemModel,
          ),
        ),
      ),
    );
  }

  @override
  State<ReportListingDialog> createState() => _ReportListingDialogState();
}

class _ReportListingDialogState extends State<ReportListingDialog> {
  static const List<ReportCategoryOption> _reportOptions = [
    ReportCategoryOption(label: "Spam", key: "spam"),
    ReportCategoryOption(label: "Fraud", key: "fraud"),
    ReportCategoryOption(label: "Miscategorized", key: "miscategorized"),
    ReportCategoryOption(label: "Repetitive Listing", key: "repetitive_listing"),
    ReportCategoryOption(label: "Copyright Infringement", key: "copyright_infringement"),
    ReportCategoryOption(label: "Not Available", key: "not_available"),
    ReportCategoryOption(label: "Incorrect Pricing", key: "incorrect_pricing"),
  ];

  ReportCategoryOption? _selectedCategory;
  final TextEditingController _textController = TextEditingController();
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    // Default to Fraud or null
    _selectedCategory = _reportOptions[1]; // Fraud by default
    _textController.addListener(() {
      setState(() {
        _charCount = _textController.text.trim().length;
      });
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submitReport() {
    if (_selectedCategory == null) return;
    if (_charCount < 20) return;

    final userIdStr = HiveUtils.getUserId();
    final userId = userIdStr != null ? int.tryParse(userIdStr.toString()) ?? 0 : 0;

    context.read<ItemReportCubit>().reportAd(
          userId: userId,
          itemId: widget.itemId,
          reportType: _selectedCategory!.key,
          reportText: _textController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final label = _selectedCategory?.label ?? "violation";
    final isCountValid = _charCount >= 20;

    return BlocListener<ItemReportCubit, ItemReportState>(
      listener: (context, state) {
        if (state is ItemReportInSuccess) {
          if (widget.itemModel != null) {
            context.read<UpdatedReportItemCubit>().addItem(widget.itemModel!);
          }
          Navigator.pop(context);
          HelperUtils.showSnackBarMessage(
            context,
            state.responseMessage,
            type: MessageType.success,
          );
        } else if (state is ItemReportFailure) {
          HelperUtils.showSnackBarMessage(
            context,
            state.error.toString(),
            type: MessageType.error,
          );
        }
      },
      child: BlocBuilder<ItemReportCubit, ItemReportState>(
        builder: (context, state) {
          final isLoading = state is ItemReportInProgress;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Report this listing",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 22,
                          color: context.color.textLightColor,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          if (!isLoading) Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Category Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: context.color.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: context.color.borderColor,
                        width: 1.2,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ReportCategoryOption>(
                        value: _selectedCategory,
                        isExpanded: true,
                        icon: const Icon(
                          Icons.check_rounded,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        hint: Text(
                          "Select Reason",
                          style: TextStyle(
                            fontSize: 14,
                            color: context.color.textLightColor,
                          ),
                        ),
                        items: _reportOptions.map((option) {
                          return DropdownMenuItem<ReportCategoryOption>(
                            value: option,
                            child: Text(
                              option.label,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: context.color.textDefaultColor,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: isLoading
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedCategory = val;
                                  });
                                }
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Prompt text
                  Text(
                    "Please tell us why you believe this is ${label.toLowerCase()}",
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: context.color.textDefaultColor.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Multiline Text Field
                  TextFormField(
                    controller: _textController,
                    maxLines: 4,
                    minLines: 3,
                    enabled: !isLoading,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.color.textDefaultColor,
                    ),
                    decoration: InputDecoration(
                      hintText: "Enter explanation here...",
                      hintStyle: TextStyle(
                        fontSize: 13.5,
                        color: context.color.textLightColor,
                      ),
                      filled: true,
                      fillColor: context.color.backgroundColor,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: context.color.borderColor,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: context.color.borderColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: context.color.territoryColor,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Live character count
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "Minimum 20 characters",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight:
                            isCountValid ? FontWeight.w600 : FontWeight.normal,
                        color: isCountValid
                            ? Colors.green
                            : context.color.textLightColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Subtitle notice
                  Center(
                    child: Text(
                      "You have chosen to report this as ${label.toLowerCase()}.",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.color.textDefaultColor
                            .withValues(alpha: 0.75),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Submit Report Button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCountValid && !isLoading
                            ? context.color.territoryColor
                            : Colors.grey.shade300,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed:
                          isCountValid && !isLoading ? _submitReport : null,
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              "Submit Report",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isCountValid && !isLoading
                                    ? Colors.white
                                    : Colors.grey.shade600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
