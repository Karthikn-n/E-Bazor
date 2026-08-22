import 'dart:async';

import 'package:Ebozor/data/cubits/location/fetch_areas_cubit.dart';
import 'package:Ebozor/data/model/location/areaModel.dart';
import 'package:Ebozor/ui/screens/location/location_map_screen.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_internet.dart';
import 'package:Ebozor/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:Ebozor/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AreasScreen extends StatefulWidget {
  final int cityId;
  final String cityName;
  final String countryName;
  final String stateName;
  final String from;
  final double latitude;
  final double longitude;

  const AreasScreen({
    super.key,
    required this.cityId,
    required this.cityName,
    required this.from,
    required this.countryName,
    required this.stateName,
    required this.latitude,
    required this.longitude,
  });

  static Route route(RouteSettings settings) {
    Map? arguments = settings.arguments as Map?;

    return BlurredRouter(
      builder: (context) => BlocProvider(
        create: (context) => FetchAreasCubit(),
        child: AreasScreen(
          cityId: arguments?['cityId'] ?? 0,
          cityName: arguments?['cityName'] ?? "",
          countryName: arguments?['countryName'] ?? "",
          stateName: arguments?['stateName'] ?? "",
          from: arguments?['from'] ?? "",
          latitude: (arguments?['latitude'] is num)
              ? (arguments?['latitude'] as num).toDouble()
              : 0.0,
          longitude: (arguments?['longitude'] is num)
              ? (arguments?['longitude'] as num).toDouble()
              : 0.0,
        ),
      ),
    );
  }

  @override
  AreasScreenState createState() => AreasScreenState();
}

class AreasScreenState extends State<AreasScreen> {
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  final ScrollController controller = ScrollController();
  Timer? _searchDelay;
  String previousSearchQuery = "";
  AreaModel? selectedArea;

  @override
  void initState() {
    super.initState();
    context.read<FetchAreasCubit>().fetchAreas(
          search: "",
          cityId: widget.cityId,
        );
    controller.addListener(_pageScrollListen);
  }

  @override
  void dispose() {
    _searchDelay?.cancel();
    searchController.dispose();
    searchFocusNode.dispose();
    controller.dispose();
    super.dispose();
  }

  void _pageScrollListen() {
    if (controller.isEndReached()) {
      if (context.read<FetchAreasCubit>().hasMoreData()) {
        context.read<FetchAreasCubit>().fetchAreasMore(
              cityId: widget.cityId,
            );
      }
    }
  }

  void _onSearchChanged(String query) {
    _searchDelay?.cancel();
    _searchDelay = Timer(const Duration(milliseconds: 350), () {
      final trimmed = query.trim();
      if (previousSearchQuery != trimmed) {
        context.read<FetchAreasCubit>().fetchAreas(
              search: trimmed,
              cityId: widget.cityId,
            );
        previousSearchQuery = trimmed;
        setState(() {});
      }
    });
    setState(() {});
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: context.color.secondaryColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0.5,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: context.color.textDefaultColor,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.cityName.isNotEmpty ? widget.cityName : "Select Area".translate(context),
        style: TextStyle(
          color: context.color.textDefaultColor,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: context.color.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.color.borderColor.withValues(alpha: 0.6),
              ),
            ),
            child: TextField(
              controller: searchController,
              focusNode: searchFocusNode,
              onChanged: _onSearchChanged,
              style: TextStyle(
                color: context.color.textDefaultColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: "Search area...".translate(context),
                hintStyle: TextStyle(
                  color: context.color.textLightColor,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: context.color.territoryColor,
                  size: 20,
                ),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: context.color.textLightColor,
                          size: 18,
                        ),
                        onPressed: () {
                          searchController.clear();
                          _onSearchChanged("");
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 10,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.color.borderColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: const [
            CustomShimmer(height: 14, width: 130),
            Spacer(),
            CustomShimmer(height: 14, width: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return BlocBuilder<FetchAreasCubit, FetchAreasState>(
      builder: (context, state) {
        if (state is FetchAreasInProgress) {
          return _buildShimmer();
        }

        if (state is FetchAreasFailure) {
          if (state.errorMessage.contains("no-internet")) {
            return NoInternet(
              onRetry: () {
                context.read<FetchAreasCubit>().fetchAreas(
                      search: searchController.text,
                      cityId: widget.cityId,
                    );
              },
            );
          }
          return const Center(child: SomethingWentWrong());
        }

        if (state is FetchAreasSuccess) {
          if (state.areasModel.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.near_me_disabled_rounded,
                      size: 54,
                      color: context.color.textLightColor.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "No areas found".translate(context),
                      style: TextStyle(
                        color: context.color.textDefaultColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (scrollInfo.metrics.pixels >=
                  scrollInfo.metrics.maxScrollExtent - 50) {
                if (context.read<FetchAreasCubit>().hasMoreData()) {
                  context.read<FetchAreasCubit>().fetchAreasMore(
                        cityId: widget.cityId,
                      );
                }
              }
              return false;
            },
            child: SingleChildScrollView(
              controller: controller,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.pin_drop_rounded,
                        size: 16,
                        color: context.color.territoryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "All Areas".translate(context),
                        style: TextStyle(
                          color: context.color.textDefaultColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "(${state.areasModel.length})",
                        style: TextStyle(
                          color: context.color.textLightColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: state.areasModel.map((area) {
                      final isSelected = selectedArea?.id == area.id;
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() {
                            selectedArea = area;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? context.color.territoryColor.withValues(alpha: 0.12)
                                : context.color.secondaryColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? context.color.territoryColor
                                  : context.color.borderColor.withValues(alpha: 0.6),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                area.name ?? "",
                                style: TextStyle(
                                  color: isSelected
                                      ? context.color.territoryColor
                                      : context.color.textDefaultColor,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 16,
                                  color: context.color.territoryColor,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                if (state.isLoadingMore)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: UiUtils.progress(
                        normalProgressColor: context.color.territoryColor,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: UiUtils.buildButton(
          context,
          onPressed: () {
            if (selectedArea != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LocationMapScreen(),
                  settings: RouteSettings(
                    arguments: {
                      'area_id': selectedArea!.id,
                      'area': selectedArea!.name,
                      'city': widget.cityName,
                      'state': widget.stateName,
                      'country': widget.countryName,
                      'latitude': widget.latitude,
                      'longitude': widget.longitude,
                      'from': widget.from,
                    },
                  ),
                ),
              ).then((value) {
                if (value != null && widget.from == "addItem") {
                  Navigator.pop(context, value);
                }
              });
            }
          },
          buttonTitle: "Continue".translate(context),
          textColor: Colors.white,
          buttonColor: selectedArea != null
              ? context.color.territoryColor
              : context.color.territoryColor.withValues(alpha: 0.4),
          radius: 10,
          height: 48,
          disabled: selectedArea == null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }
}
