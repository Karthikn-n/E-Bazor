import 'package:Ebozor/data/cubits/category/subcategory_filters_cubit.dart';
import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/data/repositories/category_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';



class FiltersPage extends StatefulWidget {
  final CategoryModel category;

  const FiltersPage({super.key, required this.category});



    static Route route(RouteSettings settings) {
      final category = settings.arguments as CategoryModel;

      return MaterialPageRoute(
        builder: (context) => BlocProvider(
          create: (context) => FilterCubit(
            FilterRepository(), // 👈 இங்க தான் fix
          ),
          child: FiltersPage(category: category),
        ),
      );
    }

  @override

  State<FiltersPage> createState() => _FiltersPageState();
}

class _FiltersPageState extends State<FiltersPage> {
  late FilterCubit cubit;
  String selectedSlug = "residential";
  // Tab
  int _selectedTab = 0; // 0=Rent, 1=Buy, 2=Off-Plan

  // Property Type
  int _selectedPropertyType = 0; // 0=Residential, 1=Commercial, 2=Rooms, 3=Hotel Apt, 4=Land

  // Residential Categories
  int _selectedCategory = 0; // 0=All Residential, 1=Apartment, 2=Villa, ...

  // Price Range
  final TextEditingController _priceMinController = TextEditingController(text: '0');
  final TextEditingController _priceMaxController = TextEditingController(text: '');
  RangeValues _priceRange = const RangeValues(0, 1);

  // Bedrooms - multi select
  final Set<String> _selectedBedrooms = {};

  // Bathrooms - multi select
  final Set<String> _selectedBathrooms = {};

  // Area/Size
  final TextEditingController _areaMinController = TextEditingController(text: '0');
  final TextEditingController _areaMaxController = TextEditingController(text: '');
  RangeValues _areaRange = const RangeValues(0, 1);

  // Furnishing Type
  int _selectedFurnishing = 0; // 0=All, 1=Furnished, 2=Unfurnished

  // Amenities - multi select
  final Set<String> _selectedAmenities = {};

  // Listed By - multi select
  final Set<String> _selectedListedBy = {};

  // Rent is Paid - multi select
  final Set<String> _selectedRentPaid = {};

  // More Filters - multi select
  final Set<String> _selectedMoreFilters = {};

  // Text controllers
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _excludeLocationController = TextEditingController();
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _agencyController = TextEditingController();

