import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class SellerContactBottomSheet extends StatelessWidget {
  final ItemModel model;

  const SellerContactBottomSheet({super.key, required this.model});

  static Future<void> show(BuildContext context, {required ItemModel model}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SellerContactBottomSheet(model: model),
    );
  }

  String _formatJoinedDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Joined Recently";
    try {
      final dt = DateTime.parse(dateStr);
      return "Joined ${DateFormat('MMMM, yyyy').format(dt)}";
    } catch (_) {
      return "Joined Recently";
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = model.user;
    final isPhoneHidden = model.hidePhoneNumber == true;
    final phone = model.contact ?? user?.mobile ?? "";
    final joinedText = _formatJoinedDate(user?.createdAt);
    final sellerName = user?.name ?? "Seller";

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Seller Info Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Seller Avatar
                ClipOval(
                  child: Container(
                    width: 54,
                    height: 54,
                    color: Colors.grey.shade200,
                    child: user?.profile != null && user!.profile!.isNotEmpty
                        ? UiUtils.getImage(
                            user.profile!,
                            fit: BoxFit.cover,
                          )
                        : Icon(
                            Icons.person,
                            size: 36,
                            color: Colors.grey.shade500,
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                // Name & Joined Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            joinedText,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.color.textLightColor,
                            ),
                          ),
                          Text(
                            "Seller",
                            style: TextStyle(
                              fontSize: 13,
                              color: context.color.textLightColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sellerName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Big Red Call Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626), // Red
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  if (isPhoneHidden) {
                    HelperUtils.showSnackBarMessage(
                      context,
                      "Phone number is hidden by seller",
                    );
                    return;
                  }
                  if (phone.trim().isEmpty) {
                    HelperUtils.showSnackBarMessage(
                      context,
                      "Seller phone number not available",
                    );
                    return;
                  }
                  final Uri launchUri = Uri(
                    scheme: 'tel',
                    path: phone.trim(),
                  );
                  if (await canLaunchUrl(launchUri)) {
                    await launchUrl(launchUri);
                  } else {
                    HelperUtils.showSnackBarMessage(
                      context,
                      "Could not launch phone dialer",
                    );
                  }
                },
                child: Text(
                  isPhoneHidden
                      ? "Phone Number Hidden"
                      : (phone.trim().isNotEmpty ? "Call $phone" : "Call Seller"),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Tips for a safer transaction Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F7FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFDBEAFE),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Tips for a safer transaction:",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTipRow(
                    icon: Icons.handyman_outlined,
                    text: "Check the condition of the item",
                  ),
                  const SizedBox(height: 10),
                  _buildTipRow(
                    icon: Icons.handshake_outlined,
                    text: "Meet the seller in person",
                  ),
                  const SizedBox(height: 10),
                  _buildTipRow(
                    icon: Icons.credit_card_off_outlined,
                    text: "Don't wire money online",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildTipRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: const Color(0xFF2563EB),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1E40AF),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
