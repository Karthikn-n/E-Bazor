import 'dart:developer';
import 'package:Ebozor/data/model/data_output.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/favorite/favorite_cubit.dart';
import 'package:Ebozor/data/cubits/favorite/manage_fav_cubit.dart';
import 'package:Ebozor/data/model/cars/car_models.dart';
import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/data/model/custom_field/custom_field_model.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/data/repositories/cars_repository.dart';
import 'package:Ebozor/data/repositories/category_repository.dart';
import 'package:Ebozor/data/repositories/favourites_repository.dart';
import 'package:Ebozor/data/repositories/item/item_repository.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:Ebozor/utils/ui_utils.dart';

class MotorsHomeScreen extends StatefulWidget {
  final CategoryModel? category;

  const MotorsHomeScreen({super.key, this.category});

  @override
  State<MotorsHomeScreen> createState() => _MotorsHomeScreenState();

  static Route route(RouteSettings routeSettings) {
    Map? args = routeSettings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => MotorsHomeScreen(
        category: args?['category'] as CategoryModel?,
      ),
    );
  }
}

class _MotorsHomeScreenState extends State<MotorsHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final CarsRepository _carsRepository = CarsRepository();
  final ItemRepository _itemRepository = ItemRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();

  bool _isLoading = true;
  String? _selectedVehicleType;
  String _selectedSort = 'recommended';
  int _totalCarsCount = 12845;

  List<CarMake> _carMakes = [];
  List<ItemModel> _recommendedCars = [];
  List<CategoryModel> _vehicleTypes = [];

  // Standard fallback vehicle categories
  final List<Map<String, dynamic>> _defaultVehicleTypes = [
    {
      'title': 'Cars',
      'icon': Icons.directions_car_rounded,
      'image': 'https://images.unsplash.com/photo-1541899481282-d53bffe3c35d?w=300&q=80',
    },
    {
      'title': 'SUVs',
      'icon': Icons.airport_shuttle_rounded,
      'image': 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?w=300&q=80',
    },
    {
      'title': 'Motorcycles',
      'icon': Icons.two_wheeler_rounded,
      'image': 'https://images.unsplash.com/photo-1558981403-c5f9899a28bc?w=300&q=80',
    },
    {
      'title': 'Commercial',
      'icon': Icons.local_shipping_rounded,
      'image': 'https://images.unsplash.com/photo-1601584115197-04ecc0da31d7?w=300&q=80',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadAllMotorsData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _motorsCategoryId {
    if (widget.category?.id != null && widget.category!.id! > 0) {
      return widget.category!.id!;
    }
    return 1;
  }

  Future<void> _loadAllMotorsData() async {
    setState(() => _isLoading = true);

    try {
      // 1. Fetch Popular Makes
      final makesFuture = _carsRepository.fetchCarMakes().catchError((e) {
        log('Error fetching car makes: $e');
        return <CarMake>[];
      });

      // 2. Fetch Recommended Cars for category (categoryId: 1)
      final carsFuture = _itemRepository
          .fetchItemFromCatId(
            categoryId: _motorsCategoryId,
            page: 1,
            sortBy: _selectedSort == 'recommended' ? null : _selectedSort,
          )
          .catchError((e) {
        log('Error fetching motors items: $e');
        return DataOutput<ItemModel>(total: 0, modelList: []);
      });

      // 3. Fetch Subcategories (Vehicle Types)
      final subCategoriesFuture = _categoryRepository
          .fetchCategoryChildrenByParent(parentId: _motorsCategoryId)
          .catchError((e) {
        log('Error fetching vehicle types: $e');
        return <CategoryModel>[];
      });

      final results = await Future.wait([makesFuture, carsFuture, subCategoriesFuture]);

      _carMakes = results[0] as List<CarMake>;
      final carOutput = results[1] as DataOutput<ItemModel>;
      _vehicleTypes = results[2] as List<CategoryModel>;

      if (carOutput.total > 0) {
        _totalCarsCount = carOutput.total;
      }

      if (carOutput.modelList.isNotEmpty) {
        _recommendedCars = carOutput.modelList;
      } else {
        // Fallback to demo items matching the mockup if backend has no motor items yet
        _recommendedCars = _getDemoRecommendedCars();
      }

      // If backend car makes is empty, use standard top brands
      if (_carMakes.isEmpty) {
        _carMakes = _getDemoCarMakes();
      }
    } catch (e) {
      log('Error loading motors data: $e');
      _recommendedCars = _getDemoRecommendedCars();
      _carMakes = _getDemoCarMakes();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<CarMake> _getDemoCarMakes() {
    return [
      CarMake(id: 1, name: 'Toyota'),
      CarMake(id: 2, name: 'Mercedes-Benz'),
      CarMake(id: 3, name: 'BMW'),
      CarMake(id: 4, name: 'Hyundai'),
      CarMake(id: 5, name: 'Kia'),
      CarMake(id: 6, name: 'Volkswagen'),
      CarMake(id: 7, name: 'Nissan'),
      CarMake(id: 8, name: 'Lexus'),
    ];
  }

  List<ItemModel> _getDemoRecommendedCars() {
    return [
      ItemModel(
        id: 99101,
        name: 'Toyota Land Cruiser 300',
        price: 820000,
        city: 'Dushanbe',
        address: 'Dushanbe, Tajikistan',
        image: 'https://images.unsplash.com/photo-1594502184342-2e12f877aa73?w=600&q=80',
        isFeature: true,
        carMakeName: 'Toyota',
        carModelName: 'Land Cruiser 300',
        customFields: [
          CustomFieldModel(name: 'Year', value: ['2022']),
          CustomFieldModel(name: 'Kilometers', value: ['28 000 km']),
        ],
      ),
      ItemModel(
        id: 99102,
        name: 'BMW 5 Series',
        price: 420000,
        city: 'Dushanbe',
        address: 'Dushanbe, Tajikistan',
        image: 'https://images.unsplash.com/photo-1555215695-3004980ad54e?w=600&q=80',
        isFeature: false,
        carMakeName: 'BMW',
        carModelName: '5 Series',
        customFields: [
          CustomFieldModel(name: 'Year', value: ['2020']),
          CustomFieldModel(name: 'Kilometers', value: ['45 000 km']),
        ],
      ),
      ItemModel(
        id: 99103,
        name: 'Mercedes-Benz E-Class',
        price: 395000,
        city: 'Dushanbe',
        address: 'Dushanbe, Tajikistan',
        image: 'https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8?w=600&q=80',
        isFeature: true,
        carMakeName: 'Mercedes-Benz',
        carModelName: 'E-Class',
        customFields: [
          CustomFieldModel(name: 'Year', value: ['2021']),
          CustomFieldModel(name: 'Kilometers', value: ['34 000 km']),
        ],
      ),
      ItemModel(
        id: 99104,
        name: 'Hyundai Santa Fe',
        price: 285000,
        city: 'Khujand',
        address: 'Khujand, Tajikistan',
        image: 'https://images.unsplash.com/photo-1563720223185-11003d516935?w=600&q=80',
        isFeature: false,
        carMakeName: 'Hyundai',
        carModelName: 'Santa Fe',
        customFields: [
          CustomFieldModel(name: 'Year', value: ['2023']),
          CustomFieldModel(name: 'Kilometers', value: ['15 000 km']),
        ],
      ),
    ];
  }

  void _onSearchSubmit(String query) {
    final trimmed = query.trim();
    Navigator.pushNamed(
      context,
      Routes.itemsList,
      arguments: {
        'catID': '6',
        'catName': 'Used Cars',
        'catSlug': 'used-cars',
        'categoryIds': ['1', '5', '6'],
        'search': trimmed.isNotEmpty ? trimmed : null,
      },
    );
  }

  void _onMakeTap(CarMake make) {
    Navigator.pushNamed(
      context,
      Routes.itemsList,
      arguments: {
        'catID': '6',
        'catName': 'Used Cars',
        'catSlug': 'used-cars',
        'categoryIds': ['1', '5', '6'],
        'search': make.name,
      },
    );
  }

  void _onVehicleTypeTap(String typeTitle) {
    setState(() {
      _selectedVehicleType = typeTitle;
    });

    final lower = typeTitle.toLowerCase();
    String targetCatId = '6';
    String targetSlug = 'used-cars';
    String targetName = 'Used Cars';
    List<String> targetChainIds = ['1', '5', '6'];
    String? searchParam;

    if (lower == 'cars') {
      targetCatId = '6';
      targetSlug = 'used-cars';
      targetName = 'Used Cars';
      targetChainIds = ['1', '5', '6'];
    } else if (lower == 'suvs') {
      targetCatId = '6';
      targetSlug = 'used-cars';
      targetName = 'SUVs';
      targetChainIds = ['1', '5', '6'];
      searchParam = 'SUV';
    } else if (lower == 'motorcycles') {
      targetCatId = '13';
      targetSlug = 'motorcycles';
      targetName = 'Motorcycles';
      targetChainIds = ['1', '13'];
    } else if (lower == 'commercial') {
      targetCatId = '37';
      targetSlug = 'heavy-vehicles';
      targetName = 'Heavy Vehicles';
      targetChainIds = ['1', '37'];
    }

    Navigator.pushNamed(
      context,
      Routes.itemsList,
      arguments: {
        'catID': targetCatId,
        'catName': targetName,
        'catSlug': targetSlug,
        'categoryIds': targetChainIds,
        if (searchParam != null) 'search': searchParam,
      },
    );
  }

  void _openFilters() {
    Navigator.pushNamed(
      context,
      Routes.filterpage,
      arguments: {
        'category': CategoryModel(
          id: 6,
          name: 'Used Cars',
          slug: 'used-cars',
          children: const [],
          subcategoriesCount: 0,
        ),
        'categorySlug': 'used-cars',
        'categoryIds': ['1', '5', '6'],
        'isFromItemsList': false,
      },
    );
  }

  void _openAllCars() {
    Navigator.pushNamed(
      context,
      Routes.itemsList,
      arguments: {
        'catID': '6',
        'catName': 'Used Cars',
        'catSlug': 'used-cars',
        'categoryIds': ['1', '5', '6'],
      },
    );
  }

  String _formatPrice(double? price) {
    if (price == null) return 'Price on request';
    final formatter = NumberFormat('#,###', 'en_US');
    return '${formatter.format(price.toInt()).replaceAll(',', ' ')} TJS';
  }

  String _formatCount(int count) {
    final formatter = NumberFormat('#,###', 'en_US');
    return formatter.format(count).replaceAll(',', ' ');
  }

  String? _getItemYear(ItemModel item) {
    if (item.customFields != null) {
      for (final cf in item.customFields!) {
        final name = (cf.name ?? '').toLowerCase();
        if (name.contains('year')) {
          if (cf.value != null && cf.value is List && cf.value!.isNotEmpty) {
            return cf.value!.first.toString();
          }
          if (cf.value != null) return cf.value.toString();
        }
      }
    }
    // Try regex match from title (e.g. "2020", "2022")
    final match = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(item.name ?? '');
    return match?.group(0);
  }

  String? _getItemMileage(ItemModel item) {
    if (item.customFields != null) {
      for (final cf in item.customFields!) {
        final name = (cf.name ?? '').toLowerCase();
        if (name.contains('kilometer') || name.contains('mileage') || name.contains('km')) {
          if (cf.value != null && cf.value is List && cf.value!.isNotEmpty) {
            final val = cf.value!.first.toString();
            return val.toLowerCase().contains('km') ? val : '$val km';
          }
          if (cf.value != null) {
            final val = cf.value.toString();
            return val.toLowerCase().contains('km') ? val : '$val km';
          }
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          // Scrollable Content
          RefreshIndicator(
            color: const Color(0xFF007AFF),
            onRefresh: _loadAllMotorsData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.only(bottom: 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroBannerWithSearch(context),
                  const SizedBox(height: 18),
                  _buildVehicleTypesSection(context),
                  const SizedBox(height: 22),
                  _buildPopularMakesSection(context),
                  const SizedBox(height: 24),
                  _buildRecommendedCarsSection(context),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Sticky Bottom Action Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildStickyBottomBar(context),
          ),
        ],
      ),
    );
  }

  /// 1. Top App Bar matching mockup
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Color(0xFF0F172A),
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.category?.name ?? 'Motors',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.favorite_border_rounded,
            color: Color(0xFF0F172A),
            size: 24,
          ),
          onPressed: () {
            Navigator.pushNamed(context, Routes.favoritesScreen);
          },
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: const Color(0xFFE2E8F0),
          height: 1,
        ),
      ),
    );
  }

  /// 2. Hero Car Banner with Stacked Overlapping Search Bar
  Widget _buildHeroBannerWithSearch(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    // motors_banner.png is 6840 x 3420 -> aspect ratio 2.0
    final double bannerHeight = screenWidth > 0 ? (screenWidth / 2.0) : 190.0;
    const double searchBarHeight = 50;
    const double overlap = 26;

    return SizedBox(
      height: bannerHeight + (searchBarHeight - overlap),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 2a. Hero Banner Image Card (Full width, top rounded corners only, matching design)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: bannerHeight,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Image.asset(
                'assets/motors_banner.png',
                width: double.infinity,
                height: bannerHeight,
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
                errorBuilder: (_, __, ___) => Image.network(
                  'https://images.unsplash.com/photo-1594502184342-2e12f877aa73?w=1200&q=80',
                  width: double.infinity,
                  height: bannerHeight,
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
          ),

          // 2b. White Shadow / Gradient along the bottom of the banner
          Positioned(
            left: 16,
            right: 16,
            bottom: searchBarHeight - overlap,
            height: 75,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.35),
                    Colors.white.withValues(alpha: 0.8),
                    Colors.white,
                  ],
                  stops: const [0.0, 0.4, 0.75, 1.0],
                ),
              ),
            ),
          ),

          // 2c. Overlapping Search Bar (Starts above the bottom of the banner)
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            height: searchBarHeight,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.85),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.only(left: 14, right: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF64748B),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _onSearchSubmit,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Search by make or model...',
                        hintStyle: TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.2,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  Material(
                    color: const Color(0xFF007AFF),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _onSearchSubmit(_searchController.text),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        child: Text(
                          'Search',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Vehicle Types Horizontal Selector (Cars, SUVs, Motorcycles, Commercial)
  Widget _buildVehicleTypesSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _defaultVehicleTypes.map((type) {
          final title = type['title'] as String;
          final isSelected = _selectedVehicleType != null && _selectedVehicleType!.toLowerCase() == title.toLowerCase();

          return Expanded(
            child: GestureDetector(
              onTap: () => _onVehicleTypeTap(title),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF007AFF) : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.6 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isSelected ? 0.04 : 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Vehicle Illustration
                    SizedBox(
                      height: 38,
                      width: 58,
                      child: _buildVehicleIllustration(title),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          title,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected ? const Color(0xFF007AFF) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVehicleIllustration(String title) {
    switch (title.toLowerCase()) {
      case 'cars':
        return Image.asset('assets/icons/cars.png', height: 38, width: 50, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.directions_car_rounded, color: Color(0xFF007AFF), size: 34));
      case 'suvs':
        return Image.asset('assets/icons/suvs.png', height: 38, width: 50, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.airport_shuttle_rounded, color: Color(0xFF0284C7), size: 34));
      case 'motorcycles':
        return Image.asset('assets/icons/motorcycles.png', height: 38, width: 50, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.two_wheeler_rounded, color: Color(0xFF2563EB), size: 34));
      case 'commercial':
        return Image.asset('assets/icons/commercial.png', height: 38, width: 50, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.local_shipping_rounded, color: Color(0xFF475569), size: 34));
      default:
        return const Icon(
          Icons.directions_car_rounded,
          color: Color(0xFF007AFF),
          size: 34,
        );
    }
  }

  /// 4. Popular Makes Section with Brand Logos & "View all"
  Widget _buildPopularMakesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Popular makes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _openAllMakesSheet,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Horizontal scrolling brands carousel with shimmer support
        if (_isLoading)
          _buildPopularMakesShimmer()
        else
          SizedBox(
            height: 94,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _carMakes.length.clamp(0, 10),
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final make = _carMakes[index];
                return _buildMakeCard(make);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildPopularMakesShimmer() {
    return SizedBox(
      height: 94,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          return const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomShimmer(
                width: 62,
                height: 62,
                borderRadius: 18,
              ),
              SizedBox(height: 6),
              CustomShimmer(
                width: 50,
                height: 11,
                borderRadius: 4,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMakeCard(CarMake make) {
    return GestureDetector(
      onTap: () => _onMakeTap(make),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(10),
            child: Center(
              child: _buildMakeLogo(make),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 68,
            child: Text(
              make.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMakeLogo(CarMake make) {
    final name = make.name.toLowerCase();

    // 1. If network logo is available, render with Image.network
    if (make.image != null && make.image!.trim().isNotEmpty && make.image != 'null') {
      return Image.network(
        make.image!,
        width: 38,
        height: 38,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildFallbackVectorLogo(make, name),
      );
    }

    return _buildFallbackVectorLogo(make, name);
  }

  Widget _buildFallbackVectorLogo(CarMake make, String name) {
    if (name.contains('toyota')) {
      return _buildToyotaLogo();
    } else if (name.contains('mercedes') || name.contains('marcedes')) {
      return _buildMercedesLogo();
    } else if (name.contains('bmw')) {
      return _buildBmwLogo();
    } else if (name.contains('hyundai')) {
      return _buildHyundaiLogo();
    } else if (name.contains('kia')) {
      return _buildKiaLogo();
    } else if (name.contains('nissan')) {
      return _buildNissanLogo();
    } else if (name.contains('volkswagen')) {
      return _buildVolkswagenLogo();
    } else if (name.contains('lexus')) {
      return _buildLexusLogo();
    }

    // Fallback Initial Badge
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          make.name.isNotEmpty ? make.name[0].toUpperCase() : 'C',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF007AFF),
          ),
        ),
      ),
    );
  }

  Widget _buildNissanLogo() {
    return SvgPicture.string(
      '''<svg viewBox="0 0 100 80" xmlns="http://www.w3.org/2000/svg">
        <circle cx="50" cy="40" r="32" fill="none" stroke="#475569" stroke-width="6"/>
        <rect x="10" y="32" width="80" height="16" rx="3" fill="#475569"/>
      </svg>''',
    );
  }

  Widget _buildVolkswagenLogo() {
    return SvgPicture.string(
      '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
        <circle cx="50" cy="50" r="44" fill="none" stroke="#003468" stroke-width="6"/>
        <path d="M30,30 L44,70 M70,30 L56,70 M40,50 L50,30 L60,50" fill="none" stroke="#003468" stroke-width="5" stroke-linecap="round"/>
      </svg>''',
    );
  }

  Widget _buildLexusLogo() {
    return SvgPicture.string(
      '''<svg viewBox="0 0 100 80" xmlns="http://www.w3.org/2000/svg">
        <ellipse cx="50" cy="40" rx="44" ry="32" fill="none" stroke="#334155" stroke-width="6"/>
        <path d="M34,26 L34,54 L66,54" fill="none" stroke="#334155" stroke-width="7" stroke-linecap="round"/>
      </svg>''',
    );
  }

  Widget _buildToyotaLogo() {
    return SvgPicture.string(
      '''<svg viewBox="0 0 100 80" xmlns="http://www.w3.org/2000/svg">
        <ellipse cx="50" cy="40" rx="46" ry="34" fill="none" stroke="#334155" stroke-width="7"/>
        <ellipse cx="50" cy="30" rx="28" ry="14" fill="none" stroke="#334155" stroke-width="6"/>
        <ellipse cx="50" cy="40" rx="14" ry="24" fill="none" stroke="#334155" stroke-width="6"/>
      </svg>''',
    );
  }

  Widget _buildMercedesLogo() {
    return SvgPicture.string(
      '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
        <circle cx="50" cy="50" r="44" fill="none" stroke="#334155" stroke-width="6"/>
        <polygon points="50,12 56,48 50,44 44,48" fill="#334155"/>
        <polygon points="18,68 46,46 50,50 48,56" fill="#334155"/>
        <polygon points="82,68 52,56 50,50 54,46" fill="#334155"/>
      </svg>''',
    );
  }

  Widget _buildBmwLogo() {
    return SvgPicture.string(
      '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
        <circle cx="50" cy="50" r="46" fill="#1E293B"/>
        <circle cx="50" cy="50" r="30" fill="white"/>
        <path d="M50,20 A30,30 0 0,1 80,50 L50,50 Z" fill="#007AFF"/>
        <path d="M50,50 L20,50 A30,30 0 0,1 50,80 Z" fill="#007AFF"/>
      </svg>''',
    );
  }

  Widget _buildHyundaiLogo() {
    return SvgPicture.string(
      '''<svg viewBox="0 0 100 70" xmlns="http://www.w3.org/2000/svg">
        <ellipse cx="50" cy="35" rx="46" ry="30" fill="none" stroke="#003468" stroke-width="6" transform="rotate(-5 50 35)"/>
        <path d="M34,16 L38,54 M62,16 L66,54 M36,35 L64,35" stroke="#003468" stroke-width="7" stroke-linecap="round"/>
      </svg>''',
    );
  }

  Widget _buildKiaLogo() {
    return const Center(
      child: Text(
        'KIA',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }

  /// 5. Recommended Cars Section Header & 2-Column Grid
  Widget _buildRecommendedCarsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header with Sort button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recommended cars',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _openSortSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swap_vert_rounded,
                        size: 16,
                        color: Color(0xFF007AFF),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Sort',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Grid of Cars with shimmer loading support
        if (_isLoading)
          _buildRecommendedCarsShimmer()
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recommendedCars.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.66,
                crossAxisSpacing: 12,
                mainAxisSpacing: 14,
              ),
              itemBuilder: (context, index) {
                final car = _recommendedCars[index];
                return _buildCarCard(context, car);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildRecommendedCarsShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.66,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
        ),
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomShimmer(
                  height: 128,
                  width: double.infinity,
                  borderRadius: 17,
                ),
                Padding(
                  padding: EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomShimmer(width: 90, height: 16, borderRadius: 4),
                      SizedBox(height: 6),
                      CustomShimmer(width: 120, height: 12, borderRadius: 4),
                      SizedBox(height: 8),
                      CustomShimmer(width: 80, height: 10, borderRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCarCard(BuildContext context, ItemModel car) {
    final bool isPromoted = car.isFeature == true;
    final year = _getItemYear(car) ?? '2022';
    final mileage = _getItemMileage(car) ?? '28 000 km';
    final location = car.city?.isNotEmpty == true
        ? car.city!
        : (car.address?.isNotEmpty == true ? car.address! : 'Dushanbe');

    final imageSrc = car.image?.isNotEmpty == true
        ? car.image!
        : (car.galleryImages?.isNotEmpty == true ? car.galleryImages!.first.image ?? '' : '');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.pushNamed(
              context,
              Routes.adDetailsScreen,
              arguments: {'model': car},
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Stack with Promoted Tag and Favorite Button
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                    child: SizedBox(
                      height: 128,
                      width: double.infinity,
                      child: imageSrc.isNotEmpty
                          ? UiUtils.imageType(imageSrc, fit: BoxFit.cover)
                          : Container(
                              color: const Color(0xFFF1F5F9),
                              child: const Icon(
                                Icons.directions_car_rounded,
                                size: 38,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                    ),
                  ),

                  // "Promoted" Tag
                  if (isPromoted)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9500),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Text(
                          'Promoted',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),

                  // Favorite Button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _buildFavoriteButton(context, car),
                  ),
                ],
              ),

              // Card Details
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Price
                    Text(
                      _formatPrice(car.price),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF007AFF),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),

                    // Car Title
                    Text(
                      car.name ?? 'Car Listing',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 7),

                    // Location Chip
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 13,
                          color: Color(0xFF007AFF),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Year & Mileage Chips
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          year,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.speed_rounded,
                          size: 13,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            mileage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
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

  Widget _buildFavoriteButton(BuildContext context, ItemModel car) {
    if (car.id == null) return const SizedBox.shrink();

    return BlocProvider(
      create: (context) => UpdateFavoriteCubit(FavoriteRepository()),
      child: BlocBuilder<FavoriteCubit, FavoriteState>(
        builder: (context, favState) {
          final isLike = context.read<FavoriteCubit>().isItemFavorite(car.id!);

          return Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  UiUtils.checkUser(
                    context: context,
                    onNotGuest: () {
                      if (isLike) {
                        context.read<UpdateFavoriteCubit>().setFavoriteItem(
                              item: car,
                              type: 0,
                            );
                        context.read<FavoriteCubit>().removeFavoriteItem(car);
                      } else {
                        context.read<UpdateFavoriteCubit>().setFavoriteItem(
                              item: car,
                              type: 1,
                            );
                        context.read<FavoriteCubit>().addFavoriteitem(car);
                      }
                    },
                  );
                },
                child: Center(
                  child: Icon(
                    isLike ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 18,
                    color: isLike ? const Color(0xFFEF4444) : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 6. Sticky Bottom Action Bar with Filters & All cars (12 845) >
  Widget _buildStickyBottomBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          // Filters Button (Left)
          Expanded(
            flex: 2,
            child: Material(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _openFilters,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFBFDBFE),
                      width: 1.2,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        color: Color(0xFF007AFF),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // All cars (12 845) > Button (Right)
          Expanded(
            flex: 3,
            child: Material(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _openAllCars,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFBFDBFE),
                      width: 1.2,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'All cars (${_formatCount(_totalCarsCount)})',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF007AFF),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom Sheet for All Car Makes
  void _openAllMakesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredMakes = _carMakes.where((m) {
              return m.name.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return Material(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.75,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'All Car Makes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                onChanged: (val) {
                                  setSheetState(() => searchQuery = val);
                                },
                                decoration: const InputDecoration(
                                  hintText: 'Search car make...',
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(18),
                        itemCount: filteredMakes.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final make = filteredMakes[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            leading: SizedBox(
                              width: 36,
                              height: 36,
                              child: _buildMakeLogo(make),
                            ),
                            title: Text(
                              make.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF94A3B8),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _onMakeTap(make);
                            },
                          );
                        },
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

  /// Bottom Sheet for Sorting
  void _openSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sort Cars',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                _buildSortOption('Recommended', 'recommended'),
                _buildSortOption('Price: Low to High', 'price_low_to_high'),
                _buildSortOption('Price: High to Low', 'price_high_to_low'),
                _buildSortOption('Newest First', 'newly_added'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String label, String value) {
    final isSelected = _selectedSort == value;
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? const Color(0xFF007AFF) : const Color(0xFF334155),
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF007AFF))
          : null,
      onTap: () {
        Navigator.pop(context);
        setState(() {
          _selectedSort = value;
        });
        _loadAllMotorsData();
      },
    );
  }
}