  static const Color _redColor = Color(0xFFE02020);
  static const Color _borderColor = Color(0xFFDDDDDD);
  static const Color _greyText = Color(0xFF888888);
  @override
  void initState() {
    super.initState();

    cubit = context.read<FilterCubit>();

    final initialSlug = widget.category.children?.first.slug ?? "residential";

    selectedSlug = initialSlug;

    cubit.fetchFilters(initialSlug);
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildAppBar(),
          _buildTabBar(),
          // Expanded(
          //   child: SingleChildScrollView(
          //     padding: const EdgeInsets.symmetric(horizontal: 16),
          //     child: Column(
          //       crossAxisAlignment: CrossAxisAlignment.start,
          //       children: [
          //         const SizedBox(height: 20),
          //         _buildLocationSection(),
          //         const SizedBox(height: 24),
          //         _buildPropertyTypeSection(),
          //         const SizedBox(height: 24),
          //         _buildResidentialCategoriesSection(),
          //         const SizedBox(height: 24),
          //         _buildPriceRangeSection(),
          //         const SizedBox(height: 24),
          //         _buildBedroomsSection(),
          //         const SizedBox(height: 24),
          //         _buildBathroomsSection(),
          //         const SizedBox(height: 24),
          //         _buildAreaSizeSection(),
          //         const SizedBox(height: 24),
          //         _buildFurnishingTypeSection(),
          //         const SizedBox(height: 24),
          //         _buildExcludeLocationsSection(),
          //         const SizedBox(height: 24),
          //         _buildAmenitiesSection(),
          //         const SizedBox(height: 24),
          //         _buildKeywordSection(),
          //         const SizedBox(height: 24),
          //         _buildListedBySection(),
          //         const SizedBox(height: 24),
          //         _buildRealEstateAgenciesSection(),
          //         const SizedBox(height: 24),
          //         _buildRentIsPaidSection(),
          //         const SizedBox(height: 24),
          //         _buildMoreFiltersSection(),
          //         const SizedBox(height: 24),
          //       ],
          //     ),
          //   ),
          // ),

          // Expanded(
          //   child: BlocBuilder<FilterCubit, FilterState>(
          //     builder: (context, state) {
          //
          //       if (state is FilterLoading) {
          //         return const Center(child: CircularProgressIndicator());
          //       }
          //
          //       if (state is FilterError) {
          //         return Center(child: Text(state.message));
          //       }
          //
          //       if (state is FilterLoaded) {
          //         final data = state.data;
          //
          //         final propertyTypes = widget.category.children ?? [];
          //
          //         // 👉 IMPORTANT: selected property
          //         final selectedProperty =
          //         (_selectedPropertyType < propertyTypes.length)
          //             ? propertyTypes[_selectedPropertyType]
          //             : null;
          //
          //         final categories = selectedProperty?.children ?? [];
          //
          //
          //         print("👉 propertyTypes length: ${propertyTypes.length}");
          //         print("👉 selectedPropertyType: $_selectedPropertyType");
          //
          //
          //
          //         print("👉 selectedProperty: $selectedProperty");
          //
          //
          //
          //         print("👉 categories length: ${categories.length}");
          //         print("👉 selectedCategory: $_selectedCategory");
          //
          //         return SingleChildScrollView(
          //           padding: const EdgeInsets.symmetric(horizontal: 16),
          //           child: Column(
          //             crossAxisAlignment: CrossAxisAlignment.start,
          //             children: [
          //
          //               const SizedBox(height: 20),
          //
          //               _buildPropertyTypeSection(propertyTypes),
          //
          //               const SizedBox(height: 24),
          //
          //               _buildResidentialCategoriesSection(categories),
          //
          //             ],
          //           ),
          //         );
          //       }
          //
          //       return const SizedBox();
          //     },
          //   ),
          // ),
// Replace the entire BlocBuilder Expanded section:

          Expanded(
            child: BlocBuilder<FilterCubit, FilterState>(
              builder: (context, state) {
                final propertyTypes = widget.category.children ?? [];

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // ✅ Static - Location
                      _buildLocationSection(),
                      const SizedBox(height: 24),

                      // ✅ Static - Property Type (from widget.category.children)
                      _buildPropertyTypeSection(propertyTypes),
                      const SizedBox(height: 24),

                      if (state is FilterLoading)
                        const Center(child: CircularProgressIndicator())

                      else if (state is FilterError)
                        Center(child: Text(state.message))

                      else if (state is FilterLoaded) ...[

                          // ✅ API - Categories chips
                          if (state.data.children.isNotEmpty) ...[
                            _buildResidentialCategoriesSection(
                              state.data.children,
                              state.data.name ?? 'Categories',
                            ),
                            const SizedBox(height: 24),
                          ],

                          // ✅ Static - Price Range
                          _buildPriceRangeSection(),
                          const SizedBox(height: 24),

                          // ✅ API - Dynamic filters (Bedrooms, Bathrooms, Furnishing, etc.)
                          ...state.data.filters
                              .map((filter) => _buildDynamicFilterSection(filter))
                    .where((widget) => widget is! SizedBox) // 👈 remove empty widgets
                    .expand((widget) => [
                widget,
                const SizedBox(height: 24),
                ]),


                          // ✅ Static - Exclude Locations
                          _buildExcludeLocationsSection(),
                          const SizedBox(height: 24),

                          // ✅ Static - Keyword
                          _buildKeywordSection(),
                          const SizedBox(height: 24),

                          // ✅ Static - Real Estate Agencies
                          _buildRealEstateAgenciesSection(),
                          const SizedBox(height: 24),

                          // ✅ Static - More Filters
                          _buildMoreFiltersSection(),
                          const SizedBox(height: 24),
                        ],
                    ],
                  ),
                );
              },
            ),
          ),
          // Expanded(
          //   child: BlocBuilder<FilterCubit, FilterState>(
          //     builder: (context, state) {
          //       final propertyTypes = widget.category.children ?? [];
          //
          //       return SingleChildScrollView(
          //         padding: const EdgeInsets.symmetric(horizontal: 16),
          //         child: Column(
          //           crossAxisAlignment: CrossAxisAlignment.start,
          //           children: [
          //             const SizedBox(height: 20),
          //                     _buildLocationSection(),
          //             const SizedBox(height: 24),
          //             // ✅ Property Type — always from widget.category.children
          //             _buildPropertyTypeSection(propertyTypes),
          //
          //             const SizedBox(height: 24),
          //
          //             // ✅ Below sections depend on API state
          //             if (state is FilterLoading)
          //               const Center(child: CircularProgressIndicator())
          //
          //             else if (state is FilterError)
          //               Center(child: Text(state.message))
          //
          //             else if (state is FilterLoaded) ...[
          //
          //                 // ✅ Categories — from API response (state.data.children)
          //                 if (state.data.children.isNotEmpty)
          //                   _buildResidentialCategoriesSection(
          //                     state.data.children,
          //                     state.data.name ?? 'Categories', // ✅ pass name here
          //                   ),
          //                 const SizedBox(height: 24),
          //                 //         _buildPriceRangeSection(),
          //                 // ✅ Dynamic filters — from API response (state.data.filters)
          //                 ...state.data.filters.map((filter) => Column(
          //                   children: [
          //                     _buildDynamicFilterSection(filter),
          //                     const SizedBox(height: 24),
          //                   ],
          //                 )),
          //               ],
          //           ],
          //         ),
          //       );
          //     },
          //   ),
          // ),
          _buildShowResultsButton(),
        ],
      ),
    );
  }
  Widget _buildDynamicFilterSection(FilterItem filter) {
    if (filter.values.isEmpty) return const SizedBox();

    // ✅ multi select chips (checkbox)
    if (filter.multiSelect) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(filter.name ?? ''),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: filter.values.map((val) {
              final isSelected = _selectedMoreFilters.contains(val);
              return _buildToggleChip(
                val,
                isSelected,
                    () => setState(() {
                  isSelected
                      ? _selectedMoreFilters.remove(val)
                      : _selectedMoreFilters.add(val);
                }),
              );
            }).toList(),
          ),
        ],
      );
    }

    // ✅ single select (radio)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(filter.name ?? ''),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filter.values.map((val) {
            final isSelected = _selectedMoreFilters.contains(val);
            return GestureDetector(
              onTap: () => setState(() {
                // clear all values of this filter first (single select)
                for (final v in filter.values) {
                  _selectedMoreFilters.remove(v);
                }
                _selectedMoreFilters.add(val);
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected ? Colors.black : _borderColor,
                    width: isSelected ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  val,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    color: isSelected ? Colors.black : _greyText,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
  Widget _buildAppBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                print("Filter screen close clicked");
                Navigator.pop(context);
              },
              child: const Icon(Icons.close, color: _redColor, size: 24),
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: () {},
              child: const Text(
                'Reset',
                style: TextStyle(
                  fontSize: 16,
                  color: _greyText,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = ['Rent', 'Buy', 'Off-Plan'];
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _borderColor, width: 1)),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isSelected = _selectedTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : const Color(0xFFEEEEEE),
                  border: isSelected
                      ? const Border(bottom: BorderSide(color: _redColor, width: 2))
                      : null,
                ),
                child: Center(
                  child: Text(
                    tabs[i],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isSelected ? Colors.black : _greyText,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Location'),
        _buildSearchField(_locationController, 'e.g. Dubai Marina'),
        const SizedBox(height: 8),
        const Text(
          'Select the cities, neighborhoods or buildings that you want to  search properties in.',
          style: TextStyle(fontSize: 13, color: _greyText, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildSearchField(TextEditingController controller, String hint) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _greyText, fontSize: 15),
          prefixIcon: const Icon(Icons.location_on_outlined, color: _greyText, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // Widget _buildPropertyTypeSection() {
  //   final subCategories = widget.category.children ?? [];
  //
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       _buildSectionTitle('Property Type'),
  //       SizedBox(
  //         height: 90,
  //         child: ListView.separated(
  //           scrollDirection: Axis.horizontal,
  //           itemCount: subCategories.length,
  //           separatorBuilder: (_, __) => const SizedBox(width: 10),
  //           itemBuilder: (context, i) {
  //             final item = subCategories[i];
  //             final isSelected = _selectedPropertyType == i;
  //
  //             return GestureDetector(
  //             //  onTap: () => setState(() => _selectedPropertyType = i),
  //               onTap: () {
  //                 setState(() {
  //                   _selectedPropertyType = i;
  //                 });
  //
  //                 final slug = widget.category.children![i].slug;
  //
  //                 setState(() {
  //                   selectedSlug = slug!;
  //                 });
  //
  //                 cubit.fetchFilters(slug!);
  //               },
  //               child: Container(
  //                 width: 100,
  //                 decoration: BoxDecoration(
  //                   border: Border.all(
  //                     color: isSelected ? Colors.black : _borderColor,
  //                     width: isSelected ? 1.5 : 1,
  //                   ),
  //                   borderRadius: BorderRadius.circular(8),
  //                 ),
  //                 child: Column(
  //                   mainAxisAlignment: MainAxisAlignment.center,
  //                   children: [
  //                     _buildCategoryImage(
  //                       item.url,   // 👈 API image
  //                       item.name,
  //                       isSelected,
  //                     ),
  //                     const SizedBox(height: 6),
  //                     Text(
  //                       item.name ?? '',
  //                       textAlign: TextAlign.center,
  //                       style: TextStyle(
  //                         fontSize: 12,
  //                         fontWeight:
  //                         isSelected ? FontWeight.w700 : FontWeight.w400,
  //                         color: isSelected ? Colors.black : _greyText,
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             );
  //           },
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildPropertyTypeSection(List propertyTypes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Property Type'),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: propertyTypes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {

              final item = propertyTypes[i];
              final isSelected = _selectedPropertyType == i;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPropertyType = i;
                    _selectedCategory = 0; // 🔥 reset category
                  });
                  final slug = item.slug;

                  if (slug != null && slug.isNotEmpty) {
                    cubit.fetchFilters(slug);
                  }
                },
                child: Container(
                  width: 100,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? Colors.black : _borderColor,
                      width: isSelected ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildCategoryImage(item.url, item.name, isSelected),
                      const SizedBox(height: 6),
                      Text(
                        item.name ?? '',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isSelected ? Colors.black : _greyText,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  IconData _getIcon(String? name) {
    switch (name?.toLowerCase()) {
      case 'residential':
        return Icons.home_outlined;
      case 'commercial':
        return Icons.business_outlined;
      case 'rooms for rent':
        return Icons.meeting_room_outlined;
      case 'monthly short term':
        return Icons.calendar_month;
      case 'daily short term':
        return Icons.today;
      default:
        return Icons.category;
    }
  }
  Widget _buildCategoryImage(String? image, String? name, bool isSelected) {
    if (image != null && image.isNotEmpty) {
      return Image.network(
        image,
        height: 30,
        width: 30,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            _getIcon(name),
            size: 26,
            color: isSelected ? Colors.black : _greyText,
          );
        },
      );
    } else {
      return Icon(
        _getIcon(name),
        size: 26,
        color: isSelected ? Colors.black : _greyText,
      );
    }
  }
  Widget _buildResidentialCategoriesSection(List categories, String title) {

    if (categories.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("${title} Categories"),

        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {

              final item = categories[i];
              final isSelected = _selectedCategory == i;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = i;
                  });

                  final slug = item.slug;
                  cubit.fetchFilters(slug);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? Colors.black : _borderColor,
                      width: isSelected ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    item.name ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: isSelected ? Colors.black : _greyText,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRangeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Price Range'),
        Row(
          children: [
            Expanded(child: _buildRangeInputField(_priceMinController, '0', 'AED')),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('to', style: TextStyle(fontSize: 15, color: Colors.black)),
            ),
            Expanded(child: _buildRangeInputField(_priceMaxController, 'Any', 'AED')),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            activeTrackColor: Colors.black,
            inactiveTrackColor: Colors.black,
            thumbColor: Colors.black,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
          ),
          child: RangeSlider(
            values: _priceRange,
            onChanged: (v) => setState(() => _priceRange = v),
          ),
        ),
      ],
    );
  }

  Widget _buildRangeInputField(TextEditingController controller, String hint, String suffix) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              controller.text.isEmpty ? hint : controller.text,
              style: TextStyle(
                fontSize: 15,
                color: controller.text.isEmpty ? _greyText : Colors.black,
              ),
            ),
          ),
          Text(suffix, style: const TextStyle(fontSize: 14, color: _greyText)),
        ],
      ),
    );
  }

  Widget _buildBedroomsSection() {
    final options = ['Studio', '1', '2', '3', '4', '5', '6', '7+'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Bedrooms'),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: options.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final isSelected = _selectedBedrooms.contains(options[i]);
              return _buildToggleChip(
                options[i],
                isSelected,
                    () => setState(() {
                  isSelected
                      ? _selectedBedrooms.remove(options[i])
                      : _selectedBedrooms.add(options[i]);
                }),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBathroomsSection() {
    final options = ['1', '2', '3', '4', '5', '6+'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Bathrooms'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = _selectedBathrooms.contains(opt);
            return _buildToggleChip(
              opt,
              isSelected,
                  () => setState(() {
                isSelected ? _selectedBathrooms.remove(opt) : _selectedBathrooms.add(opt);
              }),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildToggleChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.black : _borderColor,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            color: isSelected ? Colors.black : _greyText,
          ),
        ),
      ),
    );
  }

  Widget _buildAreaSizeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Area / Size'),
        Row(
          children: [
            Expanded(child: _buildAreaInputField('0', 'sqft')),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('to', style: TextStyle(fontSize: 15, color: Colors.black)),
            ),
            Expanded(child: _buildAreaInputField('Any', 'sqft')),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            activeTrackColor: Colors.black,
            inactiveTrackColor: Colors.black,
            thumbColor: Colors.black,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
          ),
          child: RangeSlider(
            values: _areaRange,
            onChanged: (v) => setState(() => _areaRange = v),
          ),
        ),
      ],
    );
  }

  Widget _buildAreaInputField(String value, String suffix) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                color: value == 'Any' || value == '0' ? _greyText : Colors.black,
              ),
            ),
          ),
          Text(suffix, style: const TextStyle(fontSize: 14, color: _greyText)),
        ],
      ),
    );
  }

  Widget _buildFurnishingTypeSection() {
    final options = ['All', 'Furnished', 'Unfurnished'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Furnishing Type'),
        Wrap(
          spacing: 8,
          children: List.generate(options.length, (i) {
            final isSelected = _selectedFurnishing == i;
            return GestureDetector(
              onTap: () => setState(() => _selectedFurnishing = i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected ? Colors.black : _borderColor,
                    width: isSelected ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  options[i],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    color: isSelected ? Colors.black : _greyText,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildExcludeLocationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Exclude locations'),
        _buildSearchField(_excludeLocationController, 'e.g. Dubai Marina'),
        const SizedBox(height: 8),
        const Text(
          'Select the locations or buildings that you want to exclude from your search.',
          style: TextStyle(fontSize: 13, color: _greyText, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildAmenitiesSection() {
    final amenities = ['Maids Room', 'Study', 'Central A/C', 'Balcony', 'Private Garden', 'Private Pool', 'Private Gym', 'Private Jacuzzi', 'Shared Pool', 'Shared Spa', 'Shared Gym'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Amenities'),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final isSelected = _selectedAmenities.contains(amenities[i]);
              return _buildToggleChip(
                amenities[i],
                isSelected,
                    () => setState(() {
                  isSelected
                      ? _selectedAmenities.remove(amenities[i])
                      : _selectedAmenities.add(amenities[i]);
                }),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () {},
          child: const Row(
            children: [
              Text(
                'View all',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Color(0xFF1565C0), size: 18),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKeywordSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Keyword'),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _keywordController,
            decoration: const InputDecoration(
              hintText: 'e.g. Pool, Security, Ref ID',
              hintStyle: TextStyle(color: _greyText, fontSize: 15),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListedBySection() {
    final options = ['Agency', 'Landlord', 'Developer'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Listed By'),
        Wrap(
          spacing: 8,
          children: options.map((opt) {
            final isSelected = _selectedListedBy.contains(opt);
            return _buildToggleChip(
              opt,
              isSelected,
                  () => setState(() {
                isSelected ? _selectedListedBy.remove(opt) : _selectedListedBy.add(opt);
              }),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRealEstateAgenciesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Real Estate Agencies'),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _agencyController,
            decoration: const InputDecoration(
              hintText: 'e.g. dubizzle Properties',
              hintStyle: TextStyle(color: _greyText, fontSize: 15),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRentIsPaidSection() {
    final options = ['Yearly', 'Bi-Yearly', 'Quarterly', 'Monthly'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Rent is Paid'),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: options.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final isSelected = _selectedRentPaid.contains(options[i]);
              return _buildToggleChip(
                options[i],
                isSelected,
                    () => setState(() {
                  isSelected
                      ? _selectedRentPaid.remove(options[i])
                      : _selectedRentPaid.add(options[i]);
                }),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMoreFiltersSection() {
    final filters = [
      {'icon': Icons.abc, 'label': 'Ads in\nEnglish'},
      {'icon': Icons.play_circle_outline, 'label': 'Ads with\nVideo'},
      {'icon': Icons.rotate_left, 'label': 'Ads with\n360 View'},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('More Filters'),
        Row(
          children: filters.map((f) {
            final label = f['label'] as String;
            final isSelected = _selectedMoreFilters.contains(label);
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  isSelected
                      ? _selectedMoreFilters.remove(label)
                      : _selectedMoreFilters.add(label);
                }),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? Colors.black : _borderColor,
                      width: isSelected ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        f['icon'] as IconData,
                        size: 28,
                        color: isSelected ? Colors.black : _greyText,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.black : _greyText,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildShowResultsButton() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: _redColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: const Text(
            'Show 216,176 Results',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}