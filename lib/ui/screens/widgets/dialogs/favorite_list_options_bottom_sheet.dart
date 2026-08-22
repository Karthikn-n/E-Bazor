import 'package:Ebozor/data/cubits/favorite/favorite_listings_cubit.dart';
import 'package:Ebozor/data/model/favorite_listing_model.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

class FavoriteListOptionsBottomSheet extends StatelessWidget {
  final FavoriteListingModel listing;
  final VoidCallback? onDeleted;
  final Function(String newName)? onRenamed;

  const FavoriteListOptionsBottomSheet({
    super.key,
    required this.listing,
    this.onDeleted,
    this.onRenamed,
  });

  static Future<void> show(
    BuildContext context, {
    required FavoriteListingModel listing,
    VoidCallback? onDeleted,
    Function(String newName)? onRenamed,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return BlocProvider.value(
          value: context.read<FavoriteListingsCubit>(),
          child: FavoriteListOptionsBottomSheet(
            listing: listing,
            onDeleted: onDeleted,
            onRenamed: onRenamed,
          ),
        );
      },
    );
  }

  void _shareList(BuildContext context) {
    Navigator.pop(context);
    final shareText = "Check out my favorite list '${listing.title}' on Ebozor!\n${Constant.shareappText}";
    Share.share(shareText);
  }

  void _showRenameDialog(BuildContext context) {
    Navigator.pop(context);
    final controller = TextEditingController(text: listing.title);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        bool isRenaming = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: context.color.secondaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                "Rename list title".translate(context),
                style: TextStyle(
                  color: context.color.textDefaultColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  autofocus: true,
                  style: TextStyle(color: context.color.textDefaultColor),
                  decoration: InputDecoration(
                    hintText: "Enter new list title...".translate(context),
                    hintStyle: TextStyle(color: context.color.textLightColor),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.color.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.color.territoryColor),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return "Please enter a list name".translate(context);
                    }
                    return null;
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(
                    "Cancel".translate(context),
                    style: TextStyle(color: context.color.textLightColor),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.color.territoryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: isRenaming
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isRenaming = true);
                          final newName = controller.text.trim();
                          if (listing.favouritelistingId != null) {
                            final success = await context
                                .read<FavoriteListingsCubit>()
                                .renameListing(listing.favouritelistingId!, newName);
                            if (success) {
                              onRenamed?.call(newName);
                              if (context.mounted) {
                                HelperUtils.showSnackBarMessage(
                                  context,
                                  "List renamed successfully".translate(context),
                                );
                              }
                            }
                          }
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }
                        },
                  child: isRenaming
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          "Save".translate(context),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmDialog(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (dialogCtx) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: context.color.secondaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                "Delete list".translate(context),
                style: TextStyle(
                  color: context.color.textDefaultColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              content: Text(
                "Are you sure you want to delete '${listing.title}'?".translate(context),
                style: TextStyle(color: context.color.textLightColor, fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(
                    "Cancel".translate(context),
                    style: TextStyle(color: context.color.textLightColor),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() => isDeleting = true);
                          if (listing.favouritelistingId != null) {
                            final success = await context
                                .read<FavoriteListingsCubit>()
                                .deleteListing(listing.favouritelistingId!);
                            if (success) {
                              onDeleted?.call();
                              if (context.mounted) {
                                HelperUtils.showSnackBarMessage(
                                  context,
                                  "List deleted successfully".translate(context),
                                );
                              }
                            }
                          }
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }
                        },
                  child: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          "Delete".translate(context),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Text(
                "Edit".translate(context),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.share_outlined,
                color: context.color.textDefaultColor,
                size: 22,
              ),
              title: Text(
                "Share list".translate(context),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: context.color.textDefaultColor,
                ),
              ),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.color.textLightColor),
              onTap: () => _shareList(context),
            ),
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: Icon(
                Icons.edit_outlined,
                color: context.color.textDefaultColor,
                size: 22,
              ),
              title: Text(
                "Rename list title".translate(context),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: context.color.textDefaultColor,
                ),
              ),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.color.textLightColor),
              onTap: () => _showRenameDialog(context),
            ),
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
                size: 22,
              ),
              title: Text(
                "Delete list".translate(context),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
                ),
              ),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.color.textLightColor),
              onTap: () => _showDeleteConfirmDialog(context),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
