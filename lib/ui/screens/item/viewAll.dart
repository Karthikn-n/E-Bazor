// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/favorite/favorite_cubit.dart';
import 'package:Ebozor/data/cubits/favorite/manage_fav_cubit.dart';
import 'package:Ebozor/data/cubits/home/fetch_section_items_cubit.dart';
import 'package:Ebozor/data/cubits/system/location_change_cubit.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/data/model/item_filter_model.dart';
import 'package:Ebozor/data/repositories/favourites_repository.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/dialogs/save_to_favorite_bottom_sheet.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_data_found.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_internet.dart';
import 'package:Ebozor/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:Ebozor/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';

class SectionItemsScreen extends StatefulWidget {
  final String title;
  final dynamic sectionId;

  const SectionItemsScreen({
    super.key,
    required this.title,
    required this.sectionId,
  });

  static Route route(RouteSettings routeSettings) {
    Map? arguments = routeSettings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => SectionItemsScreen(
        title: arguments?['title'] ?? "",
        sectionId: arguments?['sectionId'] ?? 0,
      ),
    );
  }

  @override
  _SectionItemsScreenState createState() => _SectionItemsScreenState();
}

class _SectionItemsScreenState extends State<SectionItemsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // Search & Filter state
  String _searchQuery = '';
  String _selectedSort = 'new-to-old';
  String _selectedCondition = 'All';
  String? _selectedMaxPrice;

  int get parsedSectionId =>
      int.tryParse(widget.sectionId.toString()) ?? 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadItems();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.isEndReached()) {
      if (context.read<FetchSectionItemsCubit>().hasMoreData()) {
        context.read<FetchSectionItemsCubit>().fetchSectionItemMore(
              sectionId: parsedSectionId,
              city: HiveUtils.getCityName(),
              areaId: HiveUtils.getAreaId(),
              country: HiveUtils.getCountryName(),
              stateName: HiveUtils.getStateName(),
            );
      }
    }
  }

  void _loadItems() {
    context.read<FetchSectionItemsCubit>().fetchSectionItem(
          sectionId: parsedSectionId,
          city: HiveUtils.getCityName(),
          areaId: HiveUtils.getAreaId(),
          country: HiveUtils.getCountryName(),
          state: HiveUtils.getStateName(),
        );
  }

  void _onTapLocation() async {
    final result = await Navigator.pushNamed(
      context,
      Routes.citiesScreen,
      arguments: {"from": "filter"},
    );
    if (result != null) {
      final loc = result as Map<String, dynamic>;
      if (loc['clear'] == true) {
        context.read<LocationChangeCubit>().clearLocation();
      } else {
        context.read<LocationChangeCubit>().setLocation(
              city: loc['city']?.toString() ?? '',
              state: loc['state']?.toString() ?? '',
              country: loc['country']?.toString() ?? '',
              area: loc['area']?.toString() ?? '',
              areaId: loc['area_id'] != null
                  ? int.tryParse(loc['area_id'].toString())
                  : null,
              latitude: loc['latitude'] != null
                  ? double.tryParse(loc['latitude'].toString())
                  : null,
              longitude: loc['longitude'] != null
                  ? double.tryParse(loc['longitude'].toString())
                  : null,
            );
      }
      _loadItems();
    }
  }

  void _openFilters() {
    Navigator.pushNamed(
      context,
      Routes.filterScreen,
      arguments: {
        "update": (ItemFilterModel appliedFilter) {
          Constant.itemFilter = appliedFilter;
          _loadItems();
        },
        "from": "view_all",
      },
    ).then((value) {
      if (value == true) {
        _loadItems();
      }
    });
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Text(
                        'Sort Results',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildSortOption(ctx, 'Newest first', 'new-to-old'),
                _buildSortOption(ctx, 'Oldest first', 'old-to-new'),
                _buildSortOption(ctx, 'Price: Low to High', 'price-low-to-high'),
                _buildSortOption(ctx, 'Price: High to Low', 'price-high-to-low'),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortOption(BuildContext ctx, String label, String value) {
    final isSelected = _selectedSort == value;
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected
              ? context.color.territoryColor
              : context.color.textDefaultColor,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_rounded, color: context.color.territoryColor)
          : null,
      onTap: () {
        setState(() => _selectedSort = value);
        Navigator.pop(ctx);
      },
    );
  }

  void _showPriceFilterSheet() {
    final priceOptions = ['All Prices', 'Under 1,000', 'Under 5,000', 'Under 10,000', 'Under 50,000'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Text(
                    'Price Filter',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                ),
                ...priceOptions.map((opt) {
                  final isSelected = (_selectedMaxPrice == null && opt == 'All Prices') ||
                      (_selectedMaxPrice == opt);
                  return ListTile(
                    title: Text(
                      opt,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? context.color.territoryColor
                            : context.color.textDefaultColor,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_rounded, color: context.color.territoryColor)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedMaxPrice = opt == 'All Prices' ? null : opt;
                      });
                      Navigator.pop(ctx);
                    },
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showConditionFilterSheet() {
    final conditionOptions = ['All', 'New', 'Used'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Text(
                    'Condition',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                ),
                ...conditionOptions.map((opt) {
                  final isSelected = _selectedCondition == opt;
                  return ListTile(
                    title: Text(
                      opt,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? context.color.territoryColor
                            : context.color.textDefaultColor,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_rounded, color: context.color.territoryColor)
                        : null,
                    onTap: () {
                      setState(() => _selectedCondition = opt);
                      Navigator.pop(ctx);
                    },
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  List<ItemModel> _applyFiltersAndSort(List<ItemModel> rawItems) {
    List<ItemModel> items = List.from(rawItems);

    // Text search filter
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      items = items
          .where((item) =>
              (item.name ?? '').toLowerCase().contains(q) ||
              (item.description ?? '').toLowerCase().contains(q))
          .toList();
    }

    // Condition filter
    if (_selectedCondition != 'All') {
      items = items.where((item) {
        if (item.customFields == null) return true;
        for (final f in item.customFields!) {
          if ((f.name ?? '').toLowerCase().contains('condition')) {
            if (f.value != null && f.value!.isNotEmpty) {
              return f.value!.first
                  .toString()
                  .toLowerCase()
                  .contains(_selectedCondition.toLowerCase());
            }
          }
        }
        return true;
      }).toList();
    }

    // Max Price filter
    if (_selectedMaxPrice != null) {
      double max = double.infinity;
      if (_selectedMaxPrice == 'Under 1,000') max = 1000;
      if (_selectedMaxPrice == 'Under 5,000') max = 5000;
      if (_selectedMaxPrice == 'Under 10,000') max = 10000;
      if (_selectedMaxPrice == 'Under 50,000') max = 50000;
      items = items.where((item) => (item.price ?? 0) <= max).toList();
    }

    // Sorting
    if (_selectedSort == 'new-to-old') {
      items.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
    } else if (_selectedSort == 'old-to-new') {
      items.sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
    } else if (_selectedSort == 'price-low-to-high') {
      items.sort((a, b) => (a.price ?? 0).compareTo(b.price ?? 0));
    } else if (_selectedSort == 'price-high-to-low') {
      items.sort((a, b) => (b.price ?? 0).compareTo(a.price ?? 0));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocationChangeCubit, LocationChangeState>(
      listener: (context, locState) {
        setState(() {});
        _loadItems();
      },
      child: Scaffold(
        backgroundColor: context.color.backgroundColor,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopBar(),
              _buildSubHeader(),
              _buildFilterChips(),
              Expanded(
                child: BlocBuilder<FetchSectionItemsCubit, FetchSectionItemsState>(
                  builder: (context, state) {
                    if (state is FetchSectionItemsInProgress) {
                      return _buildShimmerGrid();
                    } else if (state is FetchSectionItemsSuccess) {
                      final filteredList = _applyFiltersAndSort(state.items);

                      if (filteredList.isEmpty) {
                        return Center(
                          child: NoDataFound(onTap: _loadItems),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async => _loadItems(),
                        color: context.color.territoryColor,
                        child: Column(
                          children: [
                            // Summary Row
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${filteredList.length} results',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: context.color.textLightColor,
                                    ),
                                  ),
                                  InkWell(
                                    onTap: _showSortSheet,
                                    child: Row(
                                      children: [
                                        Text(
                                          'Sort: ${_getSortLabel()}',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: context.color.textDefaultColor,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 18,
                                          color: context.color.textDefaultColor,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 2-Column Grid
                            Expanded(
                              child: GridView.builder(
                                controller: _scrollController,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.58,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                itemCount: filteredList.length,
                                itemBuilder: (context, index) {
                                  final item = filteredList[index];
                                  return _buildGridCard(item);
                                },
                              ),
                            ),
                            if (state.isLoadingMore)
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Center(
                                  child: UiUtils.progress(
                                    normalProgressColor:
                                        context.color.territoryColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    } else if (state is FetchSectionItemsFail) {
                      if (state.error is ApiException &&
                          (state.error as ApiException).errorMessage ==
                              "no-internet") {
                        return NoInternet(onRetry: _loadItems);
                      }
                      return const SomethingWentWrong();
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getSortLabel() {
    switch (_selectedSort) {
      case 'old-to-new':
        return 'Oldest';
      case 'price-low-to-high':
        return 'Price: Low';
      case 'price-high-to-low':
        return 'Price: High';
      default:
        return 'Newest';
    }
  }

  // --- Header Components ---

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: context.color.textDefaultColor,
              size: 24,
            ),
          ),
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: context.color.secondaryColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: context.color.borderColor.withValues(alpha: 0.6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Icon(
                    Icons.search_rounded,
                    color: context.color.textLightColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onChanged: (val) {
                        setState(() => _searchQuery = val);
                      },
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: context.color.textDefaultColor,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: widget.title.isNotEmpty
                            ? widget.title
                            : 'Search...',
                        hintStyle: TextStyle(
                          color: context.color.textLightColor.withValues(alpha: 0.7),
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade300,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Reactive Location Selector
          BlocBuilder<LocationChangeCubit, LocationChangeState>(
            builder: (context, locState) {
              final cityName = locState.city?.isNotEmpty == true
                  ? locState.city!
                  : (HiveUtils.getCityName() ?? 'Dushanbe');

              return InkWell(
                onTap: _onTapLocation,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 18,
                        color: Color(0xFF007AFF),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cityName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: Color(0xFF007AFF),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Filter Icon Button
          InkWell(
            onTap: _openFilters,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.color.secondaryColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: context.color.borderColor.withValues(alpha: 0.6),
                ),
              ),
              child: Icon(
                Icons.tune_rounded,
                size: 18,
                color: context.color.textDefaultColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final hasCategoryTitle =
        widget.title.isNotEmpty && widget.title.toLowerCase() != 'all';

    return Container(
      height: 42,
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // 'All' Pill
          _buildChip(
            label: 'All',
            isActive: _selectedCondition == 'All' && _selectedMaxPrice == null,
            onTap: () {
              setState(() {
                _selectedCondition = 'All';
                _selectedMaxPrice = null;
              });
            },
          ),
          if (hasCategoryTitle) ...[
            const SizedBox(width: 8),
            _buildChip(
              label: widget.title,
              isActive: false,
              onTap: () {},
            ),
          ],
          const SizedBox(width: 8),
          // Price Dropdown Chip
          _buildDropdownChip(
            label: _selectedMaxPrice ?? 'Price',
            isActive: _selectedMaxPrice != null,
            onTap: _showPriceFilterSheet,
          ),
          const SizedBox(width: 8),
          // Condition Dropdown Chip
          _buildDropdownChip(
            label: _selectedCondition != 'All' ? _selectedCondition : 'Condition',
            isActive: _selectedCondition != 'All',
            onTap: _showConditionFilterSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF007AFF) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF334155),
            fontSize: 13.5,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF007AFF).withValues(alpha: 0.12)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: isActive
              ? Border.all(color: const Color(0xFF007AFF), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF007AFF) : const Color(0xFF334155),
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isActive ? const Color(0xFF007AFF) : const Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }

  // --- Grid Card Component ---

  Widget _buildGridCard(ItemModel item) {
    final bool isPromoted = item.isFeature == true;
    final bool isVerified =
        item.user?.isVerified == 1 || item.user?.isVerified == true;

    final formattedPrice = item.price != null
        ? item.price!.toInt().toString().replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (m) => '${m[1]} ',
            )
        : null;

    final imageSrc = item.image?.isNotEmpty == true
        ? item.image!
        : (item.galleryImages?.isNotEmpty == true
            ? item.galleryImages!.first.image ?? ''
            : '');

    return Container(
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.pushNamed(
              context,
              Routes.adDetailsScreen,
              arguments: {'model': item},
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Header
              Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: SizedBox(
                      height: 135,
                      width: double.infinity,
                      child: imageSrc.isNotEmpty
                          ? UiUtils.imageType(imageSrc, fit: BoxFit.cover)
                          : Container(
                              color: Colors.grey.shade200,
                              child: Icon(
                                Icons.image_outlined,
                                size: 36,
                                color: Colors.grey.shade400,
                              ),
                            ),
                    ),
                  ),
                  if (isPromoted)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF7A00),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Promoted',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Favorite Heart Button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _buildFavoriteButton(item),
                  ),
                ],
              ),
              // Card Details
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: context.color.textDefaultColor,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (formattedPrice != null)
                      Text(
                        '$formattedPrice ${Constant.currencySymbol}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: context.color.textLightColor,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            item.city?.isNotEmpty == true
                                ? item.city!
                                : (item.address ?? 'Dushanbe'),
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
                    if (isVerified) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: const [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 13,
                            color: Color(0xFF007AFF),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Verified',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF007AFF),
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
      ),
    );
  }

  Widget _buildFavoriteButton(ItemModel item) {
    if (item.id == null) return const SizedBox.shrink();

    return BlocProvider(
      create: (_) => UpdateFavoriteCubit(FavoriteRepository()),
      child: BlocConsumer<FavoriteCubit, FavoriteState>(
        bloc: context.read<FavoriteCubit>(),
        listener: (context, favState) {},
        builder: (context, favState) {
          final isLike =
              context.read<FavoriteCubit>().isItemFavorite(item.id!);

          return BlocConsumer<UpdateFavoriteCubit, UpdateFavoriteState>(
            listener: (context, updateState) {
              if (updateState is UpdateFavoriteSuccess) {
                if (updateState.wasProcess) {
                  context.read<FavoriteCubit>().addFavoriteitem(updateState.item);
                } else {
                  context.read<FavoriteCubit>().removeFavoriteItem(updateState.item);
                }
              }
            },
            builder: (context, updateState) {
              return InkWell(
                onTap: () {
                  UiUtils.checkUser(
                    context: context,
                    onNotGuest: () {
                      if (isLike) {
                        context.read<UpdateFavoriteCubit>().setFavoriteItem(
                              item: item,
                              type: 0,
                            );
                        return;
                      }
                      context
                          .read<UpdateFavoriteCubit>()
                          .setFavoriteItem(item: item, type: 1);
                      SaveToFavoriteBottomSheet.show(context, item: item);
                    },
                  );
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      isLike ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 18,
                      color: isLike ? Colors.red : Colors.black87,
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

  Widget _buildShimmerGrid() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.58,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              child: CustomShimmer(height: 135, width: double.infinity),
            ),
            Padding(
              padding: EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomShimmer(height: 14, width: 110),
                  SizedBox(height: 8),
                  CustomShimmer(height: 16, width: 80),
                  SizedBox(height: 8),
                  CustomShimmer(height: 12, width: 60),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
