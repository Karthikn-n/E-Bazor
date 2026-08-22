import 'dart:async';

import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/location/fetch_states_cubit.dart';
import 'package:Ebozor/data/model/location/statesModel.dart';
import 'package:Ebozor/ui/screens/location/location_map_screen.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_internet.dart';
import 'package:Ebozor/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:Ebozor/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class StatesScreen extends StatefulWidget {
  final int countryId;
  final String countryName;
  final String from;

  const StatesScreen({
    super.key,
    required this.countryId,
    required this.countryName,
    required this.from,
  });

  static Route route(RouteSettings settings) {
    Map? arguments = settings.arguments as Map?;

    int cId = 0;
    if (arguments?['countryId'] is int) {
      cId = arguments!['countryId'];
    } else if (arguments?['countryId'] != null) {
      cId = int.tryParse(arguments!['countryId'].toString()) ?? 0;
    }

    return BlurredRouter(
      builder: (context) => BlocProvider(
        create: (context) => FetchStatesCubit(),
        child: StatesScreen(
          countryId: cId,
          countryName: arguments?['countryName']?.toString() ?? "",
          from: arguments?['from']?.toString() ?? "",
        ),
      ),
    );
  }

  @override
  StatesScreenState createState() => StatesScreenState();
}

class StatesScreenState extends State<StatesScreen> {
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  final ScrollController controller = ScrollController();
  Timer? _searchDelay;
  String previousSearchQuery = "";
  StatesModel? selectedState;
  String? manualStateName;

