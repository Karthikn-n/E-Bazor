import 'dart:async';
import 'dart:math';
import 'package:Ebozor/utils/string_extenstion.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/ui/screens/widgets/dialogs/save_to_favorite_bottom_sheet.dart';
import 'package:Ebozor/data/cubits/favorite/favorite_cubit.dart';
import 'package:Ebozor/data/cubits/favorite/manage_fav_cubit.dart';
import 'package:Ebozor/data/repositories/favourites_repository.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/item/fetch_item_from_category_cubit.dart';
import 'package:Ebozor/data/cubits/category/fetch_sub_categories_cubit.dart';
import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/data/repositories/category_repository.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/sliver_grid_delegate_with_fixed_cross_axis_count_and_fixed_height.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/data/model/item_filter_model.dart';

import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ApiService/api.dart';

import 'package:Ebozor/utils/responsiveSize.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/ui/screens/home/widgets/home_sections_adapter.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_data_found.dart';
import 'package:Ebozor/ui/screens/main_activity.dart';
import 'package:Ebozor/data/cubits/saved_search/fetch_saved_searches_cubit.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/bottom_sheets/save_search_bottom_sheet.dart';
import 'package:Ebozor/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:Ebozor/ui/screens/chat/chat_screen.dart';
import 'package:Ebozor/data/cubits/chat/load_chat_messages.dart';
import 'package:Ebozor/data/cubits/chat/delete_message_cubit.dart';

class ItemsList extends StatefulWidget {
  final String categoryId, categoryName;
  final String? initialSearch;
  final List<String>? categoryIds;
  final List<CategoryModel>? selectedCategoryChain;
  final ItemFilterModel? appliedFilter;
  final FilterCategory? filterConfiguration;

  const ItemsList(
      {super.key,
      required this.categoryId,
      required this.categoryName,
      this.initialSearch,
      this.categoryIds,
      this.selectedCategoryChain,
      this.appliedFilter,
      this.filterConfiguration});

  @override
  ItemsListState createState() => ItemsListState();

  static Route route(RouteSettings routeSettings) {
    Map? arguments = routeSettings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => ItemsList(
        categoryId: (arguments?['catID'] ?? "").toString(),
        categoryName: (arguments?['catName'] ?? "").toString(),
        initialSearch: arguments?['search']?.toString(),
        categoryIds: arguments?['categoryIds'] != null
            ? List<String>.from(arguments!['categoryIds'])
            : [],
        selectedCategoryChain:
            arguments?['selectedCategoryChain'] as List<CategoryModel>?,
        appliedFilter: arguments?['appliedFilter'] as ItemFilterModel?,
        filterConfiguration:
            arguments?['filterConfiguration'] as FilterCategory?,
      ),
    );
  }
}

class ItemsListState extends State<ItemsList> {
  late ScrollController controller;
  static TextEditingController searchController = TextEditingController();
  bool isFocused = false;
  bool isList = true;
  String previousSearchQuery = "";
  Timer? _searchDelay;
  String? sortBy;
  ItemFilterModel? filter;

  // For dynamic filtering
  late List<CategoryModel> _currentChain;
  late final FetchSubCategoriesCubit _chipFilterCubit;
  List<String> _currentCategoryIds = [];
  FilterCategory? _propertyFilterConfiguration;

  bool _showVerifiedOnly = false;

  String _selectedRentSaleLabel = "Rent";
  String _selectedPropertyTypeLabel = "Property Type";
  String _selectedRoomsLabel = "Bedrooms";
  String _selectedBathroomsLabel = "Bathrooms";
  String _selectedPriceRangeLabel = "Price Range";
  String _selectedRoomTypeLabel = "Room type";
  String _selectedJobTypeLabel = "Job Type";
  String _selectedJobGenderLabel = "Gender";

  bool _isJobsVertical() {
    final catId = widget.categoryId;
    final catName = widget.categoryName.toLowerCase();
    final catIds = widget.categoryIds ?? [];
    if (catId == '4' ||
        catId == '356' ||
        catId == '357' ||
        catIds.contains('4') ||
        catIds.contains('356') ||
        catIds.contains('357') ||
        _currentCategoryIds.contains('4') ||
        _currentCategoryIds.contains('356') ||
        _currentCategoryIds.contains('357') ||
        catName.contains('job') ||
        catName.contains('recruit') ||
        catName.contains('talent')) {
      return true;
    }
    if (_currentChain.any((c) {
      final name = (c.name ?? '').toLowerCase();
      final slug = (c.slug ?? '').toLowerCase();
      final id = c.id?.toString() ?? '';
      return id == '4' ||
          id == '356' ||
          id == '357' ||
          name.contains('job') ||
          name.contains('recruit') ||
          name.contains('talent') ||
          slug.contains('job');
    })) {
      return true;
    }
    return false;
  }

  bool _isPropertyVertical() {
    if (_isJobsVertical()) return false;
    const propertyIds = ['65', '68', '139', '143', '144', '145', '146'];
    final catId = widget.categoryId;
    if (propertyIds.contains(catId)) return true;
    final catIds = widget.categoryIds ?? [];
    if (catIds.any((id) => propertyIds.contains(id))) return true;
    if (_currentCategoryIds.any((id) => propertyIds.contains(id))) return true;

    final catName = widget.categoryName.toLowerCase();
    if (catName.contains('property') ||
        catName.contains('residential') ||
        catName.contains('commercial') ||
        catName.contains('off-plan') ||
        catName.contains('off plan') ||
        (catName.contains('rent') && !catName.contains('car')) ||
        (catName.contains('sale') &&
            !catName.contains('car') &&
            !catName.contains('motor') &&
            !catName.contains('job'))) {
      return true;
    }
    if (_currentChain.any((c) {
      final name = (c.name ?? '').toLowerCase();
      final slug = (c.slug ?? '').toLowerCase();
      final id = c.id?.toString() ?? '';
      return propertyIds.contains(id) ||
          name.contains('property') ||
          name.contains('residential') ||
          name.contains('off-plan') ||
          (name.contains('rent') && !name.contains('car')) ||
          slug.contains('property') ||
          slug.contains('residential') ||
          slug.contains('off-plan') ||
          (slug.contains('rent') && !slug.contains('car'));
    })) {
      return true;
    }
    return false;
  }

  int get _activeCategoryId {
    final filterCategoryId = int.tryParse(filter?.categoryId ?? '');
    if (filterCategoryId != null && filterCategoryId > 0) {
      return filterCategoryId;
    }
    if (_currentCategoryIds.isNotEmpty) {
      final currentId = int.tryParse(_currentCategoryIds.last);
      if (currentId != null && currentId > 0) return currentId;
    }
    return int.tryParse(widget.categoryId) ?? 0;
  }

  String _normalizeFilterName(String name) {
    var normalized = name.trim();
    if (normalized.startsWith('filters[') && normalized.endsWith(']')) {
      normalized = normalized.substring(8, normalized.length - 1);
    }
    return normalized.trim().toLowerCase();
  }

  dynamic _customFilterValue(String fieldName) {
    final customFields = filter?.customFields;
    if (customFields == null) return null;
    final target = _normalizeFilterName(fieldName);
    for (final entry in customFields.entries) {
      if (_normalizeFilterName(entry.key) == target) return entry.value;
    }
    return null;
  }

