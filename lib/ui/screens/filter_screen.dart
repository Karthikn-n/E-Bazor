// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/data/model/item_filter_model.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:Ebozor/data/cubits/custom_field/fetch_custom_fields_cubit.dart';


import 'package:Ebozor/utils/ApiService/api.dart';

import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart';
import 'package:Ebozor/ui/screens/widgets/dynamic_field/dynamic_field.dart';
import 'package:Ebozor/ui/screens/main_activity.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FilterScreen extends StatefulWidget {
  final Function update;
  final String from;
  final List<String>? categoryIds;
  final List<CategoryModel>? categoryList;

  const FilterScreen({
    super.key,
    required this.update,
    required this.from,
    this.categoryIds,
    this.categoryList,
  });

  @override
  FilterScreenState createState() => FilterScreenState();

  static Route route(RouteSettings routeSettings) {
    Map? arguments = routeSettings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => BlocProvider(
        create: (context) => FetchCustomFieldsCubit(),
        child: FilterScreen(
          update: arguments?['update'],
          from: arguments?['from'],
          categoryIds: arguments?['categoryIds'] ?? [],
          categoryList: arguments?['categoryList'] ?? [],
        ),
      ),
    );
  }
}

class FilterScreenState extends State<FilterScreen> {
  List<String> selectedCategories = [];

  TextEditingController minController =
      TextEditingController(text: Constant.itemFilter?.minPrice);
  TextEditingController maxController =
      TextEditingController(text: Constant.itemFilter?.maxPrice);

  // = 2; // 0: last_week   1: yesterday
  dynamic defaultCategoryID = currentVisitingCategoryId;
  dynamic defaultCategory = currentVisitingCategory;
  dynamic city = Constant.itemFilter?.city ?? "";
  dynamic area = Constant.itemFilter?.area ?? "";
  dynamic areaId = Constant.itemFilter?.areaId ?? null;
  dynamic radius = Constant.itemFilter?.radius ?? null;
  dynamic _state = Constant.itemFilter?.state ?? "";
  dynamic country = Constant.itemFilter?.country ?? "";
  dynamic latitude = Constant.itemFilter?.latitude ?? null;
  dynamic longitude = Constant.itemFilter?.longitude ?? null;
  List<CustomFieldBuilder> moreDetailDynamicFields = [];

  //String _selectedOption = "All Time";

  String postedOn =
      Constant.itemFilter?.postedSince ?? Constant.postedSince[0].value;

  late List<CategoryModel> categoryList = widget.categoryList ?? [];

  // Default max, can be adjusted
  RangeValues _priceRangeValues = const RangeValues(0, 1000000);

  bool get isJobs {
    if (widget.categoryIds != null) {
      if (widget.categoryIds!.contains("4") ||
          widget.categoryIds!.contains("356") ||
          widget.categoryIds!.contains("357")) {
        return true;
      }
    }
    if (selectedCategories.contains("4") ||
        selectedCategories.contains("356") ||
        selectedCategories.contains("357")) {
      return true;
    }
    if (categoryList.isNotEmpty) {
      for (var cat in categoryList) {
        final name = (cat.name ?? "").toLowerCase();
        final id = cat.id?.toString() ?? "";
        if (id == "4" ||
            id == "356" ||
            id == "357" ||
            name.contains("job") ||
            name.contains("recruit") ||
            name.contains("talent")) {
          return true;
        }
      }
    }
    return false;
  }