  @override
  void initState() {
    super.initState();
    if (widget.countryId > 0) {
      context.read<FetchStatesCubit>().fetchStates(
            search: "",
            countryId: widget.countryId,
          );
    }
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
      _loadMoreStates();
    }
  }

  void _loadMoreStates() {
    if (widget.countryId > 0 && context.read<FetchStatesCubit>().hasMoreData()) {
      context.read<FetchStatesCubit>().fetchStatesMore(
            countryId: widget.countryId,
            search: searchController.text.trim(),
          );
    }
  }

  void _onSearchChanged(String query) {
    _searchDelay?.cancel();
    _searchDelay = Timer(const Duration(milliseconds: 350), () {
      final trimmed = query.trim();
      if (previousSearchQuery != trimmed) {
        if (widget.countryId > 0) {
          context.read<FetchStatesCubit>().fetchStates(
                search: trimmed,
                countryId: widget.countryId,
              );
        }
        previousSearchQuery = trimmed;
        setState(() {});
      }
    });
    setState(() {});
  }

  String get effectiveStateName {
    if (selectedState != null) return selectedState!.name ?? "";
    if (manualStateName != null && manualStateName!.trim().isNotEmpty) {
      return manualStateName!.trim();
    }
    if (searchController.text.trim().isNotEmpty) {
      return searchController.text.trim();
    }
    return widget.countryName;
  }

  void _openMapForLocation() {
    final stateName = effectiveStateName;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationMapScreen(),
        settings: RouteSettings(
          arguments: {
            'area_id': null,
            'area': null,
            'city': stateName,
            'state': stateName,
            'country': widget.countryName,
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

  void _applyStateDirectly() {
    final stateName = effectiveStateName;

    if (widget.from == "addItem") {
      Navigator.pop(context, {
        "area_id": null,
        "area": null,
        "city": stateName,
        "state": stateName,
        "country": widget.countryName,
      });
    } else {
      HiveUtils.setLocation(
        city: stateName,
        state: stateName,
        country: widget.countryName,
        area: null,
      );

      Navigator.pushNamedAndRemoveUntil(
        context,
        Routes.main,
        (route) => false,
        arguments: {"from": "login"},
      );
    }
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
        widget.countryName.isNotEmpty ? widget.countryName : "Select State".translate(context),
        style: TextStyle(
          color: context.color.textDefaultColor,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(
            Icons.map_rounded,
            color: context.color.territoryColor,
            size: 22,
          ),
          tooltip: "Pick on Map".translate(context),
          onPressed: _openMapForLocation,
        ),
        const SizedBox(width: 4),
      ],
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
              textInputAction: TextInputAction.search,
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  setState(() {
                    manualStateName = val.trim();
                    selectedState = null;
                  });
                }
              },
              style: TextStyle(
                color: context.color.textDefaultColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: "Search or enter state/region...".translate(context),
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
                          setState(() {
                            manualStateName = null;
                          });
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
    final searchText = searchController.text.trim();

    return BlocBuilder<FetchStatesCubit, FetchStatesState>(
      builder: (context, state) {
        if (state is FetchStatesInProgress) {
          return _buildShimmer();
        }

        if (state is FetchStatesFailure) {
          if (state.errorMessage.contains("no-internet")) {
            return NoInternet(
              onRetry: () {
                context.read<FetchStatesCubit>().fetchStates(
                      search: searchController.text,
                      countryId: widget.countryId,
                    );
              },
            );
          }
          return const Center(child: SomethingWentWrong());
        }

        List<StatesModel> states = [];
        bool isLoadingMore = false;

        if (state is FetchStatesSuccess) {
          states = state.statesModel;
          isLoadingMore = state.isLoadingMore;
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            if (scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 50) {
              _loadMoreStates();
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
                // 1. Quick Select: Entire Country / Custom State
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() {
                            selectedState = null;
                            manualStateName = widget.countryName;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: (selectedState == null &&
                                    (manualStateName == widget.countryName ||
                                        (manualStateName == null &&
                                            searchText.isEmpty)))
                                ? context.color.territoryColor.withValues(alpha: 0.12)
                                : context.color.secondaryColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (selectedState == null &&
                                      (manualStateName == widget.countryName ||
                                          (manualStateName == null &&
                                              searchText.isEmpty)))
                                  ? context.color.territoryColor
                                  : context.color.borderColor.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.public_rounded,
                                size: 18,
                                color: context.color.territoryColor,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "All of ${widget.countryName}",
                                  style: TextStyle(
                                    color: context.color.textDefaultColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (selectedState == null &&
                                  (manualStateName == widget.countryName ||
                                      (manualStateName == null &&
                                          searchText.isEmpty)))
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 18,
                                  color: context.color.territoryColor,
                                ),
                            ],
                          ),
                        ),
                      ),

                      if (searchText.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() {
                              selectedState = null;
                              manualStateName = searchText;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: (manualStateName == searchText)
                                  ? context.color.territoryColor.withValues(alpha: 0.12)
                                  : context.color.secondaryColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (manualStateName == searchText)
                                    ? context.color.territoryColor
                                    : context.color.borderColor.withValues(alpha: 0.6),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.add_location_alt_rounded,
                                  size: 18,
                                  color: context.color.territoryColor,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Use \"$searchText\" as State/Region",
                                    style: TextStyle(
                                      color: context.color.textDefaultColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                if (manualStateName == searchText)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 18,
                                    color: context.color.territoryColor,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // 2. States List from API
                if (states.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.map_rounded,
                          size: 16,
                          color: context.color.territoryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Available States".translate(context),
                          style: TextStyle(
                            color: context.color.textDefaultColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "(${states.length})",
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
                      children: states.map((stateItem) {
                        final isSelected = selectedState?.id == stateItem.id;
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() {
                              selectedState = stateItem;
                              manualStateName = null;
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
                                  stateItem.name ?? "",
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
                ],

                if (isLoadingMore)
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
      },
    );
  }

  Widget _buildBottomBar() {
    final stateName = effectiveStateName;

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
        child: Row(
          children: [
            // Continue to Cities
            Expanded(
              child: UiUtils.buildButton(
                context,
                onPressed: () {
                  if (selectedState != null) {
                    Navigator.pushNamed(
                      context,
                      Routes.citiesScreen,
                      arguments: {
                        "stateId": selectedState!.id!,
                        "stateName": selectedState!.name!,
                        "from": widget.from,
                        "countryName": widget.countryName,
                        "countryId": widget.countryId,
                      },
                    ).then((value) {
                      if (value != null && widget.from == "addItem") {
                        Navigator.pop(context, value);
                      }
                    });
                  } else {
                    _applyStateDirectly();
                  }
                },
                buttonTitle: selectedState != null
                    ? "Next (Cities)"
                    : "Apply $stateName",
                textColor: Colors.white,
                buttonColor: context.color.territoryColor,
                radius: 10,
                height: 48,
              ),
            ),
          ],
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