  String? _singleCustomFilterValue(String fieldName) {
    final value = _customFilterValue(fieldName);
    if (value is Iterable) {
      final values = value.map((e) => e.toString()).toList();
      return values.isEmpty ? null : values.first;
    }
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  FilterItem? _propertyFilterByNames(List<String> names) {
    final filters =
        _propertyFilterConfiguration?.filters ?? const <FilterItem>[];
    final normalizedNames = names.map(_normalizeFilterName).toSet();
    for (final propertyFilter in filters) {
      final name = propertyFilter.name;
      if (name != null &&
          normalizedNames.contains(_normalizeFilterName(name))) {
        return propertyFilter;
      }
    }
    return null;
  }

  void _setCustomFilterValue(String fieldName, String? value) {
    final updatedCustom = Map<String, dynamic>.from(
      filter?.customFields ?? const <String, dynamic>{},
    );
    final target = _normalizeFilterName(fieldName);
    updatedCustom.removeWhere(
      (key, _) => _normalizeFilterName(key) == target,
    );
    if (value != null && value.trim().isNotEmpty) {
      updatedCustom[fieldName] = value.trim();
    }
    filter =
        (filter ?? ItemFilterModel(categoryId: _activeCategoryId.toString()))
            .copyWith(customFields: updatedCustom);
    Constant.itemFilter = filter;
  }

  void _setDynamicCustomFilterValue(String fieldName, dynamic value) {
    final updatedCustom = Map<String, dynamic>.from(
      filter?.customFields ?? const <String, dynamic>{},
    );
    final target = _normalizeFilterName(fieldName);
    updatedCustom.removeWhere(
      (key, _) => _normalizeFilterName(key) == target,
    );
    if (_isMeaningfulFilterValue(value)) {
      updatedCustom[fieldName] = value;
    }
    filter =
        (filter ?? ItemFilterModel(categoryId: _activeCategoryId.toString()))
            .copyWith(customFields: updatedCustom);
    Constant.itemFilter = filter;
  }

  List<FilterItem> get _jobQuickFilters =>
      (_propertyFilterConfiguration?.filters ?? const <FilterItem>[])
          .where((item) =>
              (item.name?.trim().isNotEmpty ?? false) && item.values.isNotEmpty)
          .toList();

  String _jobFilterLabel(FilterItem item) {
    final name = item.name?.trim() ?? 'Filter';
    final value = _customFilterValue(name);
    if (value is Iterable && value is! String) {
      final selected = value
          .map((entry) => entry.toString().trim())
          .where((entry) => entry.isNotEmpty)
          .toList();
      if (selected.isEmpty) return name;
      if (selected.length == 1) return selected.first;
      return '$name (${selected.length})';
    }
    final selected = value?.toString().trim() ?? '';
    return selected.isEmpty ? name : selected;
  }

  Future<void> _showJobApiQuickFilter(FilterItem item) async {
    final fieldName = item.name?.trim();
    if (fieldName == null || fieldName.isEmpty || item.values.isEmpty) return;

    final existing = _customFilterValue(fieldName);
    final selected = <String>{};
    if (existing is Iterable && existing is! String) {
      selected.addAll(existing.map((entry) => entry.toString()));
    } else if (existing != null && existing.toString().trim().isNotEmpty) {
      selected.add(existing.toString());
    }

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Material(
              color: sheetContext.color.secondaryColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: sheetContext.color.borderColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          fieldName,
                          style: TextStyle(
                            color: sheetContext.color.textDefaultColor,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: item.values.map((option) {
                                final isSelected = selected.contains(option);
                                return ChoiceChip(
                                  label: Text(option),
                                  selected: isSelected,
                                  onSelected: (_) {
                                    setSheetState(() {
                                      if (item.multiSelect) {
                                        isSelected
                                            ? selected.remove(option)
                                            : selected.add(option);
                                      } else {
                                        selected
                                          ..clear()
                                          ..add(option);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(
                                  sheetContext,
                                  <String, dynamic>{
                                    'apply': true,
                                    'value': null,
                                  },
                                ),
                                child: const Text('Clear'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  final value = item.multiSelect
                                      ? selected.toList()
                                      : (selected.isEmpty
                                          ? null
                                          : selected.first);
                                  Navigator.pop(
                                    sheetContext,
                                    <String, dynamic>{
                                      'apply': true,
                                      'value': value,
                                    },
                                  );
                                },
                                child: const Text('Apply'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || result?['apply'] != true) return;
    setState(() {
      _setDynamicCustomFilterValue(fieldName, result?['value']);
    });
    _fetchFilteredItems();
  }

  void _fetchFilteredItems() {
    final categoryId = _activeCategoryId;
    if (categoryId == 0) return;
    context.read<FetchItemFromCategoryCubit>().fetchItemFromCategory(
          categoryId: categoryId,
          search: searchController.text,
          sortBy: sortBy,
          filter: filter,
        );
  }

  Future<void> _loadPropertyFilterConfiguration(String slug) async {
    if (slug.isEmpty) return;
    try {
      final configuration = await FilterRepository().getFilters(slug);
      if (!mounted) return;
      setState(() {
        _propertyFilterConfiguration = configuration;
        _syncQuickFilterLabelsFromFilter();
      });
    } catch (_) {
      // The full filter screen remains available if the quick-filter metadata
      // cannot be refreshed.
    }
  }

  bool _isMeaningfulFilterValue(dynamic value) {
    if (value == null) return false;
    if (value is Iterable) return value.isNotEmpty;
    return value.toString().trim().isNotEmpty;
  }

  int get _activeFiltersCount {
    var count = 0;
    if ((filter?.minPrice?.isNotEmpty ?? false) ||
        (filter?.maxPrice?.isNotEmpty ?? false)) {
      count++;
    }
    if (filter?.postedSince?.isNotEmpty ?? false) count++;
    if ((filter?.city?.isNotEmpty ?? false) &&
        filter!.city != (HiveUtils.getCityName() ?? '')) {
      count++;
    }
    final uniqueNames = <String>{};
    filter?.customFields?.forEach((key, value) {
      if (_isMeaningfulFilterValue(value)) {
        uniqueNames.add(_normalizeFilterName(key));
      }
    });
    return count + uniqueNames.length;
  }

  void _launchCall(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      HelperUtils.showSnackBarMessage(context, "Phone number not available");
      return;
    }
    final url = Uri.parse("tel:${phone.trim()}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      HelperUtils.showSnackBarMessage(context, "Could not launch phone call");
    }
  }

  void _launchSMS(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      HelperUtils.showSnackBarMessage(context, "Phone number not available");
      return;
    }
    final url = Uri.parse("sms:${phone.trim()}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      HelperUtils.showSnackBarMessage(context, "Could not open SMS app");
    }
  }

  void _openChat(BuildContext context, ItemModel item) {
    UiUtils.checkUser(
      onNotGuest: () {
        Navigator.push(
          context,
          BlurredRouter(
            builder: (context) {
              return MultiBlocProvider(
                providers: [
                  BlocProvider(
                    create: (context) => LoadChatMessagesCubit(),
                  ),
                  BlocProvider(
                    create: (context) => DeleteMessageCubit(),
                  ),
                ],
                child: Builder(builder: (context) {
                  return ChatScreen(
                    profilePicture: item.user?.profile ?? "",
                    itemTitle: item.name ?? "",
                    userId: item.user?.id?.toString() ??
                        item.userId?.toString() ??
                        "",
                    itemImage: item.image ?? "",
                    userName: item.user?.name ?? "",
                    itemId: item.id?.toString() ?? "",
                    date: item.created ?? "",
                    from: "item",
                    itemOfferId: 0,
                    itemPrice: item.price ?? 0.0,
                    itemOfferPrice: null,
                    status: item.status,
                    buyerId: HiveUtils.getUserId(),
                    alreadyReview: false,
                    isPurchased: item.isPurchased ?? 0,
                  );
                }),
              );
            },
          ),
        );
      },
      context: context,
    );
  }

  Widget _favButton(BuildContext context, ItemModel item) {
    if (item.id == null) return const SizedBox.shrink();
    bool isLike = context.read<FavoriteCubit>().isItemFavorite(item.id!);

    return BlocProvider(
      create: (context) => UpdateFavoriteCubit(FavoriteRepository()),
      child: BlocConsumer<FavoriteCubit, FavoriteState>(
        bloc: context.read<FavoriteCubit>(),
        listener: ((context, state) {
          if (state is FavoriteFetchSuccess) {
            isLike = context.read<FavoriteCubit>().isItemFavorite(item.id!);
          }
        }),
        builder: (context, likeAndDislikeState) {
          return BlocConsumer<UpdateFavoriteCubit, UpdateFavoriteState>(
            bloc: context.read<UpdateFavoriteCubit>(),
            listener: ((context, state) {
              if (state is UpdateFavoriteSuccess) {
                if (state.wasProcess) {
                  context.read<FavoriteCubit>().addFavoriteitem(state.item);
                } else {
                  context.read<FavoriteCubit>().removeFavoriteItem(state.item);
                }
              }
            }),
            builder: (context, state) {
              return InkWell(
                onTap: () {
                  UiUtils.checkUser(
                    onNotGuest: () {
                      if (isLike) {
                        context.read<UpdateFavoriteCubit>().setFavoriteItem(
                              item: item,
                              type: 0,
                            );
                        return;
                      }
                      context.read<UpdateFavoriteCubit>().setFavoriteItem(
                            item: item,
                            type: 1,
                          );
                      SaveToFavoriteBottomSheet.show(context, item: item);
                    },
                    context: context,
                  );
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: state is UpdateFavoriteInProgress
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isLike ? Icons.favorite : Icons.favorite_border,
                            size: 19,
                            color: isLike ? Colors.red : Colors.white,
                          ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _chipFilterCubit = FetchSubCategoriesCubit();
    // Initialize chain from arguments or empty
    _currentChain = widget.selectedCategoryChain != null
        ? List.from(widget.selectedCategoryChain!)
        : [];
    if (_currentChain.isEmpty && widget.categoryId.isNotEmpty) {
      _currentChain.add(CategoryModel(
          id: int.tryParse(widget.categoryId) ?? 0,
          name: widget.categoryName,
          children: [],
          subcategoriesCount: 0));
    }

    _currentCategoryIds =
        widget.categoryIds != null ? List.from(widget.categoryIds!) : [];
    _propertyFilterConfiguration = widget.filterConfiguration;
    searchbody = {};
    filter = widget.appliedFilter ?? Constant.itemFilter;
    searchController = TextEditingController(text: widget.initialSearch ?? '');
    previousSearchQuery = widget.initialSearch?.trim() ?? '';
    searchController.addListener(searchItemListener);
    controller = ScrollController()..addListener(_loadMore);

    ItemFilterModel initialFilter = filter ??
        ItemFilterModel(
            country: HiveUtils.getCountryName() ?? "",
            areaId: HiveUtils.getAreaId() != null
                ? int.parse(HiveUtils.getAreaId().toString())
                : null,
            city: HiveUtils.getCityName() ?? "",
            state: HiveUtils.getStateName() ?? "",
            categoryId: widget.categoryId,
            radius: HiveUtils.getNearbyRadius() ?? null,
            latitude: HiveUtils.getLatitude() ?? null,
            longitude: HiveUtils.getLongitude() ?? null);

    filter = initialFilter;
    Constant.itemFilter = initialFilter;

    final catIdLower = widget.categoryId;
    final catNameLower = widget.categoryName.toLowerCase();
    final catSlugLower = (filter?.categorySlug ??
            _propertyFilterConfiguration?.slug ??
            (_currentChain.isNotEmpty ? _currentChain.last.slug : null) ??
            '')
        .toLowerCase();
    if (catIdLower == '143' ||
        catNameLower.contains('off-plan') ||
        catNameLower.contains('off plan') ||
        catSlugLower.contains('off-plan') ||
        catSlugLower.contains('new-project')) {
      _selectedRentSaleLabel = "Off-Plan";
    } else if (catIdLower == '139' ||
        catNameLower.contains('sale') ||
        catNameLower.contains('buy') ||
        catSlugLower.contains('property-for-sale')) {
      _selectedRentSaleLabel = "Buy";
    } else if (catIdLower == '68' || catNameLower.contains('room')) {
      _selectedRentSaleLabel = "Rent";
    } else {
      _selectedRentSaleLabel = "Rent";
    }

    _syncQuickFilterLabelsFromFilter();
    if ((_isPropertyVertical() || _isJobsVertical()) &&
        _propertyFilterConfiguration == null) {
      final configurationSlug = filter?.categorySlug ??
          (_currentChain.isNotEmpty ? _currentChain.last.slug : null) ??
          '';
      if (configurationSlug.isNotEmpty) {
        _loadPropertyFilterConfiguration(configurationSlug);
      }
    }

    if (HiveUtils.isUserAuthenticated()) {
      context.read<FetchSavedSearchesCubit>().fetchSavedSearches();
    }

    final catIdInt = _activeCategoryId;
    if (catIdInt != 0) {
      context.read<FetchItemFromCategoryCubit>().fetchItemFromCategory(
          categoryId: catIdInt,
          search: widget.initialSearch?.trim() ?? '',
          filter: initialFilter);
    }

    Future.delayed(Duration.zero, () {
      selectedcategoryId = widget.categoryId;
      selectedcategoryName = widget.categoryName;
      searchbody[Api.categoryId] = widget.categoryId;
      setState(() {});
    });
  }

  @override
  void dispose() {
    controller.removeListener(_loadMore);
    controller.dispose();
    searchController.dispose();
    _chipFilterCubit.close();
    super.dispose();
  }

  //this will listen and manage search
  void searchItemListener() {
    _searchDelay?.cancel();
    searchCallAfterDelay();
  }

//This will create delay so we don't face rapid api call
  void searchCallAfterDelay() {
    _searchDelay = Timer(const Duration(milliseconds: 500), itemSearch);
  }

  ///This will call api after some delay
  void itemSearch() {
    // if (searchController.text.isNotEmpty) {
    if (previousSearchQuery != searchController.text) {
      _fetchFilteredItems();
      previousSearchQuery = searchController.text;
      setState(() {});
    }
  }

  void _loadMore() async {
    if (controller.isEndReached()) {
      if (context.read<FetchItemFromCategoryCubit>().hasMoreData()) {
        context.read<FetchItemFromCategoryCubit>().fetchItemFromCategoryMore(
            catId: _activeCategoryId,
            search: searchController.text,
            sortBy: sortBy,
            filter: filter);
      }
    }
  }

  Widget _buildLocationHeader() {
    return Container(
      color: context.color.backgroundColor,
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: context.color.textDefaultColor,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                border: Border.all(
                  width: 1,
                  color: context.color.borderColor.withValues(alpha: 0.7),
                ),
                borderRadius: BorderRadius.circular(10),
                color: context.color.secondaryColor,
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Icon(
                    _isJobsVertical()
                        ? Icons.search_rounded
                        : (_isPropertyVertical()
                            ? Icons.location_on
                            : Icons.search_rounded),
                    size: 20,
                    color: context.color.textDefaultColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: searchController,
                      style: TextStyle(
                        color: context.color.textDefaultColor,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: _isJobsVertical()
                            ? "Search job title, role or keywords..."
                            : (_isPropertyVertical()
                                ? "Enter Neighborhood or Building"
                                : "Search in ${widget.categoryName.isNotEmpty ? widget.categoryName : 'Items'}..."),
                        hintStyle: TextStyle(
                          color: context.color.textLightColor,
                          fontSize: 13,
                        ),
                      ),
                      onEditingComplete: () {
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  ),
                  if (searchController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 16,
                        color: context.color.textLightColor,
                      ),
                      onPressed: () {
                        searchController.clear();
                        setState(() {});
                        final catIdInt = _activeCategoryId;
                        if (catIdInt != 0) {
                          context
                              .read<FetchItemFromCategoryCubit>()
                              .fetchItemFromCategory(
                                categoryId: catIdInt,
                                search: "",
                                filter: filter,
                              );
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _selectedSegmentValue;
  String? _detectedFilterFieldName;

  List<String> _extractDynamicSegments(List<ItemModel> items) {
    if (_isPropertyVertical()) {
      final furnishingFilter = _propertyFilterByNames(
        const ['Is it furnished?', 'Furnishing', 'Furnished'],
      );
      if (furnishingFilter == null) return const [];
      _detectedFilterFieldName = furnishingFilter.name;
      return furnishingFilter.values;
    }

    if (items.isEmpty) return [];

    Map<String, Set<String>> fieldValues = {};

    for (var item in items) {
      if (item.customFields == null) continue;
      for (var cf in item.customFields!) {
        final fieldName = (cf.name ?? "").trim();
        if (fieldName.isEmpty) continue;

        dynamic rawVal = cf.value;
        String val = "";
        if (rawVal is List && rawVal.isNotEmpty) {
          val = rawVal.first?.toString() ?? "";
        } else if (rawVal != null) {
          val = rawVal.toString();
        }
        val = val.trim();
        // Exclude purely numeric ID values (e.g. "65", "64")
        if (val.isNotEmpty && val.length < 25 && int.tryParse(val) == null) {
          fieldValues.putIfAbsent(fieldName, () => {}).add(val);
        }
      }
    }

    final priorityKeys = _isJobsVertical()
        ? [
            "job type",
            "employment type",
            "career level",
            "gender",
            "qualification",
            "experience",
          ]
        : [
            "furnished",
            "transmission",
            "condition",
            "fuel type",
            "fuel",
            "body type",
            "property type",
            "type",
          ];

    for (var key in priorityKeys) {
      for (var entry in fieldValues.entries) {
        if (entry.key.toLowerCase().contains(key) &&
            entry.value.length >= 2 &&
            entry.value.length <= 6) {
          _detectedFilterFieldName = entry.key;
          return entry.value.toList();
        }
      }
    }

    for (var entry in fieldValues.entries) {
      if (entry.value.length >= 2 && entry.value.length <= 5) {
        _detectedFilterFieldName = entry.key;
        return entry.value.toList();
      }
    }

    return [];
  }

  Widget _buildDynamicSegmentTabs(List<ItemModel> items) {
    final segmentOptions = _extractDynamicSegments(items);
    if (segmentOptions.isEmpty) {
      return const SizedBox.shrink();
    }

    List<String> allTabs = ["All", ...segmentOptions];

    return Container(
      color: context.color.backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: allTabs.map((tabTitle) {
            final isSelected =
                (tabTitle == "All" && _selectedSegmentValue == null) ||
                    (_selectedSegmentValue != null &&
                        _selectedSegmentValue!.toLowerCase() ==
                            tabTitle.toLowerCase());

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    if (tabTitle == "All") {
                      _selectedSegmentValue = null;
                      if (_isPropertyVertical()) {
                        _setCustomFilterValue(
                          _detectedFilterFieldName ?? 'Is it furnished?',
                          null,
                        );
                      }
                    } else {
                      _selectedSegmentValue = tabTitle;
                      if (_isPropertyVertical()) {
                        _setCustomFilterValue(
                          _detectedFilterFieldName ?? 'Is it furnished?',
                          tabTitle.toLowerCase(),
                        );
                      }
                    }
                  });

                  if (_isPropertyVertical()) {
                    _fetchFilteredItems();
                  }
                },
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFE8F1FD)
                        : context.color.secondaryColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF2979FF).withValues(alpha: 0.6)
                          : context.color.borderColor.withValues(alpha: 0.6),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      tabTitle,
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFF1565C0)
                            : context.color.textDefaultColor,
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _syncQuickFilterLabelsFromFilter() {
    if (filter == null) return;
    _selectedPropertyTypeLabel = 'Property Type';
    _selectedRoomsLabel = 'Bedrooms';
    _selectedBathroomsLabel = 'Bathrooms';
    _selectedSegmentValue = null;
    if (filter!.categorySlug != null) {
      final s = filter!.categorySlug!.toLowerCase();
      if (s.contains('off-plan') ||
          s.contains('off_plan') ||
          s.contains('offplan')) {
        _selectedRentSaleLabel = "Off-Plan";
      } else if (s.contains('sale') || s.contains('buy')) {
        _selectedRentSaleLabel = "Buy";
      } else if (s.contains('rent')) {
        _selectedRentSaleLabel = "Rent";
      }
    }
    if ((filter!.minPrice != null && filter!.minPrice!.isNotEmpty) ||
        (filter!.maxPrice != null && filter!.maxPrice!.isNotEmpty)) {
      final minP = filter!.minPrice ?? "";
      final maxP = filter!.maxPrice ?? "";
      if (minP.isNotEmpty && maxP.isNotEmpty) {
        _selectedPriceRangeLabel = "$minP - $maxP";
      } else if (minP.isNotEmpty) {
        _selectedPriceRangeLabel = "> $minP";
      } else if (maxP.isNotEmpty) {
        _selectedPriceRangeLabel = "< $maxP";
      }
    } else {
      _selectedPriceRangeLabel = "Price Range";
    }

    final configuration = _propertyFilterConfiguration;
    if (configuration != null) {
      FilterSubCategory? selectedCategory;
      for (final category in configuration.children) {
        if (category.id?.toString() == filter!.categoryId ||
            (category.slug != null && category.slug == filter!.categorySlug)) {
          selectedCategory = category;
          break;
        }
      }
      final selectedName = selectedCategory?.name?.trim() ?? '';
      if (selectedName.isNotEmpty &&
          !selectedName.toLowerCase().startsWith('all')) {
        _selectedPropertyTypeLabel = selectedName;
      } else if (configuration.slug == filter!.categorySlug &&
          !const {65, 139, 143}.contains(configuration.id)) {
        final configurationName = configuration.name?.trim() ?? '';
        if (configurationName.isNotEmpty &&
            !configurationName.toLowerCase().startsWith('all')) {
          _selectedPropertyTypeLabel = configurationName;
        }
      }
    }

    final bedroomsFilter =
        _propertyFilterByNames(const ['Bedrooms', 'Bedroom']);
    final bedroomValue =
        _singleCustomFilterValue(bedroomsFilter?.name ?? 'Bedrooms');
    if (bedroomValue != null) {
      _selectedRoomsLabel = '$bedroomValue Bedrooms';
    }

    final bathroomsFilter =
        _propertyFilterByNames(const ['Bathrooms', 'Bathroom']);
    final bathroomValue =
        _singleCustomFilterValue(bathroomsFilter?.name ?? 'Bathrooms');
    if (bathroomValue != null) {
      _selectedBathroomsLabel = '$bathroomValue Bathrooms';
    }

    final furnishingFilter = _propertyFilterByNames(
      const ['Is it furnished?', 'Furnishing', 'Furnished'],
    );
    final furnishingValue = _singleCustomFilterValue(
      furnishingFilter?.name ?? 'Is it furnished?',
    );
    if (furnishingValue != null) {
      _selectedSegmentValue = furnishingValue.toLowerCase().contains('un')
          ? 'Unfurnished'
          : 'Furnished';
    }
  }

  void _openFullFilterScreen() {
    final catIdInt = _activeCategoryId;
    const filterCategoryIds = [65, 68, 139, 143];

    CategoryModel? activeCategory;
    if (_currentChain.isNotEmpty) {
      activeCategory = _currentChain.first;
    } else if (widget.selectedCategoryChain != null &&
        widget.selectedCategoryChain!.isNotEmpty) {
      activeCategory = widget.selectedCategoryChain!.first;
    } else {
      activeCategory = CategoryModel(
        id: catIdInt,
        name: widget.categoryName,
        children: [],
        subcategoriesCount: 0,
      );
    }

    if (filterCategoryIds.contains(catIdInt) || _isPropertyVertical()) {
      Navigator.pushNamed(
        context,
        Routes.filterpage,
        arguments: {
          'category': activeCategory,
          'appliedFilter': filter,
          'isFromItemsList': true,
          'filterConfiguration': _propertyFilterConfiguration,
        },
      ).then((result) {
        if (result != null && result is Map) {
          final catIdStr = result['catID']?.toString();
          if (result['appliedFilter'] is ItemFilterModel) {
            filter = result['appliedFilter'] as ItemFilterModel;
            Constant.itemFilter = filter;
          }
          if (result['filterConfiguration'] is FilterCategory) {
            _propertyFilterConfiguration =
                result['filterConfiguration'] as FilterCategory;
          }
          if (catIdStr != null && catIdStr.isNotEmpty) {
            _currentCategoryIds = result['categoryIds'] != null
                ? List<String>.from(result['categoryIds'])
                : _currentCategoryIds;
            if (result['selectedCategoryChain'] != null) {
              _currentChain =
                  List<CategoryModel>.from(result['selectedCategoryChain']);
            }
            final newCatIdInt = int.tryParse(catIdStr) ?? 0;
            if (newCatIdInt != 0) {
              _fetchFilteredItems();
            }
            _syncQuickFilterLabelsFromFilter();
            setState(() {});
          }
        }
      });
    } else {
      Navigator.pushNamed(
        context,
        Routes.filterScreen,
        arguments: {
          "update": getFilterValue,
          "from": "itemsList",
          "categoryIds": _currentCategoryIds,
          "categoryList": _currentChain,
        },
      ).then((value) {
        if (value == true && filter != null) {
          ItemFilterModel updatedFilter =
              filter!.copyWith(categoryId: widget.categoryId);
          if (catIdInt != 0) {
            context.read<FetchItemFromCategoryCubit>().fetchItemFromCategory(
                  categoryId: catIdInt,
                  search: searchController.text,
                  filter: updatedFilter,
                );
          }
          setState(() {});
        }
      });
    }
  }

  void _showJobTypeQuickFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: context.color.secondaryColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Select Job Type",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    "All Types",
                    "Full Time",
                    "Part Time",
                    "Contract",
                    "Remote",
                    "Internship",
                    "Temporary",
                  ].map((type) {
                    final isSelected = _selectedJobTypeLabel == type ||
                        (type == "All Types" &&
                            (_selectedJobTypeLabel == "Job Type" ||
                                _selectedJobTypeLabel == "All Types"));
                    return ChoiceChip(
                      label: Text(type),
                      selected: isSelected,
                      selectedColor:
                          context.color.territoryColor.withValues(alpha: 0.15),
                      backgroundColor: context.color.secondaryColor,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? context.color.territoryColor
                            : context.color.textDefaultColor,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        Navigator.pop(context);
                        setState(() {
                          _selectedJobTypeLabel =
                              type == "All Types" ? "Job Type" : type;
                          if (type != "All Types") {
                            _selectedSegmentValue = type;
                          } else {
                            _selectedSegmentValue = null;
                          }
                        });
                        final catIdInt = int.tryParse(widget.categoryId) ?? 0;
                        if (catIdInt != 0) {
                          context
                              .read<FetchItemFromCategoryCubit>()
                              .fetchItemFromCategory(
                                categoryId: catIdInt,
                                search: searchController.text,
                                filter: filter,
                              );
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showJobGenderQuickFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Select Gender Preference",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  "All",
                  "Male",
                  "Female",
                  "Any",
                ].map((g) {
                  final isSelected = _selectedJobGenderLabel == g ||
                      (g == "All" &&
                          (_selectedJobGenderLabel == "Gender" ||
                              _selectedJobGenderLabel == "All"));
                  return ChoiceChip(
                    label: Text(g),
                    selected: isSelected,
                    selectedColor:
                        context.color.territoryColor.withValues(alpha: 0.15),
                    backgroundColor: context.color.secondaryColor,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? context.color.territoryColor
                          : context.color.textDefaultColor,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      Navigator.pop(context);
                      setState(() {
                        _selectedJobGenderLabel = g == "All" ? "Gender" : g;
                      });
                      final catIdInt = int.tryParse(widget.categoryId) ?? 0;
                      if (catIdInt != 0) {
                        context
                            .read<FetchItemFromCategoryCubit>()
                            .fetchItemFromCategory(
                              categoryId: catIdInt,
                              search: searchController.text,
                              filter: filter,
                            );
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showPropertyPurposeQuickFilter() {
    final purposes = [
      {
        "label": "Property for Rent",
        "short": "Rent",
        "id": 65,
        "slug": "residential"
      },
      {
        "label": "Property for Sale",
        "short": "Buy",
        "id": 139,
        "slug": "property-for-sale-new-projects"
      },
      {
        "label": "Off-Plan / Projects",
        "short": "Off-Plan",
        "id": 143,
        "slug": "property-for-sale-off-plan"
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: context.color.secondaryColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Select Purpose",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                  ),
                ),
                const SizedBox(height: 12),
                ...purposes.map((p) {
                  final shortName = p['short'] as String;
                  final fullName = p['label'] as String;
                  final catId = p['id'] as int;
                  final slug = p['slug'] as String;

                  final isSelected = _selectedRentSaleLabel == shortName ||
                      _selectedRentSaleLabel == fullName ||
                      (shortName == "Rent" && _selectedRentSaleLabel == "Rent");

                  return ListTile(
                    title: Text(
                      fullName,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? context.color.territoryColor
                            : context.color.textDefaultColor,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle,
                            color: context.color.territoryColor)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedRentSaleLabel = shortName;
                        _currentCategoryIds = [catId.toString()];
                        _selectedPropertyTypeLabel = "Property Type";
                        _selectedRoomsLabel = "Bedrooms";
                        _selectedBathroomsLabel = "Bathrooms";
                        _selectedSegmentValue = null;
                        _currentChain = [
                          CategoryModel(
                            id: catId,
                            name: fullName,
                            slug: slug,
                            children: [],
                            subcategoriesCount: 0,
                          )
                        ];
                        if (filter != null) {
                          filter = filter!.copyWith(
                            categoryId: catId.toString(),
                            categorySlug: slug,
                            customFields: const {},
                          );
                        } else {
                          filter = ItemFilterModel(
                            categoryId: catId.toString(),
                            categorySlug: slug,
                          );
                        }
                        Constant.itemFilter = filter;
                      });
                      _loadPropertyFilterConfiguration(slug);
                      _fetchFilteredItems();
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPropertyTypeQuickFilter() {
    final configuration = _propertyFilterConfiguration;
    if (configuration == null) {
      _openFullFilterScreen();
      return;
    }
    final configuredCategories = configuration.children.where((category) {
      final name = category.name?.trim() ?? '';
      return name.isNotEmpty && !name.toLowerCase().startsWith('all');
    }).toList();
    final chainCategories = _currentChain.isEmpty
        ? const <FilterSubCategory>[]
        : (_currentChain.first.children ?? const <CategoryModel>[])
            .where((category) {
            final name = category.name?.trim() ?? '';
            return name.isNotEmpty && !name.toLowerCase().startsWith('all');
          }).map((category) {
            return FilterSubCategory(
              id: category.id,
              name: category.name,
              slug: category.slug,
            );
          }).toList();
    final usesConfiguredCategories = configuredCategories.isNotEmpty;
    final categories =
        usesConfiguredCategories ? configuredCategories : chainCategories;
    final parentId = usesConfiguredCategories
        ? configuration.id
        : (_currentChain.isNotEmpty ? _currentChain.first.id : null);
    final parentSlug = usesConfiguredCategories
        ? configuration.slug
        : (_currentChain.isNotEmpty ? _currentChain.first.slug : null);
    final propertyTypes = [
      "All Types",
      ...categories.map((category) => category.name!),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Property Type",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: propertyTypes.map((type) {
                    final isSelected = _selectedPropertyTypeLabel == type ||
                        (type == "All Types" &&
                            (_selectedPropertyTypeLabel == "Property Type" ||
                                _selectedPropertyTypeLabel == "All Types"));
                    return ChoiceChip(
                      label: Text(type),
                      selected: isSelected,
                      selectedColor:
                          context.color.territoryColor.withValues(alpha: 0.15),
                      backgroundColor: context.color.secondaryColor,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? context.color.territoryColor
                            : context.color.textDefaultColor,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        Navigator.pop(context);
                        _setCustomFilterValue('Property Type', null);
                        FilterSubCategory? selectedCategory;
                        if (type != "All Types") {
                          for (final category in categories) {
                            if (category.name == type) {
                              selectedCategory = category;
                              break;
                            }
                          }
                        }
                        setState(() {
                          _selectedPropertyTypeLabel =
                              type == "All Types" ? "Property Type" : type;
                          final targetId = selectedCategory?.id ??
                              parentId ??
                              _activeCategoryId;
                          final targetSlug = selectedCategory?.slug ??
                              parentSlug ??
                              filter?.categorySlug;
                          filter = (filter ??
                                  ItemFilterModel(
                                      categoryId: targetId.toString()))
                              .copyWith(
                            categoryId: targetId.toString(),
                            categorySlug: targetSlug,
                          );
                          _currentCategoryIds = [targetId.toString()];
                          Constant.itemFilter = filter;
                        });
                        _fetchFilteredItems();
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRoomsQuickFilter() {
    final bedroomsFilter =
        _propertyFilterByNames(const ['Bedrooms', 'Bedroom']);
    if (bedroomsFilter == null || bedroomsFilter.values.isEmpty) {
      _openFullFilterScreen();
      return;
    }
    final fieldName = bedroomsFilter.name ?? 'Bedrooms';
    final roomOptions = [
      "All Bedrooms",
      ...bedroomsFilter.values.map(
        (value) => value.toLowerCase() == 'studio'
            ? value
            : '$value ${value == '1' ? 'Bedroom' : 'Bedrooms'}',
      ),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Bedrooms",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: roomOptions.map((room) {
                  final isSelected = _selectedRoomsLabel == room ||
                      (_selectedRoomsLabel == "Bedrooms" &&
                          room == "All Bedrooms") ||
                      (_selectedRoomsLabel.contains(room.split(" ").first) &&
                          room != "All Bedrooms");

                  return ChoiceChip(
                    label: Text(room),
                    selected: isSelected,
                    selectedColor:
                        context.color.territoryColor.withValues(alpha: 0.15),
                    backgroundColor: context.color.secondaryColor,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? context.color.territoryColor
                          : context.color.textDefaultColor,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      Navigator.pop(context);
                      final rawVal = room == "All Bedrooms"
                          ? ""
                          : (room == "Studio"
                              ? "Studio"
                              : room.split(" ").first);

                      setState(() {
                        _selectedRoomsLabel =
                            room == "All Bedrooms" ? "Bedrooms" : room;

                        _setCustomFilterValue(
                          fieldName,
                          rawVal.isEmpty ? null : rawVal,
                        );
                      });
                      _fetchFilteredItems();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showBathroomsQuickFilter() {
    final bathroomsFilter =
        _propertyFilterByNames(const ['Bathrooms', 'Bathroom']);
    if (bathroomsFilter == null || bathroomsFilter.values.isEmpty) {
      _openFullFilterScreen();
      return;
    }
    final fieldName = bathroomsFilter.name ?? 'Bathrooms';
    final bathOptions = [
      "All Bathrooms",
      ...bathroomsFilter.values.map(
        (value) => '$value ${value == '1' ? 'Bathroom' : 'Bathrooms'}',
      ),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Bathrooms",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: bathOptions.map((bath) {
                  final isSelected = _selectedBathroomsLabel == bath ||
                      (_selectedBathroomsLabel == "Bathrooms" &&
                          bath == "All Bathrooms") ||
                      (_selectedBathroomsLabel
                              .contains(bath.split(" ").first) &&
                          bath != "All Bathrooms");

                  return ChoiceChip(
                    label: Text(bath),
                    selected: isSelected,
                    selectedColor:
                        context.color.territoryColor.withValues(alpha: 0.15),
                    backgroundColor: context.color.secondaryColor,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? context.color.territoryColor
                          : context.color.textDefaultColor,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      Navigator.pop(context);
                      final rawVal =
                          bath == "All Bathrooms" ? "" : bath.split(" ").first;

                      setState(() {
                        _selectedBathroomsLabel =
                            bath == "All Bathrooms" ? "Bathrooms" : bath;

                        _setCustomFilterValue(
                          fieldName,
                          rawVal.isEmpty ? null : rawVal,
                        );
                      });
                      _fetchFilteredItems();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showPriceRangeQuickFilter() {
    final currentMin = double.tryParse(filter?.minPrice ?? '') ?? 0.0;
    final currentMax = double.tryParse(filter?.maxPrice ?? '') ?? 10000000.0;

    final minCtrl = TextEditingController(
      text: filter?.minPrice != null && filter!.minPrice!.isNotEmpty
          ? filter!.minPrice!
          : "",
    );
    final maxCtrl = TextEditingController(
      text: filter?.maxPrice != null && filter!.maxPrice!.isNotEmpty
          ? filter!.maxPrice!
          : "",
    );

    double sliderMin = currentMin.clamp(0.0, 10000000.0);
    double sliderMax = currentMax.clamp(0.0, 10000000.0);
    if (sliderMin > sliderMax) sliderMin = 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: context.color.secondaryColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Price Range (${Constant.currencySymbol})",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: context.color.textDefaultColor,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              minCtrl.clear();
                              maxCtrl.clear();
                              sliderMin = 0.0;
                              sliderMax = 10000000.0;
                            });
                          },
                          child: Text(
                            "Reset",
                            style: TextStyle(
                              color: context.color.territoryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Minimum",
                              prefixText: "${Constant.currencySymbol} ",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                            onChanged: (val) {
                              final num = double.tryParse(val) ?? 0.0;
                              setModalState(() {
                                sliderMin = num.clamp(0.0, sliderMax);
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text("to",
                            style:
                                TextStyle(color: context.color.textLightColor)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: maxCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Maximum",
                              prefixText: "${Constant.currencySymbol} ",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                            onChanged: (val) {
                              final num = double.tryParse(val) ?? 10000000.0;
                              setModalState(() {
                                sliderMax = num.clamp(sliderMin, 10000000.0);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    RangeSlider(
                      values: RangeValues(sliderMin, sliderMax),
                      min: 0.0,
                      max: 10000000.0,
                      divisions: 100,
                      activeColor: context.color.territoryColor,
                      inactiveColor: context.color.borderColor,
                      labels: RangeLabels(
                        "${sliderMin.toInt()} ${Constant.currencySymbol}",
                        "${sliderMax.toInt()} ${Constant.currencySymbol}",
                      ),
                      onChanged: (RangeValues values) {
                        setModalState(() {
                          sliderMin = values.start;
                          sliderMax = values.end;
                          minCtrl.text =
                              sliderMin > 0 ? sliderMin.toInt().toString() : "";
                          maxCtrl.text = sliderMax < 10000000
                              ? sliderMax.toInt().toString()
                              : "";
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.color.territoryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          final minP = minCtrl.text.trim();
                          final maxP = maxCtrl.text.trim();
                          setState(() {
                            if (minP.isEmpty && maxP.isEmpty) {
                              _selectedPriceRangeLabel = "Price Range";
                            } else if (minP.isNotEmpty && maxP.isNotEmpty) {
                              _selectedPriceRangeLabel = "$minP - $maxP";
                            } else if (minP.isNotEmpty) {
                              _selectedPriceRangeLabel = "> $minP";
                            } else {
                              _selectedPriceRangeLabel = "< $maxP";
                            }

                            if (filter != null) {
                              filter = filter!.copyWith(
                                minPrice: minP.isNotEmpty ? minP : null,
                                maxPrice: maxP.isNotEmpty ? maxP : null,
                                clearMinPrice: minP.isEmpty,
                                clearMaxPrice: maxP.isEmpty,
                              );
                            } else {
                              filter = ItemFilterModel(
                                minPrice: minP.isNotEmpty ? minP : null,
                                maxPrice: maxP.isNotEmpty ? maxP : null,
                                categoryId: widget.categoryId,
                              );
                            }
                          });

                          Constant.itemFilter = filter;
                          _fetchFilteredItems();
                        },
                        child: const Text(
                          "Apply Price Filter",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChips() {
    final activeFiltersCount = _activeFiltersCount;

    final isProp = _isPropertyVertical();
    final isJob = _isJobsVertical();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Filter count chip -> opens full filter screen
          ActionChip(
            avatar: Icon(
              Icons.tune_rounded,
              size: 16,
              color: activeFiltersCount > 0
                  ? Colors.white
                  : context.color.textDefaultColor,
            ),
            label: Text(
              activeFiltersCount > 0
                  ? "Filters ($activeFiltersCount)"
                  : "Filters",
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: activeFiltersCount > 0
                    ? Colors.white
                    : context.color.textDefaultColor,
              ),
            ),
            backgroundColor: activeFiltersCount > 0
                ? context.color.territoryColor
                : context.color.secondaryColor,
            side: BorderSide(
              color: activeFiltersCount > 0
                  ? context.color.territoryColor
                  : context.color.borderColor,
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            onPressed: _openFullFilterScreen,
          ),
          const SizedBox(width: 8),

          if (isProp) ...[
            // Purpose (Rent, Buy, Off-plan, Rooms)
            _buildQuickFilterPill(
              label: _selectedRentSaleLabel,
              isActive: _selectedRentSaleLabel != "Purpose",
              onTap: _showPropertyPurposeQuickFilter,
            ),
            const SizedBox(width: 8),

            // Property Type
            _buildQuickFilterPill(
              label: _selectedPropertyTypeLabel,
              isActive: _selectedPropertyTypeLabel != "Property Type" &&
                  _selectedPropertyTypeLabel != "All",
              onTap: _showPropertyTypeQuickFilter,
            ),
            const SizedBox(width: 8),

            // Price Range
            _buildQuickFilterPill(
              label: _selectedPriceRangeLabel,
              isActive: _selectedPriceRangeLabel != "Price Range",
              onTap: _showPriceRangeQuickFilter,
            ),
            const SizedBox(width: 8),

            // Bedrooms / Rooms
            _buildQuickFilterPill(
              label: _selectedRoomsLabel,
              isActive: _selectedRoomsLabel != "Bedrooms" &&
                  _selectedRoomsLabel != "Rooms",
              onTap: _showRoomsQuickFilter,
            ),
            const SizedBox(width: 8),

            // Bathrooms
            _buildQuickFilterPill(
              label: _selectedBathroomsLabel,
              isActive: _selectedBathroomsLabel != "Bathrooms",
              onTap: _showBathroomsQuickFilter,
            ),
          ] else if (isJob) ...[
            for (final jobFilter in _jobQuickFilters) ...[
              _buildQuickFilterPill(
                label: _jobFilterLabel(jobFilter),
                isActive: _isMeaningfulFilterValue(
                    _customFilterValue(jobFilter.name!)),
                onTap: () => _showJobApiQuickFilter(jobFilter),
              ),
              const SizedBox(width: 8),
            ],
          ] else ...[
            // General dynamic category chain chips
            for (int i = 0; i < _currentChain.length; i++) ...[
              _buildDynamicChip(i),
              const SizedBox(width: 8),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildQuickFilterPill({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? context.color.territoryColor.withValues(alpha: 0.12)
              : context.color.secondaryColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? context.color.territoryColor
                : context.color.borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive
                    ? context.color.territoryColor
                    : context.color.textDefaultColor,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isActive
                  ? context.color.territoryColor
                  : context.color.textLightColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicChip(int chainIndex) {
    CategoryModel currentModel = _currentChain[chainIndex];
    return _buildChip(
      label: currentModel.name ?? "",
      isActive: !_isAllFieldsSelected, // Inactive if All Fields is selected
      showDropdown: true,
      onTap: () {
        if (_isAllFieldsSelected) {
          _restoreSelection(chainIndex);
        } else {
          _showDynamicFilterBottomSheet(chainIndex);
        }
      },
    );
  }

  bool _isAllFieldsSelected = false;

  void _restoreSelection(int chainIndex) {
    setState(() {
      _isAllFieldsSelected = false;

      // Truncate chain after chainIndex
      if (_currentChain.length > chainIndex + 1) {
        _currentChain.removeRange(chainIndex + 1, _currentChain.length);
      }

      List<String> newIds = [];
      if (widget.categoryIds != null &&
          widget.categoryIds!.isNotEmpty &&
          widget.categoryIds!.length > 1) {
        newIds.add(widget.categoryIds![0]);
      }
      for (var cat in _currentChain) {
        if (cat.id != null && !newIds.contains(cat.id.toString())) {
          newIds.add(cat.id.toString());
        }
      }
      _currentCategoryIds = newIds;

      // Fetch
      CategoryModel? targetCat =
          _currentChain.isNotEmpty ? _currentChain.last : null;
      int targetId = targetCat?.id ?? int.tryParse(widget.categoryId) ?? 0;

      context.read<FetchItemFromCategoryCubit>().fetchItemFromCategory(
          categoryId: targetId, search: searchController.text, filter: filter);
    });
  }

  CategoryModel? _findCategoryInTree(
      List<CategoryModel> categories, int targetId) {
    for (var cat in categories) {
      if (cat.id == targetId) return cat;
      if (cat.children != null && cat.children!.isNotEmpty) {
        final found = _findCategoryInTree(cat.children!, targetId);
        if (found != null) return found;
      }
    }
    return null;
  }

  void _showDynamicFilterBottomSheet(int chainIndex) {
    int parentId = 0;
    if (chainIndex == 0) {
      if (widget.categoryIds != null && widget.categoryIds!.length > 1) {
        parentId = int.tryParse(widget.categoryIds![0]) ?? 0;
      } else if (_currentChain.isNotEmpty) {
        parentId = _currentChain[0].id ?? int.tryParse(widget.categoryId) ?? 0;
      } else {
        parentId = int.tryParse(widget.categoryId) ?? 0;
      }
    } else {
      if (chainIndex - 1 < _currentChain.length) {
        parentId = _currentChain[chainIndex - 1].id ?? 0;
      }
    }

    if (parentId != 0) {
      _chipFilterCubit.fetchSubCategories(categoryId: parentId);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        CategoryModel? selectedCategory;
        if (_currentChain.length > chainIndex) {
          selectedCategory = _currentChain[chainIndex];
        }

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Material(
                  color: context.color.secondaryColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      children: [
                        // Drag Handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: context.color.borderColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Select Category",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: context.color.textDefaultColor)),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Icon(Icons.close,
                                  color: context.color.textDefaultColor),
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: BlocProvider.value(
                            value: _chipFilterCubit,
                            child: BlocBuilder<FetchSubCategoriesCubit,
                                FetchSubCategoriesState>(
                              builder: (context, state) {
                                if (state is FetchSubCategoriesInProgress) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }
                                if (state is FetchSubCategoriesSuccess) {
                                  List<CategoryModel> displayCategories = [];
                                  bool isMainCategory = false;

                                  if (parentId != 0) {
                                    final parentModel = _findCategoryInTree(
                                        state.categories, parentId);
                                    if (parentModel != null &&
                                        parentModel.children != null &&
                                        parentModel.children!.isNotEmpty) {
                                      displayCategories = parentModel.children!;
                                      isMainCategory = false;
                                    } else {
                                      displayCategories = state.categories;
                                      isMainCategory = true;
                                    }
                                  } else {
                                    displayCategories = state.categories;
                                    isMainCategory = true;
                                  }

                                  if (displayCategories.isEmpty) {
                                    return Center(
                                      child: Text(
                                        "No subcategories available",
                                        style: TextStyle(
                                            color:
                                                context.color.textLightColor),
                                      ),
                                    );
                                  }

                                  if (isMainCategory) {
                                    // Grid View for Main Categories
                                    return GridView.builder(
                                      controller: scrollController,
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: displayCategories.length,
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        mainAxisSpacing: 12,
                                        crossAxisSpacing: 12,
                                        childAspectRatio: 0.92,
                                      ),
                                      itemBuilder: (context, index) {
                                        CategoryModel cat =
                                            displayCategories[index];
                                        bool isSelected =
                                            selectedCategory?.id == cat.id;

                                        return Material(
                                          color: isSelected
                                              ? context.color.territoryColor
                                                  .withValues(alpha: 0.1)
                                              : context.color.backgroundColor,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          clipBehavior: Clip.antiAlias,
                                          child: InkWell(
                                            onTap: () {
                                              setModalState(() {
                                                selectedCategory = cat;
                                              });
                                            },
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? context
                                                          .color.territoryColor
                                                      : context
                                                          .color.borderColor,
                                                  width: isSelected ? 1.5 : 1,
                                                ),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 8),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Container(
                                                    width: 44,
                                                    height: 44,
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: isSelected
                                                          ? context.color
                                                              .territoryColor
                                                              .withValues(
                                                                  alpha: 0.15)
                                                          : context.color
                                                              .territoryColor
                                                              .withValues(
                                                                  alpha: 0.06),
                                                    ),
                                                    child: (cat.url != null &&
                                                            cat.url!
                                                                .trim()
                                                                .isNotEmpty)
                                                        ? UiUtils.imageType(
                                                            cat.url!,
                                                            fit: BoxFit.contain,
                                                            color: isSelected
                                                                ? context.color
                                                                    .territoryColor
                                                                : null,
                                                          )
                                                        : Icon(
                                                            Icons
                                                                .category_outlined,
                                                            size: 22,
                                                            color: context.color
                                                                .territoryColor,
                                                          ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    cat.name ?? "",
                                                    textAlign: TextAlign.center,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isSelected
                                                          ? context.color
                                                              .territoryColor
                                                          : context.color
                                                              .textDefaultColor,
                                                      fontWeight: isSelected
                                                          ? FontWeight.bold
                                                          : FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  }

                                  // List View for Subcategories
                                  return ListView.separated(
                                    controller: scrollController,
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: displayCategories.length,
                                    separatorBuilder: (context, index) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      CategoryModel cat =
                                          displayCategories[index];
                                      bool isSelected =
                                          selectedCategory?.id == cat.id;

                                      return Material(
                                        color: isSelected
                                            ? context.color.territoryColor
                                                .withValues(alpha: 0.08)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        clipBehavior: Clip.antiAlias,
                                        child: ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 4),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          leading: Container(
                                            width: 40,
                                            height: 40,
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isSelected
                                                  ? context.color.territoryColor
                                                      .withValues(alpha: 0.15)
                                                  : context.color.territoryColor
                                                      .withValues(alpha: 0.06),
                                            ),
                                            child: (cat.url != null &&
                                                    cat.url!.trim().isNotEmpty)
                                                ? UiUtils.imageType(
                                                    cat.url!,
                                                    fit: BoxFit.contain,
                                                    color: isSelected
                                                        ? context.color
                                                            .territoryColor
                                                        : null,
                                                  )
                                                : Icon(
                                                    Icons.category_outlined,
                                                    size: 20,
                                                    color: context
                                                        .color.territoryColor,
                                                  ),
                                          ),
                                          title: Text(
                                            cat.name ?? "",
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isSelected
                                                  ? context.color.territoryColor
                                                  : context
                                                      .color.textDefaultColor,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                          trailing: isSelected
                                              ? Icon(Icons.check_circle_rounded,
                                                  color: context
                                                      .color.territoryColor,
                                                  size: 22)
                                              : Icon(
                                                  Icons.radio_button_unchecked,
                                                  color:
                                                      context.color.borderColor,
                                                  size: 22),
                                          onTap: () {
                                            setModalState(() {
                                              selectedCategory = cat;
                                            });
                                          },
                                        ),
                                      );
                                    },
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SafeArea(
                          top: false,
                          child: UiUtils.buildButton(context, onPressed: () {
                            if (selectedCategory != null) {
                              Navigator.pop(context);
                              _updateSelection(chainIndex, selectedCategory!);
                            }
                          },
                              buttonTitle: "Show Results",
                              textColor: context.color.secondaryColor,
                              buttonColor: context.color.territoryColor,
                              radius: 10),
                        )
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _updateSelection(int chainIndex, CategoryModel newSelection) {
    setState(() {
      _isAllFieldsSelected = false;

      // Update the chain at this index
      if (_currentChain.length > chainIndex) {
        _currentChain[chainIndex] = newSelection;
      } else {
        _currentChain.add(newSelection);
      }

      // Truncate any existing children
      if (_currentChain.length > chainIndex + 1) {
        _currentChain.removeRange(chainIndex + 1, _currentChain.length);
      }

      // Re-calculate categoryIds chain
      List<String> newIds = [];
      if (widget.categoryIds != null &&
          widget.categoryIds!.isNotEmpty &&
          widget.categoryIds!.length > 1) {
        newIds.add(widget.categoryIds![0]);
      }
      for (var cat in _currentChain) {
        if (cat.id != null && !newIds.contains(cat.id.toString())) {
          newIds.add(cat.id.toString());
        }
      }
      _currentCategoryIds = newIds;

      int targetId = newSelection.id ?? int.tryParse(widget.categoryId) ?? 0;

      context.read<FetchItemFromCategoryCubit>().fetchItemFromCategory(
            categoryId: targetId,
            search: searchController.text,
            filter: filter,
          );
    });
  }

  Widget _buildChip(
      {required String label,
      required bool isActive,
      bool showDropdown = true,
      VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? context.color.territoryColor.withValues(alpha: 0.12)
              : context.color.secondaryColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isActive
                  ? context.color.territoryColor
                  : context.color.borderColor.withValues(alpha: 0.7),
              width: isActive ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    color: isActive
                        ? context.color.territoryColor
                        : context.color.textDefaultColor,
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600)),
            if (showDropdown) ...[
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: isActive
                      ? context.color.territoryColor
                      : context.color.textDefaultColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVerifiedToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Show Verified Properties First",
            style: TextStyle(
              color: context.color.textDefaultColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          CupertinoSwitch(
            value: _showVerifiedOnly,
            activeTrackColor: context.color.territoryColor,
            onChanged: (val) {
              setState(() {
                _showVerifiedOnly = val;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingBottomBar() {
    final catIdInt = int.tryParse(widget.categoryId);
    final city = HiveUtils.getCityName() ?? "Dubai";
    final country = HiveUtils.getCountryName() ?? "United Arab Emirates";
    final locationStr = "$city, $country";

    String suggestedTitle;
    if (searchController.text.trim().isNotEmpty) {
      suggestedTitle = "${searchController.text.trim()} in $city";
    } else if (widget.categoryName.isNotEmpty) {
      suggestedTitle = "${widget.categoryName} in $city";
    } else {
      suggestedTitle = "Search in $city";
    }

    int? parentCatId;
    String? catSlug;
    if (widget.selectedCategoryChain != null &&
        widget.selectedCategoryChain!.isNotEmpty) {
      parentCatId = widget.selectedCategoryChain!.first.id;
      catSlug = widget.selectedCategoryChain!.last.slug;
    }

    return BlocBuilder<FetchSavedSearchesCubit, FetchSavedSearchesState>(
      builder: (context, savedSearchState) {
        final matchedSearch = context
            .read<FetchSavedSearchesCubit>()
            .findSavedSearch(
              query: searchController.text.trim(),
              categoryId: catIdInt,
              apiSearchUrl: "${Api.getItemApi}?category_id=${catIdInt ?? ''}",
            );
        final bool isAlreadySaved = matchedSearch != null;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: context.color.borderColor.withValues(alpha: 0.7),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. Sort Button
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: showSortByBottomSheet,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swap_vert_rounded,
                        size: 18,
                        color: context.color.textDefaultColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        "Sort",
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Container(
                height: 18,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: context.color.borderColor.withValues(alpha: 0.6),
              ),

              // 2. Save Button
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  SaveSearchBottomSheet.show(
                    context,
                    isAlreadySaved: isAlreadySaved,
                    savedSearchId: matchedSearch?.id,
                    initialTitle:
                        isAlreadySaved ? matchedSearch.title : suggestedTitle,
                    categoryId: catIdInt,
                    parentCategoryId: parentCatId,
                    categorySlug: catSlug,
                    apiSearchUrl:
                        "${Api.getItemApi}?category_id=${catIdInt ?? ''}",
                    location: locationStr,
                    initialNotification: matchedSearch?.notification ?? true,
                    initialSubscribeEmail:
                        matchedSearch?.subscribeEmail ?? false,
                  );
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAlreadySaved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        size: 18,
                        color: isAlreadySaved
                            ? context.color.territoryColor
                            : context.color.textDefaultColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isAlreadySaved ? "Saved" : "Save",
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isAlreadySaved
                              ? context.color.territoryColor
                              : context.color.textDefaultColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String? _getPricePeriod(ItemModel item) {
    if (item.customFields != null) {
      for (var cf in item.customFields!) {
        final name = (cf.name ?? "").toLowerCase();
        final val = (cf.value?.toString() ?? "").toLowerCase();
        if (name.contains("period") || name.contains("rent type")) {
          return cf.value?.toString();
        }
        if (val == "yearly" ||
            val == "monthly" ||
            val == "daily" ||
            val == "weekly") {
          return cf.value?.toString();
        }
      }
    }
    final catName = widget.categoryName.toLowerCase();
    if (catName.contains("rent") || catName.contains("property")) {
      return "Yearly";
    }
    return null;
  }

  Widget _buildPropertyFeatures(ItemModel item) {
    List<Widget> features = [];

    if (item.customFields != null && item.customFields!.isNotEmpty) {
      for (var field in item.customFields!) {
        final name = (field.name ?? "").toLowerCase();
        if (name.contains("upload your cv") ||
            name.contains("cv") ||
            name.contains("resume") ||
            field.type == "fileinput") {
          continue;
        }
        dynamic rawVal = field.value;
        String val = "";
        if (rawVal is List && rawVal.isNotEmpty) {
          val = rawVal.join(", ");
        } else if (rawVal != null) {
          val = rawVal.toString();
        }
        val = val.trim();
        if (val.isEmpty ||
            (val.startsWith("http") &&
                (val.endsWith(".jpg") ||
                    val.endsWith(".png") ||
                    val.endsWith(".pdf") ||
                    val.endsWith(".docx") ||
                    val.endsWith(".doc")))) {
          continue;
        }

        IconData iconData = Icons.label_outline_rounded;

        if (name.contains("bed") || name.contains("room")) {
          iconData = Icons.bed_outlined;
          if (!val.toLowerCase().contains("bed")) val = "$val bed";
        } else if (name.contains("bath")) {
          iconData = Icons.bathtub_outlined;
          if (!val.toLowerCase().contains("bath")) val = "$val bath";
        } else if (name.contains("sqft") ||
            name.contains("size") ||
            name.contains("area")) {
          iconData = Icons.crop_square_rounded;
          if (!val.toLowerCase().contains("sqft") &&
              !val.toLowerCase().contains("sq")) {
            val = "$val sqft";
          }
        } else if (name.contains("kilometer") ||
            name.contains("km") ||
            name.contains("mileage")) {
          iconData = Icons.speed_rounded;
          if (!val.toLowerCase().contains("km")) val = "$val km";
        } else if (name.contains("year") || name.contains("model")) {
          iconData = Icons.calendar_today_outlined;
        } else if (name.contains("transmission") || name.contains("gear")) {
          iconData = Icons.settings_suggest_outlined;
        } else if (name.contains("fuel")) {
          iconData = Icons.local_gas_station_outlined;
        } else if (name.contains("storage") ||
            name.contains("ram") ||
            name.contains("memory")) {
          iconData = Icons.memory_outlined;
        } else if (name.contains("condition")) {
          iconData = Icons.star_border_rounded;
        } else if (name.contains("furnished")) {
          iconData = Icons.chair_outlined;
        }

        if (features.isNotEmpty) {
          features.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                "•",
                style: TextStyle(
                  color: context.color.textLightColor.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ),
          );
        }

        features.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconData, size: 15, color: context.color.textDefaultColor),
              const SizedBox(width: 4),
              Text(
                val,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.color.textDefaultColor,
                ),
              ),
            ],
          ),
        );

        if (features.length >= 7) break;
      }
    }

    if (features.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: features),
      ),
    );
  }

  Widget _buildPropertyCard(BuildContext context, ItemModel item) {
    final hasGallery =
        item.galleryImages != null && item.galleryImages!.isNotEmpty;
    final totalPhotos = hasGallery ? item.galleryImages!.length + 1 : 1;
    final pricePeriod = _getPricePeriod(item);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigateToDetails(context, item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. IMAGE STACK
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(15)),
                  child: SizedBox(
                    height: 210,
                    width: double.infinity,
                    child: UiUtils.getImage(
                      item.image ?? "",
                      fit: BoxFit.cover,
                      height: 210,
                      width: double.infinity,
                    ),
                  ),
                ),

                // Top-Left Verified Badge
                if (item.isFeature == true ||
                    item.status == "approved" ||
                    item.status == "1" ||
                    item.user?.isVerified == 1)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: Color(0xFF2563EB),
                          ),
                          SizedBox(width: 4),
                          Text(
                            "VERIFIED USER",
                            style: TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w800,
                              fontSize: 10.5,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Top-Right Favorite Button
                Positioned(
                  top: 10,
                  right: 10,
                  child: _favButton(context, item),
                ),

                // Bottom-Left Photos Count Badge
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.photo_camera_outlined,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "1/$totalPhotos",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom-Center Indicator dots
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      min(totalPhotos, 5),
                      (dotIdx) => Container(
                        width: dotIdx == 0 ? 8 : 6,
                        height: dotIdx == 0 ? 8 : 6,
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotIdx == 0
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // 2. CONTENT DETAILS
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price Line
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        "${Constant.currencySymbol} ${item.price != null ? item.price!.toString().priceFormate(disabled: Constant.isNumberWithSuffix == false) : '0'}",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                      if (pricePeriod != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          pricePeriod,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.color.textLightColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Features row (beds, baths, sqft)
                  _buildPropertyFeatures(item),

                  // Title
                  Text(
                    item.name?.firstUpperCase() ?? "",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Location
                  if (item.address != null &&
                      item.address!.trim().isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: context.color.textLightColor,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.address?.trim() ?? "",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: context.color.textLightColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ] else
                    const SizedBox(height: 8),

                  // Action Buttons
                  Builder(
                    builder: (context) {
                      final allCategoryIds = item.allCategoryIds ?? '';
                      final catIdList = allCategoryIds
                          .split(',')
                          .map((e) => e.trim())
                          .toList();
                      final isJobItem = catIdList.contains('4') ||
                          catIdList.contains('356') ||
                          catIdList.contains('357') ||
                          item.categoryId == 4 ||
                          item.categoryId == 356 ||
                          item.categoryId == 357 ||
                          (item.category?.slug ?? '')
                              .toLowerCase()
                              .contains('job') ||
                          (item.category?.name ?? '')
                              .toLowerCase()
                              .contains('job') ||
                          widget.categoryName.toLowerCase().contains('job');

                      final isHireTalent = catIdList.contains('357') ||
                          item.categoryId == 357 ||
                          (item.category?.slug ?? '')
                              .toLowerCase()
                              .contains('recruit') ||
                          (item.category?.name ?? '')
                              .toLowerCase()
                              .contains('recruit') ||
                          (item.category?.slug ?? '')
                              .toLowerCase()
                              .contains('hire') ||
                          (item.category?.name ?? '')
                              .toLowerCase()
                              .contains('hire');

                      if (isJobItem) {
                        if (isHireTalent) {
                          return Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () =>
                                      _navigateToDetails(context, item),
                                  child: Container(
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E88E5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.description_outlined,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          "See CV & Details",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _launchCall(
                                      item.contact ?? item.user?.mobile),
                                  child: Container(
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFFEE2E2),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.phone_outlined,
                                          size: 16,
                                          color: Color(0xFFDC2626),
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          "Call",
                                          style: TextStyle(
                                            color: Color(0xFFDC2626),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        } else {
                          return Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () =>
                                      _navigateToDetails(context, item),
                                  child: Container(
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD31027),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.assignment_turned_in_outlined,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          "Apply Now",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _launchCall(
                                      item.contact ?? item.user?.mobile),
                                  child: Container(
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFFEE2E2),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.phone_outlined,
                                          size: 16,
                                          color: Color(0xFFDC2626),
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          "Call",
                                          style: TextStyle(
                                            color: Color(0xFFDC2626),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                      }

                      return Row(
                        children: [
                          // 1. Chat Button
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _openChat(context, item),
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFDBEAFE),
                                    width: 1,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.chat_outlined,
                                      size: 16,
                                      color: Color(0xFF2563EB),
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      "Chat",
                                      style: TextStyle(
                                        color: Color(0xFF2563EB),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // 2. Call Button
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _launchCall(
                                  item.contact ?? item.user?.mobile),
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFFEE2E2),
                                    width: 1,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.phone_outlined,
                                      size: 16,
                                      color: Color(0xFFDC2626),
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      "Call",
                                      style: TextStyle(
                                        color: Color(0xFFDC2626),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // 3. SMS Button
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () =>
                                  _launchSMS(item.contact ?? item.user?.mobile),
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFDBEAFE),
                                    width: 1,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.sms_outlined,
                                      size: 16,
                                      color: Color(0xFF2563EB),
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      "SMS",
                                      style: TextStyle(
                                        color: Color(0xFF2563EB),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return bodyWidget();
  }

  Widget bodyWidget() {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (isPop, re) {
          Constant.itemFilter = null;
        },
        child: Scaffold(
          backgroundColor: context.color.backgroundColor,
          floatingActionButton: _buildFloatingBottomBar(),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              backgroundColor: context.color.backgroundColor,
              onRefresh: () async {
                searchbody = {};

                final catIdInt = _activeCategoryId;
                if (catIdInt != 0) {
                  _fetchFilteredItems();
                }
              },
              color: context.color.territoryColor,
              child: SingleChildScrollView(
                controller: controller,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    _buildLocationHeader(),
                    const SizedBox(height: 6),
                    _buildFilterChips(),
                    _buildVerifiedToggle(),
                    const SizedBox(height: 4),
                    fetchItems(),
                    const SizedBox(height: 90),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void getFilterValue(ItemFilterModel model) {
    filter = model;
    setState(() {});
  }

  Widget bottomWidget() {
    return Container(
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        border: Border(
          top: BorderSide(
            color: context.color.borderColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: filterByWidget(),
          ),
          SizedBox(
            height: 24,
            child: VerticalDivider(
              color: context.color.borderColor.withValues(alpha: 0.5),
              thickness: 1,
            ),
          ),
          Expanded(
            child: sortByWidget(),
          ),
        ],
      ),
    );
  }

  Widget filterByWidget() {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          Routes.filterScreen,
          arguments: {
            "update": getFilterValue,
            "from": "itemsList",
            "categoryIds": _currentCategoryIds
          },
        ).then((value) {
          if (value == true && filter != null) {
            ItemFilterModel updatedFilter =
                filter!.copyWith(categoryId: widget.categoryId);

            context.read<FetchItemFromCategoryCubit>().fetchItemFromCategory(
                  categoryId: int.parse(widget.categoryId),
                  search: searchController.text,
                  filter: updatedFilter,
                );
          }
          setState(() {});
        });
      },
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 16, // smaller icon height
              width: 16, // smaller icon width
              child: UiUtils.getSvg(
                AppIcons.filterByIcon,
                color: context.color.textDefaultColor,
              ),
            ),
            const SizedBox(width: 7),
            Text("filterTitle".translate(context)),
          ],
        ),
      ),
    );
  }

  Widget sortByWidget() {
    return InkWell(
      onTap: showSortByBottomSheet,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UiUtils.getSvg(AppIcons.sortByIcon,
                color: context.color.textDefaultColor),
            const SizedBox(width: 7),
            Text("sortBy".translate(context)),
          ],
        ),
      ),
    );
  }

  void showSortByBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8.0),
          topRight: Radius.circular(8.0),
        ),
      ),
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Material(
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: context.color.borderColor,
                    ),
                    height: 6,
                    width: 60,
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 17, horizontal: 20),
                child: Text(
                  'sortBy'.translate(context),
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                  ),
                ),
              ),
              Divider(
                  height: 1,
                  color: context.color.borderColor.withValues(alpha: 0.35)),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: Text(
                  'default'.translate(context),
                  style: TextStyle(
                      color: context.color.textDefaultColor, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(context);
                  final catIdInt = _activeCategoryId;
                  if (catIdInt != 0) {
                    context
                        .read<FetchItemFromCategoryCubit>()
                        .fetchItemFromCategory(
                            categoryId: catIdInt,
                            search: searchController.text.toString(),
                            sortBy: null,
                            filter: filter);
                  }

                  setState(() {
                    sortBy = null;
                    FocusManager.instance.primaryFocus?.unfocus();
                  });
                },
              ),
              Divider(
                  height: 1,
                  color: context.color.borderColor.withValues(alpha: 0.35)),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: Text(
                  'newToOld'.translate(context),
                  style: TextStyle(
                      color: context.color.textDefaultColor, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(context);
                  final catIdInt = _activeCategoryId;
                  if (catIdInt != 0) {
                    context
                        .read<FetchItemFromCategoryCubit>()
                        .fetchItemFromCategory(
                            categoryId: catIdInt,
                            search: searchController.text.toString(),
                            sortBy: "new-to-old",
                            filter: filter);
                  }
                  setState(() {
                    sortBy = "new-to-old";
                    FocusManager.instance.primaryFocus?.unfocus();
                  });
                },
              ),
              Divider(
                  height: 1,
                  color: context.color.borderColor.withValues(alpha: 0.35)),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: Text(
                  'oldToNew'.translate(context),
                  style: TextStyle(
                      color: context.color.textDefaultColor, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(context);
                  final catIdInt = _activeCategoryId;
                  if (catIdInt != 0) {
                    context
                        .read<FetchItemFromCategoryCubit>()
                        .fetchItemFromCategory(
                            categoryId: catIdInt,
                            search: searchController.text.toString(),
                            sortBy: "old-to-new",
                            filter: filter);
                  }
                  setState(() {
                    sortBy = "old-to-new";
                    FocusManager.instance.primaryFocus?.unfocus();
                  });
                },
              ),
              Divider(
                  height: 1,
                  color: context.color.borderColor.withValues(alpha: 0.35)),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: Text(
                  'priceHighToLow'.translate(context),
                  style: TextStyle(
                      color: context.color.textDefaultColor, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(context);
                  final catIdInt = _activeCategoryId;
                  if (catIdInt != 0) {
                    context
                        .read<FetchItemFromCategoryCubit>()
                        .fetchItemFromCategory(
                            categoryId: catIdInt,
                            search: searchController.text.toString(),
                            sortBy: "price-high-to-low",
                            filter: filter);
                  }
                  setState(() {
                    sortBy = "price-high-to-low";
                    FocusManager.instance.primaryFocus?.unfocus();
                  });
                },
              ),
              Divider(
                  height: 1,
                  color: context.color.borderColor.withValues(alpha: 0.35)),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: Text(
                  'priceLowToHigh'.translate(context),
                  style: TextStyle(
                      color: context.color.textDefaultColor, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(context);
                  final catIdInt = _activeCategoryId;
                  if (catIdInt != 0) {
                    context
                        .read<FetchItemFromCategoryCubit>()
                        .fetchItemFromCategory(
                            categoryId: catIdInt,
                            search: searchController.text.toString(),
                            sortBy: "price-low-to-high",
                            filter: filter);
                  }
                  setState(() {
                    sortBy = "price-low-to-high";
                    FocusManager.instance.primaryFocus?.unfocus();
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget fetchItems() {
    return BlocBuilder<FetchItemFromCategoryCubit, FetchItemFromCategoryState>(
        builder: (context, state) {
      if (state is FetchItemFromCategoryInProgress) {
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          itemCount: 5,
          itemBuilder: (context, index) {
            return buildItemsShimmer(context);
          },
        );
      }

      if (state is FetchItemFromCategoryFailure) {
        return Center(
          child: Text(state.errorMessage),
        );
      }
      if (state is FetchItemFromCategorySuccess) {
        if (state.itemModel.isEmpty) {
          return Center(
            child: NoDataFound(
              onTap: () {
                final catIdInt = _activeCategoryId;
                if (catIdInt != 0) {
                  context
                      .read<FetchItemFromCategoryCubit>()
                      .fetchItemFromCategory(
                          categoryId: catIdInt,
                          search: searchController.text.toString(),
                          sortBy: sortBy,
                          filter: filter);
                }
              },
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDynamicSegmentTabs(state.itemModel),
            const SizedBox(height: 4),
            mainChildren(state.itemModel),
            if (state.isLoadingMore)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(child: UiUtils.progress()),
              ),
          ],
        );
      }
      return const SizedBox.shrink();
    });
  }

  void _navigateToDetails(BuildContext context, ItemModel item) {
    Navigator.pushNamed(
      context,
      Routes.adDetailsScreen,
      arguments: {'model': item},
    );
  }

  Widget mainChildren(List<ItemModel> items) {
    List<ItemModel> filteredItems = List.from(items);

    if (_showVerifiedOnly) {
      filteredItems = filteredItems
          .where((i) =>
              i.isFeature == true || i.status == "approved" || i.status == "1")
          .toList();
    }

    if (filteredItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Center(
          child: Text(
            "No items found matching criteria",
            style: TextStyle(
              color: context.color.textLightColor,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        ItemModel item = filteredItems[index];
        return _buildPropertyCard(context, item);
      },
    );
  }

  Widget _buildGridViewSection(BuildContext context, int startIndex,
      int itemCount, List<ItemModel> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCountAndFixedHeight(
          crossAxisCount: 2,
          height: MediaQuery.of(context).size.height / 3.5.rh(context),
          mainAxisSpacing: 7,
          crossAxisSpacing: 10),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        ItemModel item = items[startIndex + index];
        return GestureDetector(
          onTap: () => _navigateToDetails(context, item),
          child: ItemCard(item: item),
        );
      },
    );
  }

  Widget buildItemsShimmer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        height: 120.rh(context),
        decoration: BoxDecoration(
            border: Border.all(width: 1.5, color: context.color.borderColor),
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            CustomShimmer(
              height: 120.rh(context),
              width: 100.rw(context),
            ),
            SizedBox(
              width: 10.rw(context),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CustomShimmer(
                  width: 100.rw(context),
                  height: 10,
                  borderRadius: 7,
                ),
                CustomShimmer(
                  width: 150.rw(context),
                  height: 10,
                  borderRadius: 7,
                ),
                CustomShimmer(
                  width: 120.rw(context),
                  height: 10,
                  borderRadius: 7,
                ),
                CustomShimmer(
                  width: 80.rw(context),
                  height: 10,
                  borderRadius: 7,
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
