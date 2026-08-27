import 'package:Ebozor/data/cubits/saved_search/fetch_saved_searches_cubit.dart';
import 'package:Ebozor/data/cubits/saved_search/save_search_cubit.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SaveSearchBottomSheet extends StatefulWidget {
  final int? savedSearchId;
  final String? initialTitle;
  final int? categoryId;
  final int? parentCategoryId;
  final String? categorySlug;
  final String? searchUrl;
  final String? apiSearchUrl;
  final String? location;
  final bool initialNotification;
  final bool initialSubscribeEmail;
  final bool isAlreadySaved;

  const SaveSearchBottomSheet({
    super.key,
    this.savedSearchId,
    this.initialTitle,
    this.categoryId,
    this.parentCategoryId,
    this.categorySlug,
    this.searchUrl,
    this.apiSearchUrl,
    this.location,
    this.initialNotification = true,
    this.initialSubscribeEmail = false,
    this.isAlreadySaved = false,
  });

  static Future<void> show(
    BuildContext context, {
    int? savedSearchId,
    String? initialTitle,
    int? categoryId,
    int? parentCategoryId,
    String? categorySlug,
    String? searchUrl,
    String? apiSearchUrl,
    String? location,
    bool initialNotification = true,
    bool initialSubscribeEmail = false,
    bool isAlreadySaved = false,
  }) async {
    if (!HiveUtils.isUserAuthenticated()) {
      UiUtils.checkUser(
        onNotGuest: () {},
        context: context,
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BlocProvider(
        create: (_) => SaveSearchCubit(),
        child: SaveSearchBottomSheet(
          savedSearchId: savedSearchId,
          initialTitle: initialTitle,
          categoryId: categoryId,
          parentCategoryId: parentCategoryId,
          categorySlug: categorySlug,
          searchUrl: searchUrl,
          apiSearchUrl: apiSearchUrl,
          location: location,
          initialNotification: initialNotification,
          initialSubscribeEmail: initialSubscribeEmail,
          isAlreadySaved: isAlreadySaved,
        ),
      ),
    );
  }

  @override
  State<SaveSearchBottomSheet> createState() => _SaveSearchBottomSheetState();
}

class _SaveSearchBottomSheetState extends State<SaveSearchBottomSheet> {
  late final TextEditingController _titleController;
  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? "");
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _onSaveNew() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please enter a search name",
        type: MessageType.warning,
      );
      return;
    }

    context.read<SaveSearchCubit>().saveSearch(
          title: title,
          categoryId: widget.categoryId,
          parentCategoryId: widget.parentCategoryId,
          categorySlug: widget.categorySlug,
          searchUrl: widget.searchUrl,
          apiSearchUrl: widget.apiSearchUrl,
          location: widget.location,
        );
  }

  Future<void> _onUpdateExisting() async {
    if (widget.savedSearchId == null) return;
    final newTitle = _titleController.text.trim();
    if (newTitle.isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please enter a search name",
        type: MessageType.warning,
      );
      return;
    }

    setState(() => _isActionInProgress = true);
    final success = await context
        .read<FetchSavedSearchesCubit>()
        .editSavedSearch(id: widget.savedSearchId!, title: newTitle);
    setState(() => _isActionInProgress = false);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        HelperUtils.showSnackBarMessage(
          context,
          "Saved search updated successfully!",
          type: MessageType.success,
        );
      } else {
        HelperUtils.showSnackBarMessage(
          context,
          "Failed to update saved search",
          type: MessageType.error,
        );
      }
    }
  }

  Future<void> _onDeleteExisting() async {
    if (widget.savedSearchId == null) return;

    setState(() => _isActionInProgress = true);
    final success = await context
        .read<FetchSavedSearchesCubit>()
        .deleteSavedSearch(widget.savedSearchId!);
    setState(() => _isActionInProgress = false);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        HelperUtils.showSnackBarMessage(
          context,
          "Saved search removed",
          type: MessageType.success,
        );
      } else {
        HelperUtils.showSnackBarMessage(
          context,
          "Failed to delete saved search",
          type: MessageType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isAlreadySaved =
        widget.isAlreadySaved || widget.savedSearchId != null;

    return BlocConsumer<SaveSearchCubit, SaveSearchState>(
      listener: (context, state) {
        if (state is SaveSearchSuccess) {
          // Add newly saved search to FetchSavedSearchesCubit state
          context
              .read<FetchSavedSearchesCubit>()
              .addSavedSearch(state.savedSearch);
          Navigator.pop(context);
          HelperUtils.showSnackBarMessage(
            context,
            "Search saved successfully!",
            type: MessageType.success,
          );
        } else if (state is SaveSearchFailure) {
          HelperUtils.showSnackBarMessage(
            context,
            state.errorMessage.toString(),
            type: MessageType.error,
          );
        }
      },
      builder: (context, state) {
        final isLoading = (state is SaveSearchProgress) || _isActionInProgress;

        return Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle Bar
                Center(
                  child: Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: context.color.borderColor.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.color.territoryColor
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isAlreadySaved
                                ? Icons.bookmark_added_rounded
                                : Icons.bookmark_add_outlined,
                            size: 22,
                            color: context.color.territoryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isAlreadySaved ? "Saved Search" : "Save Search",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.color.textDefaultColor,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: context.color.textLightColor,
                        size: 22,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isAlreadySaved
                      ? "You have already saved this search. You can rename or delete it."
                      : "Save this search to find it again quickly.",
                  style: TextStyle(
                    fontSize: 13,
                    color: context.color.textLightColor,
                  ),
                ),
                const SizedBox(height: 20),

                // Title Input
                Text(
                  "Search Name",
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.color.textDefaultColor,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: context.color.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.color.borderColor.withValues(alpha: 0.8),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _titleController,
                    autofocus: false,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: context.color.textDefaultColor,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: "e.g. 2 BHK Apartments in Dubai",
                      hintStyle: TextStyle(
                        fontSize: 13.5,
                        color: context.color.textLightColor,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: context.color.textLightColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Save or Update Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : (isAlreadySaved ? _onUpdateExisting : _onSaveNew),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.color.territoryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            isAlreadySaved ? "Update Search" : "Save Search",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                // Delete Button (if already saved)
                if (isAlreadySaved) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: isLoading ? null : _onDeleteExisting,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(
                            color: Colors.redAccent, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text(
                        "Delete Saved Search",
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
