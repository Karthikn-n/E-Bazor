import 'package:Ebozor/data/cubits/item/item_inquiry_cubit.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/utils/validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class InquireAdBottomSheet extends StatefulWidget {
  final ItemModel model;

  const InquireAdBottomSheet({super.key, required this.model});

  static Future<void> show(BuildContext context, {required ItemModel model}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BlocProvider(
        create: (_) => ItemInquiryCubit(),
        child: InquireAdBottomSheet(model: model),
      ),
    );
  }

  @override
  State<InquireAdBottomSheet> createState() => _InquireAdBottomSheetState();
}

class _InquireAdBottomSheetState extends State<InquireAdBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _messageController;
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  String? _referenceCode;

  @override
  void initState() {
    super.initState();
    final user = HiveUtils.getUserDetails();

    // Extract reference code from custom fields or fallback to item ID
    if (widget.model.customFields != null) {
      for (var cf in widget.model.customFields!) {
        final name = (cf.name ?? "").toLowerCase();
        if (name.contains("reference") || name.contains("permit")) {
          if (cf.value != null && cf.value!.isNotEmpty) {
            _referenceCode = cf.value!.first.toString();
            break;
          }
        }
      }
    }
    _referenceCode ??= widget.model.id?.toString() ?? "";

    final defaultMessage =
        "Marhaba! I saw your ad with reference number: $_referenceCode on ${Constant.appName}. When is it available for viewing?\nThanks";

    _messageController = TextEditingController(text: defaultMessage);
    _nameController = TextEditingController(text: user.name ?? "");
    _emailController = TextEditingController(text: user.email ?? "");
    _phoneController = TextEditingController(text: user.mobile ?? "");
  }

  @override
  void dispose() {
    _messageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Extract quick specs from custom fields (Bedrooms, Bathrooms, Sqft)
  String _getSpecsSummary() {
    List<String> specs = [];
    if (widget.model.customFields != null) {
      for (var cf in widget.model.customFields!) {
        final name = (cf.name ?? "").toLowerCase();
        if (name.contains("bedroom") && cf.value != null && cf.value!.isNotEmpty) {
          specs.add("${cf.value!.first} Bed");
        } else if (name.contains("bathroom") && cf.value != null && cf.value!.isNotEmpty) {
          specs.add("${cf.value!.first} Bath");
        } else if (name.contains("size") && cf.value != null && cf.value!.isNotEmpty) {
          specs.add("${cf.value!.first} sqft");
        }
      }
    }
    return specs.join(" • ");
  }

  // Rent payment frequency
  String _getRentFrequency() {
    if (widget.model.customFields != null) {
      for (var cf in widget.model.customFields!) {
        final name = (cf.name ?? "").toLowerCase();
        if (name.contains("rent is paid") || name.contains("period")) {
          if (cf.value != null && cf.value!.isNotEmpty) {
            return cf.value!.first.toString();
          }
        }
      }
    }
    return "";
  }

  void _submitInquiry() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final message = _messageController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || email.isEmpty || message.isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please fill in all required fields",
        type: MessageType.error,
      );
      return;
    }

    final listingUrl = widget.model.slug != null
        ? "${Constant.baseUrl}/product-details/${widget.model.slug}"
        : null;

    context.read<ItemInquiryCubit>().sendInquiry(
          itemId: widget.model.id!,
          name: name,
          email: email,
          message: message,
          phone: phone.isNotEmpty ? phone : null,
          listingUrl: listingUrl,
          referenceCode: _referenceCode,
        );
  }

  @override
  Widget build(BuildContext context) {
    final currency = Constant.currencySymbol.isNotEmpty ? Constant.currencySymbol : "AED";
    final priceStr = widget.model.price != null
        ? "$currency ${widget.model.price!.toStringAsFixed(widget.model.price!.truncateToDouble() == widget.model.price! ? 0 : 2)}"
        : "";
    final rentFreq = _getRentFrequency();
    final fullPrice = rentFreq.isNotEmpty ? "$priceStr $rentFreq" : priceStr;
    final specsSummary = _getSpecsSummary();

    return BlocListener<ItemInquiryCubit, ItemInquiryState>(
      listener: (context, state) {
        if (state is ItemInquirySuccess) {
          Navigator.pop(context);
          HelperUtils.showSnackBarMessage(
            context,
            state.message,
            type: MessageType.success,
          );
        } else if (state is ItemInquiryFailure) {
          HelperUtils.showSnackBarMessage(
            context,
            state.errorMessage.toString(),
            type: MessageType.error,
          );
        }
      },
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 20,
            right: 20,
            top: 16,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Drag Handle & Close
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Inquire About this Ad",
                        style: TextStyle(
                          fontSize: 18,
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
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Item Preview Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.color.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.color.borderColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.model.image != null &&
                            widget.model.image!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 72,
                              height: 72,
                              child: UiUtils.getImage(
                                widget.model.image!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (fullPrice.isNotEmpty)
                                Text(
                                  fullPrice,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: context.color.textDefaultColor,
                                  ),
                                ),
                              if (specsSummary.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  specsSummary,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: context.color.textLightColor,
                                  ),
                                ),
                              ],
                              if (widget.model.address != null &&
                                  widget.model.address!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 13,
                                      color: context.color.textLightColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        widget.model.address!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: context.color.textLightColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Message Label
                  Text(
                    "Message",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Message Field
                  TextFormField(
                    controller: _messageController,
                    maxLines: 4,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? "Message is required"
                        : null,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: context.color.backgroundColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: context.color.borderColor.withValues(alpha: 0.6),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: context.color.borderColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Name Field
                  TextFormField(
                    controller: _nameController,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? "Name is required"
                        : null,
                    decoration: InputDecoration(
                      hintText: "Your name",
                      filled: true,
                      fillColor: context.color.backgroundColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: context.color.borderColor.withValues(alpha: 0.6),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: context.color.borderColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        Validator.validateEmail(email: v, context: context),
                    decoration: InputDecoration(
                      hintText: "Your email",
                      filled: true,
                      fillColor: context.color.backgroundColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: context.color.borderColor.withValues(alpha: 0.6),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: context.color.borderColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Phone Field (Optional)
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: "Your phone",
                      filled: true,
                      fillColor: context.color.backgroundColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: context.color.borderColor.withValues(alpha: 0.6),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: context.color.borderColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Inquire Now Button
                  BlocBuilder<ItemInquiryCubit, ItemInquiryState>(
                    builder: (context, state) {
                      final isLoading = state is ItemInquiryInProgress;

                      return SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.color.territoryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: isLoading ? null : _submitInquiry,
                          child: isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  "Inquire Now",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
