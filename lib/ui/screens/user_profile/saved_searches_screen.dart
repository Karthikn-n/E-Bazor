import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/saved_search/fetch_saved_searches_cubit.dart';
import 'package:Ebozor/data/model/saved_search_model.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_data_found.dart';
import 'package:Ebozor/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:Ebozor/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SavedSearchesScreen extends StatefulWidget {
  const SavedSearchesScreen({super.key});

  static Route route(RouteSettings settings) {
    return BlurredRouter(
      builder: (context) => BlocProvider(
        create: (context) => FetchSavedSearchesCubit()..fetchSavedSearches(),
        child: const SavedSearchesScreen(),
      ),
    );
  }

  @override
  State<SavedSearchesScreen> createState() => _SavedSearchesScreenState();
}

class _SavedSearchesScreenState extends State<SavedSearchesScreen> {
  final ScrollController _scrollController = ScrollController();
  String _selectedSort = "newest"; // newest, oldest, name_asc

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.isEndReached()) {
      if (context.read<FetchSavedSearchesCubit>().hasMoreData()) {
        context.read<FetchSavedSearchesCubit>().fetchMoreSavedSearches();
      }
    }
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.color.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "Sort Saved Searches",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: const Text("Newest First"),
                trailing: _selectedSort == "newest"
                    ? Icon(Icons.check, color: context.color.territoryColor)
                    : null,
                onTap: () {
                  setState(() => _selectedSort = "newest");
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: const Text("Oldest First"),
                trailing: _selectedSort == "oldest"
                    ? Icon(Icons.check, color: context.color.territoryColor)
                    : null,
                onTap: () {
                  setState(() => _selectedSort = "oldest");
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: const Text("Name (A to Z)"),
                trailing: _selectedSort == "name_asc"
                    ? Icon(Icons.check, color: context.color.territoryColor)
                    : null,
                onTap: () {
                  setState(() => _selectedSort = "name_asc");
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditTitleDialog(SavedSearchModel search) {
    final controller = TextEditingController(text: search.title ?? "");
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.color.secondaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Rename Saved Search",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: context.color.textDefaultColor,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(
            color: context.color.textDefaultColor,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: "Enter search name",
            hintStyle: TextStyle(color: context.color.textLightColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: context.color.borderColor,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              "cancel".translate(context),
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
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty && search.id != null) {
                Navigator.pop(dialogCtx);
                final success = await context
                    .read<FetchSavedSearchesCubit>()
                    .editSavedSearch(id: search.id!, title: newTitle);
                if (mounted && success) {
                  HelperUtils.showSnackBarMessage(
                    context,
                    "Saved search updated successfully",
                    type: MessageType.success,
                  );
                }
              }
            },
            child: const Text(
              "Save",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(SavedSearchModel search) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.color.secondaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Delete Saved Search",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: context.color.textDefaultColor,
          ),
        ),
        content: Text(
          "Are you sure you want to delete '${search.title}'?",
          style: TextStyle(
            fontSize: 13.5,
            color: context.color.textDefaultColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              "cancel".translate(context),
              style: TextStyle(color: context.color.textLightColor),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text(
              "Delete",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true && search.id != null) {
      final success = await context
          .read<FetchSavedSearchesCubit>()
          .deleteSavedSearch(search.id!);
      if (mounted && success) {
        HelperUtils.showSnackBarMessage(
          context,
          "Saved search deleted",
          type: MessageType.success,
        );
      }
      return success;
    }
    return false;
  }

  void _executeSavedSearch(SavedSearchModel search) {
    String? rawUrl = search.apiSearchUrl ?? search.searchUrl;
    Map<String, String> queryParams = {};
    if (rawUrl != null && rawUrl.contains('?')) {
      try {
        final uri = Uri.parse(
            rawUrl.startsWith('http') ? rawUrl : "http://dummy.com/$rawUrl");
        queryParams = uri.queryParameters;
      } catch (_) {}
    }

    final query = queryParams['search'] ?? "";
    final catIdStr = queryParams['category_id'] ??
        (search.categoryId != null && search.categoryId! > 0
            ? search.categoryId.toString()
            : null);

    if (query.isNotEmpty) {
      Navigator.pushNamed(
        context,
        Routes.searchScreenRoute,
        arguments: {
          'autoFocus': false,
          'query': query,
        },
      );
    } else if (catIdStr != null && catIdStr.isNotEmpty && catIdStr != '0') {
      Navigator.pushNamed(
        context,
        Routes.itemsList,
        arguments: {
          'catID': catIdStr,
          'catName': search.title ?? "Search Results",
          'categorySlug': search.categorySlug,
          'categoryIds': [catIdStr],
        },
      );
    } else {
      String fallbackQuery = search.title ?? "";
      if (fallbackQuery.contains(" in ")) {
        fallbackQuery = fallbackQuery.split(" in ").first.trim();
      }
      Navigator.pushNamed(
        context,
        Routes.searchScreenRoute,
        arguments: {
          'autoFocus': false,
          'query': fallbackQuery,
        },
      );
    }
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: context.color.borderColor.withValues(alpha: 0.4),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomShimmer(height: 14, width: 80, borderRadius: 4),
            const SizedBox(height: 8),
            CustomShimmer(height: 18, width: 180, borderRadius: 4),
            const SizedBox(height: 10),
            CustomShimmer(height: 22, width: 100, borderRadius: 4),
          ],
        ),
      ),
    );
  }

  void _showCategoriesBottomSheet(
    List<SavedSearchParentCategory> categories,
    int? selectedId,
    int totalAllCount,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.color.secondaryColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.color.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Select Category",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 20,
                        color: context.color.textLightColor,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Divider(
                height: 1,
                color: context.color.borderColor.withValues(alpha: 0.5),
              ),
              ListTile(
                leading: Icon(
                  Icons.grid_view_rounded,
                  color: selectedId == null
                      ? context.color.territoryColor
                      : context.color.textLightColor,
                  size: 22,
                ),
                title: Text(
                  "All Categories",
                  style: TextStyle(
                    fontWeight: selectedId == null
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: selectedId == null
                        ? context.color.territoryColor
                        : context.color.textDefaultColor,
                  ),
                ),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: selectedId == null
                        ? context.color.territoryColor.withValues(alpha: 0.15)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    totalAllCount.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: selectedId == null
                          ? context.color.territoryColor
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
                onTap: () {
                  context
                      .read<FetchSavedSearchesCubit>()
                      .selectParentCategory(null);
                  Navigator.pop(ctx);
                },
              ),
              ...categories.map((cat) {
                final isSelected = selectedId == cat.id;
                Widget leadingIcon;
                if (cat.image != null && cat.image!.isNotEmpty) {
                  if (cat.image!.endsWith('.svg')) {
                    leadingIcon = SvgPicture.network(
                      cat.image!,
                      width: 22,
                      height: 22,
                      colorFilter: ColorFilter.mode(
                        isSelected
                            ? context.color.territoryColor
                            : context.color.textLightColor,
                        BlendMode.srcIn,
                      ),
                    );
                  } else {
                    leadingIcon = CachedNetworkImage(
                      imageUrl: cat.image!,
                      width: 22,
                      height: 22,
                      errorWidget: (_, __, ___) => Icon(
                        Icons.category_outlined,
                        color: isSelected
                            ? context.color.territoryColor
                            : context.color.textLightColor,
                        size: 22,
                      ),
                    );
                  }
                } else {
                  leadingIcon = Icon(
                    Icons.category_outlined,
                    color: isSelected
                        ? context.color.territoryColor
                        : context.color.textLightColor,
                    size: 22,
                  );
                }

                return ListTile(
                  leading: leadingIcon,
                  title: Text(
                    cat.name ?? "",
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? context.color.territoryColor
                          : context.color.textDefaultColor,
                    ),
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.color.territoryColor.withValues(alpha: 0.15)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      cat.count.toString(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? context.color.territoryColor
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                  onTap: () {
                    context
                        .read<FetchSavedSearchesCubit>()
                        .selectParentCategory(cat.id);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(
    List<SavedSearchParentCategory> categories,
    int? selectedId,
    int totalAllCount,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        border: Border(
          bottom: BorderSide(
            color: context.color.borderColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Leading Menu Icon with Tap Handler
          InkWell(
            onTap: () => _showCategoriesBottomSheet(
              categories,
              selectedId,
              totalAllCount,
            ),
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 14, right: 12, top: 12, bottom: 12),
              child: Icon(
                Icons.menu_rounded,
                color: context.color.textDefaultColor,
                size: 22,
              ),
            ),
          ),
          // Scrollable Tabs
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTabItem(
                    label: "All",
                    count: totalAllCount,
                    isSelected: selectedId == null,
                    onTap: () {
                      context
                          .read<FetchSavedSearchesCubit>()
                          .selectParentCategory(null);
                    },
                  ),
                  ...categories.map((cat) {
                    final isSelected = selectedId == cat.id;
                    return _buildTabItem(
                      label: cat.name ?? "",
                      count: cat.count,
                      isSelected: isSelected,
                      onTap: () {
                        context
                            .read<FetchSavedSearchesCubit>()
                            .selectParentCategory(cat.id);
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final activeColor = Colors.redAccent.shade700;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? activeColor : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? context.color.textDefaultColor
                    : context.color.textLightColor,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected ? Colors.grey.shade300 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.black87 : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<SavedSearchModel> _applySort(List<SavedSearchModel> list) {
    final sorted = List<SavedSearchModel>.from(list);
    if (_selectedSort == "newest") {
      sorted.sort((a, b) => (b.createdAt ?? "").compareTo(a.createdAt ?? ""));
    } else if (_selectedSort == "oldest") {
      sorted.sort((a, b) => (a.createdAt ?? "").compareTo(b.createdAt ?? ""));
    } else if (_selectedSort == "name_asc") {
      sorted.sort((a, b) => (a.title ?? "")
          .toLowerCase()
          .compareTo((b.title ?? "").toLowerCase()));
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.color.secondaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: context.color.textDefaultColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "My Saved Searches",
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: context.color.textDefaultColor,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.search_rounded,
              color: context.color.textDefaultColor,
              size: 22,
            ),
            onPressed: () {
              Navigator.pushNamed(
                context,
                Routes.searchScreenRoute,
                arguments: {'autoFocus': true},
              );
            },
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: context.color.borderColor.withValues(alpha: 0.8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _showSortBottomSheet,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.unfold_more_rounded,
                    size: 18,
                    color: context.color.textDefaultColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Sort",
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: RefreshIndicator(
        color: context.color.territoryColor,
        onRefresh: () async {
          await context.read<FetchSavedSearchesCubit>().fetchSavedSearches();
        },
        child: BlocBuilder<FetchSavedSearchesCubit, FetchSavedSearchesState>(
          builder: (context, state) {
            if (state is FetchSavedSearchesInProgress) {
              return _buildShimmer();
            }

            if (state is FetchSavedSearchesFailure) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: InkWell(
                    onTap: () {
                      context
                          .read<FetchSavedSearchesCubit>()
                          .fetchSavedSearches();
                    },
                    child: const SomethingWentWrong(),
                  ),
                ),
              );
            }

            if (state is FetchSavedSearchesSuccess) {
              final displayedSearches = _applySort(state.filteredSearches);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Parent Category Tabs
                  _buildTabBar(
                    state.parentCategories,
                    state.selectedParentCategoryId,
                    state.total,
                  ),

                  Expanded(
                    child: displayedSearches.isEmpty
                        ? Center(
                            child: NoDataFound(
                              onTap: () {
                                context
                                    .read<FetchSavedSearchesCubit>()
                                    .fetchSavedSearches();
                              },
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.only(bottom: 72),
                            itemCount: displayedSearches.length +
                                (state.isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == displayedSearches.length) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: UiUtils.progress(
                                      normalProgressColor:
                                          context.color.territoryColor,
                                    ),
                                  ),
                                );
                              }

                              final search = displayedSearches[index];
                              return _SwipeableSavedSearchTile(
                                key: ValueKey("saved_search_tile_${search.id}"),
                                search: search,
                                onTap: () => _executeSavedSearch(search),
                                onRename: () => _showEditTitleDialog(search),
                                onDelete: () => _confirmDelete(search),
                              );
                            },
                          ),
                  ),
                ],
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _SwipeableSavedSearchTile extends StatefulWidget {
  final SavedSearchModel search;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _SwipeableSavedSearchTile({
    super.key,
    required this.search,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_SwipeableSavedSearchTile> createState() =>
      _SwipeableSavedSearchTileState();
}

class _SwipeableSavedSearchTileState extends State<_SwipeableSavedSearchTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  double _dragOffset = 0.0;
  static const double _actionsWidth = 150.0; // 75px for More, 75px for Delete

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = Tween<double>(begin: 0, end: 0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset =
          (_dragOffset + details.primaryDelta!).clamp(-_actionsWidth, 0.0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final threshold = -_actionsWidth / 2;
    if (_dragOffset < threshold || details.primaryVelocity! < -300) {
      // Snap open
      _animateTo(-_actionsWidth);
    } else {
      // Snap close
      _animateTo(0.0);
    }
  }

  void _animateTo(double target) {
    _animation = Tween<double>(begin: _dragOffset, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    )..addListener(() {
        setState(() {
          _dragOffset = _animation.value;
        });
      });
    _controller.forward(from: 0.0);
  }

  void _close() {
    if (_dragOffset != 0.0) {
      _animateTo(0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final search = widget.search;
    final locationText = search.location?.isNotEmpty == true
        ? search.location!.toUpperCase()
        : "DUBAI";

    // Category / Hierarchy name
    String categorySubtitle = "";
    if (search.categoryHierarchy.isNotEmpty) {
      categorySubtitle = search.categoryHierarchy.first;
    } else if (search.categorySlug != null && search.categorySlug!.isNotEmpty) {
      categorySubtitle =
          search.categorySlug!.replaceAll('-', ' ').toUpperCase();
    } else {
      categorySubtitle = "Cars";
    }

    return Container(
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        border: Border(
          bottom: BorderSide(
            color: context.color.borderColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Stack(
        children: [
          // Action Buttons Behind the Tile (Right Side)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: _actionsWidth,
            child: Row(
              children: [
                // "More" Button (Grey)
                Expanded(
                  child: Material(
                    color: const Color(0xFFB0B0B8),
                    child: InkWell(
                      onTap: () {
                        _close();
                        widget.onRename();
                      },
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.more_horiz_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                          SizedBox(height: 2),
                          Text(
                            "More",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // "Delete" Button (Red)
                Expanded(
                  child: Material(
                    color: const Color(0xFFE54B4B),
                    child: InkWell(
                      onTap: () {
                        _close();
                        widget.onDelete();
                      },
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          SizedBox(height: 2),
                          Text(
                            "Delete",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Tile Content (Slides horizontally on drag)
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: Container(
              color: context.color.secondaryColor,
              child: GestureDetector(
                onHorizontalDragUpdate: _onHorizontalDragUpdate,
                onHorizontalDragEnd: _onHorizontalDragEnd,
                child: InkWell(
                  onTap: () {
                    if (_dragOffset != 0.0) {
                      _close();
                    } else {
                      widget.onTap();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Category Subtitle
                              Text(
                                categorySubtitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.color.textLightColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Search Title
                              Text(
                                search.title ?? "Search",
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: context.color.textDefaultColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),

                              // Location Pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  locationText,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Image Thumbnails Row (if any)
                              if (search.photos.isNotEmpty)
                                Row(
                                  children:
                                      search.photos.take(3).map((photoUrl) {
                                    return Container(
                                      margin: const EdgeInsets.only(right: 6),
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        color: Colors.grey.shade100,
                                        border: Border.all(
                                          color: context.color.borderColor
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: CachedNetworkImage(
                                        imageUrl: photoUrl,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Icon(
                                          Icons.image_outlined,
                                          size: 20,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        ),

                        // Right Actions (Bell icon & 3-dots Menu)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              search.notification == true
                                  ? Icons.notifications_active_outlined
                                  : Icons.notifications_off_outlined,
                              size: 21,
                              color: context.color.textDefaultColor,
                            ),
                            const SizedBox(width: 8),
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert_rounded,
                                size: 21,
                                color: context.color.textDefaultColor,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onSelected: (val) {
                                if (val == "rename") {
                                  widget.onRename();
                                } else if (val == "delete") {
                                  widget.onDelete();
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: "rename",
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 18),
                                      SizedBox(width: 10),
                                      Text("Rename"),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: "delete",
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded,
                                          size: 18, color: Colors.redAccent),
                                      SizedBox(width: 10),
                                      Text(
                                        "Delete",
                                        style:
                                            TextStyle(color: Colors.redAccent),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