  bool get isProperty {
    if (isJobs) return false;
    if (categoryList.isNotEmpty) {
      for (var cat in categoryList) {
        if (cat.name != null &&
            (cat.name!.toLowerCase().contains("property") ||
                cat.name!.toLowerCase().contains("properties") ||
                cat.name!.toLowerCase().contains("real estate"))) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  void dispose() {
    minController.dispose();
    maxController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    setCategories();
    setDefaultVal(isRefresh: false);
    //clearFieldData();
    getCustomFieldsData();
    
         // Initialize slider values
    double min = double.tryParse(minController.text.replaceAll(',', '')) ?? 0;
    double max = double.tryParse(maxController.text.replaceAll(',', '')) ?? 1000000;
    if (max < min) max = min + 1000;
    _priceRangeValues = RangeValues(min, max);
  }


  void setCategories() {
    if (widget.categoryIds != null && widget.categoryIds!.isNotEmpty) {
      selectedCategories.addAll(widget.categoryIds!);
    }
    if (widget.categoryList != null && widget.categoryList!.isNotEmpty) {
      selectedCategories
          .addAll(widget.categoryList!.map((e) => e.id.toString()).toList());

      print("////////");
      print("categories id in filter:$selectedCategories");
      print("////////");
    }
  }

  void getCustomFieldsData() {
    if (Constant.itemFilter == null) {
      AbstractField.fieldsData.clear();
    }
    if (selectedCategories.isNotEmpty) {
      context.read<FetchCustomFieldsCubit>().fetchCustomFields(
            categoryIds: selectedCategories.join(','),
          );
    }
  }

  void setDefaultVal({bool isRefresh = true}) {
    if (isRefresh) {
      postedOn = Constant.postedSince[0].value;
      Constant.itemFilter = null;
      searchbody[Api.postedSince] = Constant.postedSince[0].value;

      selectedcategoryId = "0";
      city = "";
      areaId = null;
      radius = null;
      area = "";
      _state = "";
      country = "";
      latitude = null;
      longitude = null;
      selectedcategoryName = "";
      selectedCategory = defaultCategory;

      minController.clear();
      maxController.clear();
      widget.categoryList?.clear();
      selectedCategories.clear();
      moreDetailDynamicFields.clear();
      AbstractField.fieldsData.clear();
      AbstractField.files.clear();
      checkFilterValSet();
      setCategories();
      getCustomFieldsData();
    } else {
      city = HiveUtils.getCityName() ?? "";
      areaId = HiveUtils.getAreaId() != null
          ? int.parse(HiveUtils.getAreaId().toString())
          : null;
      area = HiveUtils.getAreaName() ?? "";
      _state = HiveUtils.getStateName() ?? "";
      country = HiveUtils.getCountryName() ?? "";
      latitude = HiveUtils.getLatitude() ?? null;
      longitude = HiveUtils.getLongitude() ?? null;
    }
  }

  bool checkFilterValSet() {
    if (postedOn != Constant.postedSince[0].value ||
        minController.text.trim().isNotEmpty ||
        maxController.text.trim().isNotEmpty ||
        selectedCategory != defaultCategory) {
            print("true");
      return true;
    }

            print("fase");
    return false;
  }

  void _onTapChooseLocation() async {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.pushNamed(context, Routes.countriesScreen,
        arguments: {"from": "filter"}).then((value) {
      if (value != null) {
        Map<String, dynamic> location = value as Map<String, dynamic>;

        setState(() {
          area = location["area"] ?? "";
          city = location["city"] ?? "";
          areaId = location["area_id"] ?? null;
          radius = location["radius"] ?? null;
          country = location["country"] ?? "";
          _state = location["state"] ?? "";
          latitude = location["latitude"] ?? null;
          longitude = location["longitude"] ?? null;
        });
      }
    });
/*    FocusManager.instance.primaryFocus?.unfocus();
    var result = await showModalBottomSheet(
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20), topRight: Radius.circular(20))),
      context: context,
      builder: (context) {
        return const ChooseLocatonBottomSheet();
      },
    );
    if (result != null) {
      GooglePlaceModel place = (result as GooglePlaceModel);

      city = place.city;
      country = place.country;
      _state = place.state;
      latitude = place.latitude;
      longitude = place.longitude;
    }*/
  }

  Map<String, dynamic> convertToCustomFields(Map<dynamic, dynamic> fieldsData) {
    return fieldsData.map((key, value) {
      return MapEntry('custom_fields[$key]', value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result)  {
        checkFilterValSet();
        return;
      },
      child: Scaffold(
        backgroundColor: context.color.backgroundColor,
        appBar: UiUtils.buildAppBar(
          context,
          onBackPress: () {
            checkFilterValSet();
            Navigator.pop(context);
          },
          showBackButton: true,
          title: "filterTitle".translate(context),
          actions: [
            TextButton(
              onPressed: () {
                setDefaultVal(isRefresh: true);
                setState(() {});
              },
              child: Text(
                "reset".translate(context),
                style: TextStyle(
                  color: context.color.territoryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        bottomNavigationBar: Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 12,
          ),
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            border: Border(
              top: BorderSide(
                color: context.color.borderColor.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                      color: context.color.borderColor.withValues(alpha: 0.8),
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    setDefaultVal(isRefresh: true);
                    setState(() {});
                  },
                  child: Text(
                    "reset".translate(context),
                    style: TextStyle(
                      color: context.color.textDefaultColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.color.territoryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Map<String, dynamic> customFields =
                        convertToCustomFields(AbstractField.fieldsData);
                    final appliedFilter = ItemFilterModel(
                      maxPrice: maxController.text,
                      minPrice: minController.text,
                      categoryId: selectedCategories.isNotEmpty
                          ? selectedCategories.last
                          : "",
                      postedSince: postedOn,
                      city: city,
                      areaId: areaId,
                      radius: radius,
                      state: _state,
                      country: country,
                      latitude: latitude,
                      longitude: longitude,
                      customFields: customFields,
                    );
                    Constant.itemFilter = appliedFilter;
                    widget.update(appliedFilter);
                    Navigator.pop(context, true);
                  },
                  child: Text(
                    "applyFilter".translate(context),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        body: isProperty ? propertyFilterBody() : SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Padding(
            padding: const EdgeInsets.all(
              20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              //mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Text('locationLbl'.translate(context))
                    .bold(weight: FontWeight.w600)
                    .color(context.color.textDefaultColor),
                const SizedBox(height: 5),
                locationWidget(context),
                if (widget.categoryIds == null ||
                    widget.categoryIds!.isEmpty) ...[
                  const SizedBox(height: 15),
                  Text('category'.translate(context))
                      .bold(weight: FontWeight.w600)
                      .color(context.color.textDefaultColor),
                  const SizedBox(height: 5),
                  categoryWidget(context),
                  const SizedBox(height: 5),
                ],
                //categoryModule(),
                const SizedBox(
                  height: 15,
                ),
                Text(isJobs
                        ? "Expected Monthly Salary (AED)"
                        : 'budgetLbl'.translate(context))
                    .bold(weight: FontWeight.w600)
                    .color(context.color.textDefaultColor),
                const SizedBox(height: 15),
                budgetOption(),
                const SizedBox(height: 15),
                Text('postedSinceLbl'.translate(context))
                    .bold(weight: FontWeight.w600)
                    .color(context.color.textDefaultColor),
                const SizedBox(height: 5),
                postedSinceOption(context),
                const SizedBox(height: 15),
                customFields()
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget propertyFilterBody() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('locationLbl'.translate(context))
                .bold(weight: FontWeight.w600)
                .color(context.color.textDefaultColor),
            const SizedBox(height: 10),
            locationWidgetProperty(context),
            const SizedBox(height: 20),
            
            Text('Price Range')
                .bold(weight: FontWeight.w600)
                .color(context.color.textDefaultColor),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: minMaxTFFProperty("minLbl".translate(context))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text("To").color(context.color.textDefaultColor),
                ),
                Expanded(child: minMaxTFFProperty("maxLbl".translate(context))),
              ],
            ),
             const SizedBox(height: 10),
            RangeSlider(
              values: _priceRangeValues,
              min: 0,
              max: 1000000, 
              activeColor: Color(0xFFE52D2D),
              inactiveColor: Color(0xFFE52D2D).withValues(alpha: 0.2),
              onChanged: (RangeValues values) {
                setState(() {
                  _priceRangeValues = values;
                  minController.text = values.start.round().toString();
                  maxController.text = values.end.round().toString();
                });
              },
            ),

            const SizedBox(height: 20),
            
            Text('postedSinceLbl'.translate(context))
                .bold(weight: FontWeight.w600)
                .color(context.color.textDefaultColor),
            const SizedBox(height: 10),
            postedSinceOptionProperty(context),
          ],
        ),
      ),
    );
  }

  Widget locationWidgetProperty(BuildContext context) {
    return InkWell(
      onTap: () {
        _onTapChooseLocation();
      },
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on_outlined, color: Colors.grey),
            const SizedBox(width: 10),
            Expanded(
              child: [area, city, _state, country]
                      .where((element) => element != null && element.isNotEmpty)
                      .join(", ")
                      .isNotEmpty
                  ? Text(
                      [area, city, _state, country]
                          .where((element) =>
                              element != null && element.isNotEmpty)
                          .join(", "),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade600),
                    )
                  : Text("allCities".translate(context))
                      .color(Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  Widget minMaxTFFProperty(String minMax) {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      alignment: Alignment.center,
      child: TextFormField(
        controller: (minMax == "minLbl".translate(context))
            ? minController
            : maxController,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(color: Colors.black),
        textAlign: TextAlign.center,
        onChanged: (value) {
            double? val = double.tryParse(value);
            if(val != null) {
              if (minMax == "minLbl".translate(context)) {
                 if(val <= _priceRangeValues.end) {
                   setState(() {
                     _priceRangeValues = RangeValues(val, _priceRangeValues.end);
                   });
                 }
              } else {
                 if(val >= _priceRangeValues.start) {
                   setState(() {
                      _priceRangeValues = RangeValues(_priceRangeValues.start, val);
                   });
                 }
              }
            }
        },
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          suffixText: "AED",
          suffixStyle: TextStyle(color: Colors.grey, fontSize: 12),
          hintText: "0",
          hintStyle: TextStyle(color: Colors.grey.shade400),
        ),
      ),
    );
  }

  Widget postedSinceOptionProperty(BuildContext context) {
    int index =
        Constant.postedSince.indexWhere((item) => item.value == postedOn);
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, Routes.postedSinceFilterScreen,
            arguments: {
              "list": Constant.postedSince,
              "postedSince": postedOn,
              "update": postedSinceUpdate
            });
      },
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, color: Colors.black54, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(Constant.postedSince[index].status)
                  .color(Colors.grey.shade600),
            ),
            Icon(Icons.keyboard_arrow_down, color: Colors.black54),
          ],
        ),
      ),
    );
  }

  Widget customFields() {
    return BlocConsumer<FetchCustomFieldsCubit, FetchCustomFieldState>(
      listener: (context, state) {
        if (state is FetchCustomFieldSuccess) {
          moreDetailDynamicFields = context
              .read<FetchCustomFieldsCubit>()
              .getFields()
              .where((field) =>
                  field.type != "fileinput" && field.type != "textbox" && field.type != "number")
              .map((field) {
            Map<String, dynamic> fieldData = field.toMap();

            // Prefill value from Constant.itemFilter!.customFields
            if (Constant.itemFilter != null &&
                Constant.itemFilter!.customFields != null) {
              String customFieldKey = 'custom_fields[${fieldData['id']}]';
              if (Constant.itemFilter!.customFields!
                  .containsKey(customFieldKey)) {
                fieldData['value'] =
                    Constant.itemFilter!.customFields![customFieldKey];
                fieldData['isEdit'] = true;
              }
            }

            CustomFieldBuilder customFieldBuilder =
                CustomFieldBuilder(fieldData);
            customFieldBuilder.stateUpdater(setState);
            customFieldBuilder.init();
            return customFieldBuilder;
          }).toList();
          setState(() {});
        }
      },
      builder: (context, state) {
        if (moreDetailDynamicFields.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: moreDetailDynamicFields.map((field) {
              field.stateUpdater(setState);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 9.0),
                child: field.build(context),
              );
            }).toList(),
          );
        } else {
          return SizedBox();
        }
      },
    );
  }

  Widget locationWidget(BuildContext context) {
    final locationText = [area, city, _state, country]
        .where((element) => element != null && element.isNotEmpty)
        .join(", ");

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _onTapChooseLocation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.color.territoryColor.withValues(alpha: 0.1),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.location_on_outlined,
                      size: 20,
                      color: context.color.territoryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    locationText.isNotEmpty
                        ? locationText
                        : "allCities".translate(context),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: locationText.isNotEmpty
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: locationText.isNotEmpty
                          ? context.color.textDefaultColor
                          : context.color.textLightColor,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: context.color.textLightColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget categoryWidget(BuildContext context) {
    final hasCategory = categoryList.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            categoryList.clear();
            Navigator.pushNamed(context, Routes.categoryFilterScreen,
                arguments: {"categoryList": categoryList}).then((value) {
              if (categoryList.isNotEmpty) {
                setState(() {});
                selectedCategories.clear();
                selectedCategories.addAll(
                    categoryList.map<String>((e) => e.id.toString()).toList());
                getCustomFieldsData();
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.color.territoryColor.withValues(alpha: 0.1),
                  ),
                  child: ClipOval(
                    child: (hasCategory &&
                            categoryList[0].url != null &&
                            categoryList[0].url!.trim().isNotEmpty)
                        ? Padding(
                            padding: const EdgeInsets.all(7.0),
                            child: UiUtils.imageType(
                              categoryList[0].url!,
                              fit: BoxFit.contain,
                              color: categoryList[0].url!.endsWith('.svg')
                                  ? context.color.territoryColor
                                  : null,
                            ),
                          )
                        : Icon(
                            Icons.grid_view_rounded,
                            size: 18,
                            color: context.color.territoryColor,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasCategory
                        ? categoryList.map((e) => e.name).join(' - ')
                        : "allInClassified".translate(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: hasCategory
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: hasCategory
                          ? context.color.textDefaultColor
                          : context.color.textLightColor,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: context.color.textLightColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget saveFilter() {
    return IconButton(
      onPressed: () {
        Constant.itemFilter = ItemFilterModel(
          maxPrice: maxController.text,
          city: city,
          areaId: areaId,
          radius: radius,
          state: _state,
          country: country,
          longitude: longitude,
          latitude: latitude,
          minPrice: minController.text,
          categoryId: selectedCategory?.id ?? "",
          postedSince: postedOn,
        );

        Navigator.pop(context, true);
      },
      icon: const Icon(Icons.check),
    );
  }

  Widget budgetOption() {
    double min = double.tryParse(minController.text.replaceAll(',', '')) ?? 0;
    double max = double.tryParse(maxController.text.replaceAll(',', '')) ?? 1000000;
    if (min < 0) min = 0;
    if (max > 1000000) max = 1000000;
    if (max < min) max = min;

    return Column(
      children: [
        Row(
          children: <Widget>[
            Expanded(
              child: minMaxTFF("minLbl".translate(context)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                "-",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: minMaxTFF("maxLbl".translate(context)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        RangeSlider(
          values: RangeValues(min, max),
          min: 0,
          max: 1000000,
          activeColor: context.color.territoryColor,
          inactiveColor: context.color.territoryColor.withValues(alpha: 0.2),
          onChanged: (RangeValues values) {
            setState(() {
              _priceRangeValues = values;
              minController.text = values.start.round().toString();
              maxController.text = values.end.round().toString();
            });
          },
        ),
      ],
    );
  }

  Widget minMaxTFF(String minMax) {
    final isMin = minMax == "minLbl".translate(context);
    final controller = isMin ? minController : maxController;

    return Container(
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: TextFormField(
        controller: controller,
        onChanged: (value) {
          bool isEmpty = value.trim().isEmpty;
          if (isMin) {
            if (isEmpty && searchbody.containsKey(Api.minPrice)) {
              searchbody.remove(Api.minPrice);
            } else {
              searchbody[Api.minPrice] = value;
            }
          } else {
            if (isEmpty && searchbody.containsKey(Api.maxPrice)) {
              searchbody.remove(Api.maxPrice);
            } else {
              searchbody[Api.maxPrice] = value;
            }
          }
        },
        keyboardType: TextInputType.number,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: context.color.textDefaultColor,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: InputBorder.none,
          labelText: minMax,
          labelStyle: TextStyle(
            color: context.color.textLightColor,
            fontSize: 13,
          ),
          prefixText: '${Constant.currencySymbol} ',
          prefixStyle: TextStyle(
            color: context.color.territoryColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void postedSinceUpdate(String value) {
    setState(() {
      postedOn = value;
    });
  }

  Widget postedSinceOption(BuildContext context) {
    int index = Constant.postedSince.indexWhere((item) => item.value == postedOn);
    if (index == -1) index = 0;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.pushNamed(context, Routes.postedSinceFilterScreen,
                arguments: {
                  "list": Constant.postedSince,
                  "postedSince": postedOn,
                  "update": postedSinceUpdate
                });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.color.territoryColor.withValues(alpha: 0.1),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: context.color.territoryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    Constant.postedSince[index].status,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: context.color.textLightColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void onClickPosted(String val) {
    if (val == Constant.postedSince[0].value &&
        searchbody.containsKey(Api.postedSince)) {
      searchbody[Api.postedSince] = "";
    } else {
      searchbody[Api.postedSince] = val;
    }

    postedOn = val;
    setState(() {});
  }
}

class PostedSinceItem {
  final String status;
  final String value;

  PostedSinceItem({
    required this.status,
    required this.value,
  });
}
