// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/favorite/favorite_cubit.dart';
import 'package:Ebozor/data/cubits/favorite/manage_fav_cubit.dart';
import 'package:Ebozor/data/cubits/item/search_item_cubit.dart';
import 'package:Ebozor/data/cubits/system/location_change_cubit.dart';
import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/data/model/custom_field/custom_field_model.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/data/model/item_filter_model.dart';
import 'package:Ebozor/data/repositories/favourites_repository.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/dialogs/save_to_favorite_bottom_sheet.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_data_found.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';

class SearchScreen extends StatefulWidget {
  final bool autoFocus;
  final String? initialQuery;

  const SearchScreen({
    super.key,
    required this.autoFocus,
    this.initialQuery,
  });

  static Route route(RouteSettings settings) {
    Map? arguments = settings.arguments as Map?;

    return BlurredRouter(
      builder: (context) => BlocProvider(
        create: (context) => SearchItemCubit(),
        child: SearchScreen(
          autoFocus: arguments?['autoFocus'] ?? false,
          initialQuery: arguments?['query'] ?? arguments?['search'],
        ),
      ),
    );
  }

  @override
  SearchScreenState createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin {
  static TextEditingController searchController = TextEditingController();
  TextEditingController get _searchController => searchController;
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounceTimer;

  // View Mode: false = List View, true = Map View
  bool _isMapView = false;

  // Filter & Categories
  ItemFilterModel? filter;
  List<CategoryModel> categoryList = [];

  // Sorting
  String _selectedSort = 'new-to-old';

  // Map state
  GoogleMapController? _mapController;
  Set<Marker> _mapMarkers = {};
  ItemModel? _selectedMapItem;
  List<ItemModel> _latestItems = [];
  static const LatLng _dushanbeCenter = LatLng(38.5598, 68.7870);

  @override
  void initState() {
    super.initState();
    searchController.text = widget.initialQuery ?? "";

    // Initialize default filter with current location
    filter = Constant.itemFilter ??
        ItemFilterModel(
          city: HiveUtils.getCityName() ?? "Dushanbe",
          country: HiveUtils.getCountryName() ?? "",
        );

    _scrollController.addListener(_onScroll);

    // Initial search
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _executeSearch();
    });
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.isEndReached()) {
      if (context.read<SearchItemCubit>().hasMoreData()) {
        context.read<SearchItemCubit>().fetchMoreSearchData(
              _searchController.text.trim(),
              filter,
            );
      }
    }
  }

  void _executeSearch() {
    context.read<SearchItemCubit>().searchItem(
          _searchController.text.trim(),
          page: 1,
          filter: filter,
        );
  }

  void _onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 400), () {
      _executeSearch();
    });
    setState(() {});
  }

  // --- Map Marker Generation ---

  Future<BitmapDescriptor> _createPriceMarkerBitmap(String price) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final textSpan = TextSpan(
        text: price,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      const double padX = 10;
      const double padY = 5;
      final double width = textPainter.width + (padX * 2);
      final double height = textPainter.height + (padY * 2);
      const double triangleH = 4;
      const double triangleW = 7;

      // Shadow
      final Paint shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      final RRect bubbleRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height),
        const Radius.circular(8),
      );
      canvas.drawRRect(bubbleRRect.shift(const Offset(0, 1.5)), shadowPaint);

      // Bubble background
      final Paint bubblePaint = Paint()..color = const Color(0xFF007AFF);
      canvas.drawRRect(bubbleRRect, bubblePaint);

      // Down arrow pointer
      final Path triangle = Path();
      triangle.moveTo(width / 2 - triangleW / 2, height);
      triangle.lineTo(width / 2 + triangleW / 2, height);
      triangle.lineTo(width / 2, height + triangleH);
      triangle.close();
      canvas.drawPath(triangle, bubblePaint);

      // Circle pin dot below pointer (matches map_view.jpeg)
      canvas.drawCircle(
        Offset(width / 2, height + triangleH + 2.5),
        2.5,
        bubblePaint,
      );

      // Text
      textPainter.paint(canvas, const Offset(padX, padY));

      final picture = recorder.endRecording();
      final img = await picture.toImage(
        width.toInt(),
        (height + triangleH + 7).toInt(),
      );
      final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
      return BitmapDescriptor.bytes(pngBytes!.buffer.asUint8List());
    } catch (_) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
  }

  void _animateCameraToItems(List<ItemModel> items) {
    if (_mapController == null || items.isEmpty) return;

    final validCoords = <LatLng>[];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final lat = item.latitude != null && item.latitude != 0
          ? item.latitude!
          : (_dushanbeCenter.latitude + (((item.id ?? i) % 17) - 8) * 0.007);
      final lng = item.longitude != null && item.longitude != 0
          ? item.longitude!
          : (_dushanbeCenter.longitude + (((item.id ?? i) % 13) - 6) * 0.008);
      validCoords.add(LatLng(lat, lng));
    }

    if (validCoords.isNotEmpty) {
      if (validCoords.length == 1) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(validCoords.first, 13.5),
        );
      } else {
        double minLat = validCoords.first.latitude;
        double maxLat = validCoords.first.latitude;
        double minLng = validCoords.first.longitude;
        double maxLng = validCoords.first.longitude;
        for (final c in validCoords) {
          if (c.latitude < minLat) minLat = c.latitude;
          if (c.latitude > maxLat) maxLat = c.latitude;
          if (c.longitude < minLng) minLng = c.longitude;
          if (c.longitude > maxLng) maxLng = c.longitude;
        }
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(minLat - 0.005, minLng - 0.005),
              northeast: LatLng(maxLat + 0.005, maxLng + 0.005),
            ),
            50,
          ),
        );
      }
    }
  }

  Future<void> _buildMapMarkers(List<ItemModel> items) async {
    _latestItems = items;
    final Set<Marker> markers = {};
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      // Use real item coords or distribute realistically across Dushanbe
      final lat = item.latitude != null && item.latitude != 0
          ? item.latitude!
          : (_dushanbeCenter.latitude + (((item.id ?? i) % 17) - 8) * 0.007);
      final lng = item.longitude != null && item.longitude != 0
          ? item.longitude!
          : (_dushanbeCenter.longitude + (((item.id ?? i) % 13) - 6) * 0.008);

      final priceStr = item.price != null
          ? item.price!.toInt().toString().replaceAllMapped(
                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                (m) => '${m[1]} ',
              )
          : '0';

      final icon = await _createPriceMarkerBitmap(priceStr);

      markers.add(
        Marker(
          markerId: MarkerId('item_${item.id ?? i}'),
          position: LatLng(lat, lng),
          icon: icon,
          onTap: () {
            setState(() {
              _selectedMapItem = item;
            });
            _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(LatLng(lat, lng), 14.5),
            );
          },
        ),
      );
    }

    if (mounted) {
      setState(() {
        _mapMarkers = markers;
        if (_selectedMapItem == null && items.isNotEmpty) {
          _selectedMapItem = items.first;
        }
      });
      _animateCameraToItems(items);
    }
  }

  // --- Filter Navigation ---

  void _openFilterScreen() {
    Navigator.pushNamed(
      context,
      Routes.filterScreen,
      arguments: {
        "update": (ItemFilterModel newFilter) {
          setState(() {
            filter = newFilter;
          });
          _executeSearch();
        },
        "from": "search",
        "categoryList": categoryList,
      },
    ).then((value) {
      if (value == true) {
        setState(() {
          filter = Constant.itemFilter;
        });
        _executeSearch();
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
        setState(() {
          _selectedSort = value;
        });
        Navigator.pop(ctx);
        _executeSearch();
      },
    );
  }

  // --- Spec Extraction Helpers ---

  String? _findCustomFieldValue(List<CustomFieldModel>? fields, String query) {
    if (fields == null) return null;
    final q = query.toLowerCase();
    for (final f in fields) {
      final name = (f.name ?? '').toLowerCase();
      final label = (f.label ?? '').toLowerCase();
      if (name.contains(q) || label.contains(q)) {
        if (f.value != null && f.value!.isNotEmpty) {
          final val = f.value!.first.toString().trim();
          if (val.isNotEmpty && val.toLowerCase() != 'null') return val;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocationChangeCubit, LocationChangeState>(
      listener: (context, locState) {
        if (locState.city != null && locState.city != filter?.city) {
          setState(() {
            filter = (filter ?? ItemFilterModel()).copyWith(
              city: locState.city,
              state: locState.state,
              country: locState.country,
              area: locState.area,
              areaId: locState.areaId,
              latitude: locState.latitude,
              longitude: locState.longitude,
            );
          });
          _executeSearch();
        }
      },
      child: Scaffold(
        backgroundColor: context.color.backgroundColor,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopSearchBar(),
              _buildFilterChipsRow(),
              _buildSegmentedToggle(),
              Expanded(
                child: BlocConsumer<SearchItemCubit, SearchItemState>(
                  listener: (context, state) {
                    if (state is SearchItemSuccess) {
                      _buildMapMarkers(state.searchedItems);
                    }
                  },
                  builder: (context, state) {
                    if (state is SearchItemFetchProgress) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: context.color.territoryColor,
                        ),
                      );
                    }

                    if (state is SearchItemFailure) {
                      return Center(
                        child: Text(
                          state.errorMessage,
                          style: TextStyle(color: context.color.textLightColor),
                        ),
                      );
                    }

                    final items = (state is SearchItemSuccess)
                        ? state.searchedItems
                        : <ItemModel>[];

                    if (_isMapView) {
                      return _buildMapView(items);
                    }

                    return _buildListView(items, state);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI Components ---




  Widget _buildTopSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (_isMapView) {
                setState(() => _isMapView = false);
              } else {
                Navigator.pop(context);
              }
            },
            icon: Icon(
              Icons.arrow_back_rounded,
              color: context.color.textDefaultColor,
              size: 24,
            ),
          ),
          Expanded(
            child: Container(
              height: 48,
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
                      focusNode: _searchFocusNode,
                      autofocus: widget.autoFocus,
                      textInputAction: TextInputAction.search,
                      onChanged: _onSearchChanged,
                      onSubmitted: (_) {
                        _searchFocusNode.unfocus();
                        _executeSearch();
                      },
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: context.color.textDefaultColor,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Toyota Land Cruiser',
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
                        _executeSearch();
                        setState(() {});
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

  Widget _buildFilterChipsRow() {
    final activeCity = filter?.city?.isNotEmpty == true
        ? filter!.city!
        : (HiveUtils.getCityName() ?? 'Dushanbe');

    final minPrice = filter?.minPrice;
    final maxPrice = filter?.maxPrice;
    final year = filter?.customFields?['min_year'] ?? filter?.customFields?['year'];
    final make = filter?.customFields?['car_make_name'] ?? filter?.customFields?['make'];

    return Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildFilterChip(
            label: activeCity,
            onRemove: () {
              setState(() {
                filter = filter?.copyWith(city: '');
              });
              _executeSearch();
            },
          ),
          if (make != null)
            _buildFilterChip(
              label: make.toString(),
              onRemove: () {
                setState(() {
                  filter?.customFields?.remove('car_make');
                  filter?.customFields?.remove('car_make_name');
                  filter?.customFields?.remove('make');
                });
                _executeSearch();
              },
            ),
          if (year != null)
            _buildFilterChip(
              label: '${year}+',
              onRemove: () {
                setState(() {
                  filter?.customFields?.remove('min_year');
                  filter?.customFields?.remove('year');
                });
                _executeSearch();
              },
            ),
          if (maxPrice != null && maxPrice.isNotEmpty)
            _buildFilterChip(
              label: 'Under $maxPrice ${Constant.currencySymbol}',
              onRemove: () {
                setState(() {
                  filter = filter?.copyWith(clearMaxPrice: true);
                });
                _executeSearch();
              },
            )
          else if (minPrice != null && minPrice.isNotEmpty && minPrice != '0')
            _buildFilterChip(
              label: 'Over $minPrice ${Constant.currencySymbol}',
              onRemove: () {
                setState(() {
                  filter = filter?.copyWith(clearMinPrice: true);
                });
                _executeSearch();
              },
            ),
          // Filter Settings Icon
          InkWell(
            onTap: _openFilterScreen,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 38,
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

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.only(left: 12, right: 6, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEBF3FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF007AFF),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.all(2.0),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: Color(0xFF007AFF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedToggle() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        height: 52,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? context.color.secondaryColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isDark
                ? context.color.borderColor.withValues(alpha: 0.5)
                : const Color(0xFFE2E8F0),
            width: 1.2,
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
            // List Tab
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_isMapView) {
                    setState(() => _isMapView = false);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.fastOutSlowIn,
                  decoration: BoxDecoration(
                    color: !_isMapView ? const Color(0xFF007AFF) : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: !_isMapView
                        ? [
                            BoxShadow(
                              color: const Color(0xFF007AFF).withValues(alpha: 0.32),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.format_list_bulleted_rounded,
                        size: 20,
                        color: !_isMapView
                            ? Colors.white
                            : (isDark ? Colors.white70 : const Color(0xFF475569)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'List',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: !_isMapView
                              ? Colors.white
                              : (isDark ? Colors.white70 : const Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Map Tab
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!_isMapView) {
                    setState(() => _isMapView = true);
                    Future.delayed(const Duration(milliseconds: 250), () {
                      if (_latestItems.isNotEmpty) {
                        _animateCameraToItems(_latestItems);
                      }
                    });
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.fastOutSlowIn,
                  decoration: BoxDecoration(
                    color: _isMapView ? const Color(0xFF007AFF) : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: _isMapView
                        ? [
                            BoxShadow(
                              color: const Color(0xFF007AFF).withValues(alpha: 0.32),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 20,
                        color: _isMapView
                            ? Colors.white
                            : (isDark ? Colors.white70 : const Color(0xFF475569)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Map',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: _isMapView
                              ? Colors.white
                              : (isDark ? Colors.white70 : const Color(0xFF475569)),
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
    );
  }

  // --- List View Content ---

  Widget _buildListView(List<ItemModel> items, SearchItemState state) {
    if (items.isEmpty) {
      return Center(
        child: NoDataFound(onTap: _executeSearch),
      );
    }

    final totalCount = (state is SearchItemSuccess) ? state.total : items.length;

    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          // Results Header & Sort
          return Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$totalCount results',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.color.textLightColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                InkWell(
                  onTap: _showSortSheet,
                  child: Row(
                    children: [
                      Text(
                        'Sort',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.color.textDefaultColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.swap_vert_rounded,
                        size: 18,
                        color: context.color.textDefaultColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final item = items[index - 1];
        return _buildItemCard(item);
      },
    );
  }

  Widget _buildItemCard(ItemModel item) {
    final year = _findCustomFieldValue(item.customFields, 'year');
    final mileage = _findCustomFieldValue(item.customFields, 'mileage') ??
        _findCustomFieldValue(item.customFields, 'km');
    final fuel = _findCustomFieldValue(item.customFields, 'fuel');
    final transmission = _findCustomFieldValue(item.customFields, 'transmission');
    final drivetrain = _findCustomFieldValue(item.customFields, 'drive') ??
        _findCustomFieldValue(item.customFields, '4wd');

    final bool isFeatured = item.isFeature == true;
    final bool isVerified =
        item.user?.isVerified == 1 || item.user?.isVerified == true;

    final formattedPrice = item.price != null
        ? item.price!.toInt().toString().replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (m) => '${m[1]},',
            )
        : null;

    final imageSrc = item.image?.isNotEmpty == true
        ? item.image!
        : (item.galleryImages?.isNotEmpty == true
            ? item.galleryImages!.first.image ?? ''
            : '');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: SizedBox(
                      height: 190,
                      width: double.infinity,
                      child: imageSrc.isNotEmpty
                          ? UiUtils.imageType(
                              imageSrc,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: Icon(
                                Icons.image_outlined,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                            ),
                    ),
                  ),
                  if (isFeatured)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF7A00),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Featured',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Favorite Heart Button
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _buildFavoriteButton(item),
                  ),
                ],
              ),
              // Body Content
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      item.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Price
                    if (formattedPrice != null)
                      Text(
                        '$formattedPrice ${Constant.currencySymbol}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    // Dynamic Specs Row (Real values only)
                    if (year != null ||
                        mileage != null ||
                        fuel != null ||
                        transmission != null ||
                        drivetrain != null) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          if (year != null)
                            _buildSpecChip(Icons.calendar_today_outlined, year),
                          if (mileage != null)
                            _buildSpecChip(
                              Icons.speed_outlined,
                              mileage.contains('km') ? mileage : '$mileage km',
                            ),
                          if (fuel != null)
                            _buildSpecChip(Icons.local_gas_station_outlined, fuel),
                          if (transmission != null)
                            _buildSpecChip(Icons.settings_outlined, transmission),
                          if (drivetrain != null)
                            _buildSpecChip(Icons.tune_outlined, drivetrain),
                        ],
                      ),
                    ] else if (item.customFields != null &&
                        item.customFields!.isNotEmpty) ...[
                      // Dynamic real attributes for non-car items
                      Builder(builder: (context) {
                        final validFields = item.customFields!
                            .where((f) =>
                                f.value != null &&
                                f.value!.isNotEmpty &&
                                f.value!.first.toString().trim().isNotEmpty &&
                                f.value!.first.toString().toLowerCase() != 'null')
                            .take(4)
                            .toList();
                        if (validFields.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            children: validFields.map((f) {
                              return _buildSpecChip(
                                Icons.info_outline_rounded,
                                '${f.value!.first}',
                              );
                            }).toList(),
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 12),
                    Divider(height: 1, color: Colors.grey.shade100),
                    const SizedBox(height: 10),
                    // Footer: Location & Verified Seller Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 15,
                              color: context.color.textLightColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item.city?.isNotEmpty == true
                                  ? item.city!
                                  : (item.address ?? 'Dushanbe'),
                              style: TextStyle(
                                fontSize: 13,
                                color: context.color.textLightColor,
                              ),
                            ),
                          ],
                        ),
                        if (isVerified)
                          Row(
                            children: const [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: Color(0xFF007AFF),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Verified seller',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF007AFF),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
                  width: 36,
                  height: 36,
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
                      size: 20,
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

  // --- Map View Content ---

  Widget _buildMapView(List<ItemModel> items) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: items.isNotEmpty && items.first.latitude != null && items.first.latitude != 0
                ? LatLng(items.first.latitude!, items.first.longitude!)
                : _dushanbeCenter,
            zoom: 12.5,
          ),
          markers: _mapMarkers,
          onMapCreated: (controller) {
            _mapController = controller;
            if (items.isNotEmpty) {
              _animateCameraToItems(items);
            }
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
        // Floating Controls: GPS & compass buttons
        Positioned(
          right: 16,
          bottom: _selectedMapItem != null ? 140 : 80,
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: 'my_location',
                backgroundColor: Colors.white,
                elevation: 3,
                onPressed: () {
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(_dushanbeCenter, 13.0),
                  );
                },
                child: const Icon(
                  Icons.my_location_rounded,
                  color: Color(0xFF007AFF),
                  size: 20,
                ),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'compass_btn',
                backgroundColor: Colors.white,
                elevation: 3,
                onPressed: () {
                  _mapController?.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: _selectedMapItem != null && _selectedMapItem!.latitude != null
                            ? LatLng(_selectedMapItem!.latitude!, _selectedMapItem!.longitude!)
                            : _dushanbeCenter,
                        zoom: 13.0,
                        bearing: 0,
                      ),
                    ),
                  );
                },
                child: const Icon(
                  Icons.navigation_rounded,
                  color: Color(0xFF007AFF),
                  size: 20,
                ),
              ),
              const SizedBox(height: 10),
              // Switch back to list pill
              InkWell(
                onTap: () => setState(() => _isMapView = false),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.view_list_rounded,
                          size: 16, color: Color(0xFF007AFF)),
                      SizedBox(width: 6),
                      Text(
                        'List view',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Bottom Selected Item Preview Card
        if (_selectedMapItem != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _buildMapPreviewCard(_selectedMapItem!),
          ),
      ],
    );
  }

  Widget _buildMapPreviewCard(ItemModel item) {
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

    final year = _findCustomFieldValue(item.customFields, 'year');
    final mileage = _findCustomFieldValue(item.customFields, 'mileage');

    return Container(
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 95,
                        height: 85,
                        child: imageSrc.isNotEmpty
                            ? UiUtils.imageType(imageSrc, fit: BoxFit.cover)
                            : Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.image_outlined),
                              ),
                      ),
                    ),
                    if (item.isFeature == true)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF7A00),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Promoted',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.name ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: context.color.textDefaultColor,
                              ),
                            ),
                          ),
                          _buildFavoriteButton(item),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (formattedPrice != null)
                        Text(
                          '$formattedPrice ${Constant.currencySymbol}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: context.color.textLightColor,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              item.city?.isNotEmpty == true
                                  ? item.city!
                                  : (item.address ?? 'Dushanbe'),
                              style: TextStyle(
                                fontSize: 12,
                                color: context.color.textLightColor,
                              ),
                            ),
                            if (year != null) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 12,
                                color: context.color.textLightColor,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                year,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.color.textLightColor,
                                ),
                              ),
                            ],
                            if (mileage != null) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.speed_outlined,
                                size: 12,
                                color: context.color.textLightColor,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                mileage.contains('km') ? mileage : '$mileage km',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.color.textLightColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
