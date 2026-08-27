import 'dart:async';
import 'dart:developer';
import 'package:Ebozor/data/cubits/item/fetch_my_promoted_items_cubit.dart';
import 'package:Ebozor/data/helper/widgets.dart';
import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/data/model/custom_field/custom_field_model.dart';
import 'package:Ebozor/data/repositories/item/item_repository.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/report/fetch_item_report_reason_list.dart';
import 'package:Ebozor/data/cubits/subscription/fetch_ads_listing_subscription_packages_cubit.dart';
import 'package:Ebozor/ui/screens/home/home_screen.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/responsiveSize.dart';
import 'package:Ebozor/data/cubits/chat/make_an_offer_item_cubit.dart';
import 'package:Ebozor/ui/screens/widgets/dialogs/save_to_favorite_bottom_sheet.dart';
import 'package:Ebozor/data/cubits/favorite/favorite_cubit.dart';
import 'package:Ebozor/data/cubits/item/create_featured_ad_cubit.dart';
import 'package:Ebozor/data/cubits/item/fetch_my_item_cubit.dart';
import 'package:Ebozor/data/cubits/item/item_total_click_cubit.dart';
import 'package:Ebozor/data/cubits/item/related_item_cubit.dart';
import 'package:Ebozor/data/cubits/renew_item_cubit.dart';
import 'package:Ebozor/data/cubits/safety_tips_cubit.dart';
import 'package:Ebozor/data/cubits/seller/fetch_seller_ratings_cubit.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/data/model/subscription_pacakage_model.dart';

import 'package:Ebozor/utils/app_icon.dart';
import 'package:flick_video_player/flick_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/cloudState/cloud_state.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/data/cubits/report/item_report_cubit.dart';
import 'package:Ebozor/data/cubits/report/update_report_items_list_cubit.dart';
import 'package:Ebozor/data/cubits/chat/delete_message_cubit.dart';
import 'package:Ebozor/data/cubits/chat/load_chat_messages.dart';
import 'package:Ebozor/data/cubits/favorite/manage_fav_cubit.dart';
import 'package:Ebozor/data/cubits/item/change_my_items_status_cubit.dart';
import 'package:Ebozor/data/cubits/item/delete_item_cubit.dart';
import 'package:Ebozor/data/cubits/subscription/fetch_user_package_limit_cubit.dart';
import 'package:Ebozor/data/model/report_item/reason_model.dart';
import 'package:Ebozor/ui/screens/ad_banner_screen.dart';
import 'package:Ebozor/ui/screens/chat/chat_screen.dart';
import 'package:Ebozor/ui/screens/home/widgets/grid_list_adapter.dart';
import 'package:Ebozor/ui/screens/home/widgets/home_sections_adapter.dart';
import 'package:Ebozor/ui/screens/subscription/widget/featured_ads_subscription_plan_item.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_data_found.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_internet.dart';
import 'package:Ebozor/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:Ebozor/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:Ebozor/ui/screens/widgets/video_view_screen.dart';
import 'package:Ebozor/ui/screens/google_map_screen.dart';
import 'package:Ebozor/ui/screens/widgets/car_finance_calculator.dart';
import 'package:Ebozor/ui/screens/widgets/dialogs/report_listing_dialog.dart';
import 'package:Ebozor/ui/screens/widgets/dialogs/inquire_ad_dialog.dart';
import 'package:Ebozor/ui/screens/widgets/dialogs/seller_contact_dialog.dart';

class AdDetailsScreen extends StatefulWidget {
  final ItemModel model;
  final String? jobApplicationStatus;
  final String? editStatus;

  const AdDetailsScreen({
    super.key,
    required this.model,
    this.jobApplicationStatus,
    this.editStatus,
  });

  @override
  AdDetailsScreenState createState() => AdDetailsScreenState();

  static Route route(RouteSettings routeSettings) {
    Map? arguments = routeSettings.arguments as Map?;
    return BlurredRouter(
        builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (context) => FetchMyItemsCubit(),
                ),
                BlocProvider(
                  create: (context) => CreateFeaturedAdCubit(),
                ),
                BlocProvider(
                  create: (context) => FetchItemReportReasonsListCubit(),
                ),
                BlocProvider(
                  create: (context) => ItemReportCubit(),
                ),
                BlocProvider(
                  create: (context) => MakeAnOfferItemCubit(),
                ),
              ],
              child: AdDetailsScreen(
                model: arguments?['model'],
                jobApplicationStatus:
                    arguments?['jobApplicationStatus']?.toString(),
                editStatus: arguments?['editStatus']?.toString(),
                // from: arguments?['from'],
              ),
            ));
  }
}

class AdDetailsScreenState extends CloudState<AdDetailsScreen> {
  //ImageView
  int currentPage = 0;
  bool? isFeaturedLimit;
  List<String> selectedFeaturedAdsOptions = [];

  bool isShowReportAds = true;
  bool _showAllAmenities = false;
  bool _isDescriptionExpanded = false;
  final Map<int, bool> _expandedFeatures = {};
  final PageController pageController = PageController();
  final List<String?> images = [];
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();
  late final ScrollController _pageScrollController = ScrollController();
  List<ReportReason>? reasons = [];
  late int selectedId;
  final TextEditingController _reportmessageController =
      TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey();
  int? _selectedPackageIndex;

  late ItemModel model = widget.model;

  late bool isAddedByMe = (widget.model.user?.id != null
          ? widget.model.user!.id.toString()
          : (widget.model.userId?.toString() ?? '')) ==
      HiveUtils.getUserId();

  bool isFeaturedWidget = true;
  String youtubeVideoThumbnail = "";
  int? categoryId;
  FlickManager? flickManager;

  @override
  void initState() {
    super.initState();
    final routedStatus = widget.editStatus?.trim() ?? '';
    if ((model.status?.trim().isEmpty ?? true) && routedStatus.isNotEmpty) {
      model.status = routedStatus;
    }

    _fetchFullItemDetails();

    if (!isAddedByMe) {
      context.read<FetchItemReportReasonsListCubit>().fetch();
      context.read<FetchSafetyTipsListCubit>().fetchSafetyTips();
      final int? sellerId = widget.model.user?.id ?? widget.model.userId;
      if (sellerId != null) {
        context.read<FetchSellerRatingsCubit>().fetch(sellerId: sellerId);
      }
    } else {
      context.read<FetchAdsListingSubscriptionPackagesCubit>().fetchPackages();
    }
    categoryId = widget.model.category != null
        ? widget.model.category?.id
        : widget.model.categoryId;

    setItemClick();
    //ImageView
    combineImages();
    pageController.addListener(() {
      setState(() {
        currentPage = pageController.page!.round();
      });
    });
    if (categoryId != null) {
      context.read<FetchRelatedItemsCubit>().fetchRelatedItems(
          categoryId: categoryId!,
          itemId: widget.model.id,
          city: HiveUtils.getCityName(),
          areaId: HiveUtils.getAreaId(),
          country: HiveUtils.getCountryName(),
          state: HiveUtils.getStateName());
    }
    _pageScrollController.addListener(_pageScroll);
  }

  Future<void> _fetchFullItemDetails() async {
    if (widget.model.id == null) return;
    try {
      final res = await ItemRepository().fetchItemFromItemId(widget.model.id!);
      if (res.modelList.isNotEmpty && mounted) {
        final fullModel = res.modelList.first;
        if (fullModel.status?.trim().isEmpty ?? true) {
          fullModel.status = _editStatusFor(fullModel);
        }
        setState(() {
          model = fullModel;
          isAddedByMe = (fullModel.user?.id != null
                  ? fullModel.user!.id.toString()
                  : (fullModel.userId?.toString() ?? '')) ==
              HiveUtils.getUserId();
          images.clear();
          combineImages();
        });
        final int? sellerId = fullModel.user?.id ?? fullModel.userId;
        if (sellerId != null && !isAddedByMe) {
          context.read<FetchSellerRatingsCubit>().fetch(sellerId: sellerId);
        }
      }
    } catch (e) {
      // Keep initial model
    }
  }

  void _pageScroll() {
    if (_pageScrollController.isEndReached() && categoryId != null) {
      if (context.read<FetchRelatedItemsCubit>().hasMoreData()) {
        context.read<FetchRelatedItemsCubit>().fetchRelatedItemsMore(
            categoryId: categoryId!,
            city: HiveUtils.getCityName(),
            areaId: HiveUtils.getAreaId(),
            country: HiveUtils.getCountryName(),
            state: HiveUtils.getStateName());
      }
    }
  }

  late final CameraPosition _kInitialPlace = CameraPosition(
    target: LatLng(
      model.latitude ?? 0,
      model.longitude ?? 0,
    ),
    zoom: 14.4746,
  );

  @override
  void dispose() {
    super.dispose();
  }

  void combineImages() {
    final mainImage = model.image?.trim();
    if (mainImage != null && mainImage.isNotEmpty) {
      images.add(mainImage);
    }
    if (model.galleryImages != null && model.galleryImages!.isNotEmpty) {
      for (var element in model.galleryImages!) {
        final galleryImage = element.image?.trim();
        if (galleryImage != null && galleryImage.isNotEmpty) {
          images.add(galleryImage);
        }
      }
    }

    final videoLink = model.videoLink?.trim();
    if (videoLink != null && videoLink.isNotEmpty) {
      images.add(videoLink);
    }

    if (model.videoLink != "" &&
        model.videoLink != null &&
        !HelperUtils.isYoutubeVideo(model.videoLink ?? "")) {
      flickManager = FlickManager(
        videoPlayerController: VideoPlayerController.networkUrl(
          Uri.parse(model.videoLink!),
        ),
      );
      flickManager?.onVideoEnd = () {};
    }
    if (model.videoLink != "" &&
        model.videoLink != null &&
        HelperUtils.isYoutubeVideo(model.videoLink ?? "")) {
      String? videoId = YoutubePlayer.convertUrlToId(model.videoLink!);
      if (videoId != null) {
        String thumbnail = YoutubePlayer.getThumbnail(videoId: videoId);

        youtubeVideoThumbnail = thumbnail;
      }
      setState(() {});
    }
  }

  /* void injectVideoInGallery() {
    ///This will inject video in image list just like another platforms
    if ((gallary?.length ?? 0) < 2) {
      if (model.videoLink != null) {
        gallary?.add(GalleryImages(

            id: 99999999999,

            image: property!.video ?? "",
            imageUrl: "",
            isVideo: true));
      }
    } else {
      gallary?.insert(
          0,
          GalleryImages(
              id: 99999999999,
              image: property!.video!,
              imageUrl: "",
              isVideo: true));
    }

    setState(() {});
  }*/

  void setItemClick() {
    if (!isAddedByMe && model.id != null) {
      context.read<ItemTotalClickCubit>().itemTotalClick(model.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isJobAd()) {
      return _buildJobDetailsScreen();
    }

    return AnnotatedRegion(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: context.color.secondaryDetailsColor,
          extendBodyBehindAppBar: true,
          bottomNavigationBar: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: bottomButtonWidget()),
          body: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Edge-to-Edge Image viewer under status bar
                  setImageViewer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14.0, vertical: 10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Price and status widget
                        setPriceAndStatus(),
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0, bottom: 2.0),
                          child: Text(model.name ?? "")
                              .size(context.font.large)
                              .bold(weight: FontWeight.w700)
                              .setMaxLines(lines: 2)
                              .color(context.color.textDefaultColor),
                        ),
                        _buildKeyHighlights(),

                        if (isAddedByMe) setRejectedReason(),

                        if (Constant.isGoogleBannerAdsEnabled == "1") ...[
                          Divider(
                              thickness: 1,
                              color: context.color.textDefaultColor
                                  .withValues(alpha: 0.1)),
                          Container(
                            alignment: AlignmentDirectional.center,
                            child: AdBannerWidget(),
                          ),
                        ],

                        if (isAddedByMe && model.isFeature != true)
                          createFeaturesAds(),

                        // Car / Item Overview (2-column key-value with Show More / Show Less)
                        _buildOverviewSection(),

                        // Property Amenities Grid (3 per row with Show More)
                        _buildAmenitiesSection(),

                        // Description with Read More & Posted On date
                        _buildDescriptionSection(),

                        // Features (expandable accordion categories with checkmarks)
                        _buildFeaturesSection(),

                        // Car Finance Calculator (shown for Cars / Motors listings with price > 0)
                        if (_isCarListing() &&
                            (model.price != null && model.price! > 0))
                          CarFinanceCalculator(
                            initialPrice: model.price ?? 0.0,
                            carName: model.name,
                            showApplyButton: false,
                          ),

                        // Location section with map preview
                        _buildLocationSection(),

                        // Seller details section with verified checkmark & view profile
                        if (!isAddedByMe) _buildSellerSection(),

                        if (Constant.isGoogleBannerAdsEnabled == "1") ...[
                          const SizedBox(height: 10),
                          Container(
                            alignment: AlignmentDirectional.center,
                            child: AdBannerWidget(),
                          ),
                        ],

                        // Report ad widget
                        if (!isAddedByMe) _buildReportAdRow(),

                        const SizedBox(height: 12),
                        // Similar ads widget
                        relatedAds(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
  }

  Widget _buildJobDetailsScreen() {
    final companyName = _jobCustomFieldValue(
          const ['company name', 'company'],
        ) ??
        model.user?.name?.trim();
    final salary = _jobCustomFieldValue(
          const ['monthly salary', 'salary', 'compensation'],
        ) ??
        ((model.price ?? 0) > 0
            ? '${Constant.currencySymbol} ${model.price}'
            : null);
    final employmentType = _jobCustomFieldValue(
      const ['employment type', 'job type'],
    );
    final experience = _jobCustomFieldValue(
      const ['work experience', 'experience'],
    );
    final location = _jobLocationLabel();

    final facts = <Widget>[
      if (salary != null) _buildJobFact(Icons.payments_outlined, salary),
      if (location.isNotEmpty)
        _buildJobFact(Icons.location_on_outlined, location),
      if (employmentType != null)
        _buildJobFact(Icons.schedule_outlined, employmentType),
      if (experience != null)
        _buildJobFact(Icons.work_history_outlined, experience),
    ];

    return AnnotatedRegion(
      value: SystemUiOverlayStyle(
        statusBarColor: context.color.secondaryColor,
        statusBarIconBrightness:
            Theme.of(context).brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: context.color.secondaryDetailsColor,
        appBar: AppBar(
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
            'Job Details',
            style: TextStyle(
              color: context.color.textDefaultColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            if (isAddedByMe)
              IconButton(
                tooltip: 'Edit job',
                onPressed: () => _navigateToEditAd(context, model),
                icon: Icon(
                  Icons.edit_outlined,
                  color: context.color.textDefaultColor,
                ),
              ),
            IconButton(
              tooltip: 'Share job',
              onPressed: () => HelperUtils.share(context, model.slug ?? ''),
              icon: Icon(
                Icons.share_outlined,
                color: context.color.textDefaultColor,
              ),
            ),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(10, 5, 10, 8),
          child: SafeArea(top: false, child: bottomButtonWidget()),
        ),
        body: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model.name?.trim().isNotEmpty == true
                              ? model.name!.trim()
                              : 'Job opportunity',
                          style: TextStyle(
                            color: context.color.textDefaultColor,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        if (companyName != null &&
                            companyName.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            companyName,
                            style: TextStyle(
                              color: context.color.textLightColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (model.category?.name?.trim().isNotEmpty ==
                            true) ...[
                          const SizedBox(height: 4),
                          Text(
                            model.category!.name!.trim(),
                            style: TextStyle(
                              color: context.color.textLightColor,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color:
                          context.color.territoryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.color.territoryColor
                            .withValues(alpha: 0.2),
                      ),
                    ),
                    child: model.user?.profile?.trim().isNotEmpty == true
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: UiUtils.getImage(
                              model.user!.profile!.trim(),
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            Icons.business_center_outlined,
                            color: context.color.territoryColor,
                            size: 30,
                          ),
                  ),
                ],
              ),
              if (facts.isNotEmpty) ...[
                const SizedBox(height: 18),
                Wrap(
                  spacing: 14,
                  runSpacing: 10,
                  children: facts,
                ),
              ],
              if (model.description?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 24),
                _buildJobSectionTitle('Job Details'),
                const SizedBox(height: 10),
                Text(
                  model.description!.trim(),
                  style: TextStyle(
                    color: context.color.textDefaultColor
                        .withValues(alpha: 0.82),
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
              ],
              _buildJobDynamicDetails(),
              if (model.created?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 18),
                Text(
                  'Posted on ${model.created!.formatDate(format: "d MMMM, yyyy")}',
                  style: TextStyle(
                    color: context.color.textLightColor,
                    fontSize: 12,
                  ),
                ),
              ],
              if (!isAddedByMe) ...[
                const SizedBox(height: 20),
                _buildReportAdRow(),
              ],
              const SizedBox(height: 14),
              relatedAds(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: context.color.textDefaultColor,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildJobFact(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: context.color.textLightColor),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.68,
          ),
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.color.textDefaultColor.withValues(alpha: 0.78),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  String _jobLocationLabel() {
    final values = <String>[
      model.area ?? '',
      model.city ?? '',
      model.state ?? '',
      model.country ?? '',
    ];
    final unique = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty &&
          !unique.any((entry) => entry.toLowerCase() == trimmed.toLowerCase())) {
        unique.add(trimmed);
      }
    }
    if (unique.isNotEmpty) return unique.join(', ');
    return model.address?.trim() ?? '';
  }

  String _normalizeJobFieldName(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  String? _jobFieldValue(CustomFieldModel field) {
    final values = field.value
            ?.map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toList() ??
        const <String>[];
    if (values.isEmpty) return null;
    return values.join(', ');
  }

  String? _jobCustomFieldValue(List<String> aliases) {
    final normalizedAliases =
        aliases.map(_normalizeJobFieldName).where((value) => value.isNotEmpty);
    for (final field in model.customFields ?? const <CustomFieldModel>[]) {
      final value = _jobFieldValue(field);
      if (value == null) continue;
      final fieldName =
          _normalizeJobFieldName('${field.name ?? ''} ${field.label ?? ''}');
      if (normalizedAliases.any(
        (alias) => fieldName == alias || fieldName.contains(alias),
      )) {
        return value;
      }
    }
    return null;
  }

  Widget _buildJobDynamicDetails() {
    final fields = (model.customFields ?? const <CustomFieldModel>[])
        .where((field) => _jobFieldValue(field) != null)
        .where((field) => field.type?.toLowerCase() != 'fileinput')
        .toList();
    if (fields.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _buildJobSectionTitle('Job Information'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.color.borderColor.withValues(alpha: 0.55),
            ),
          ),
          child: Column(
            children: List.generate(fields.length, (index) {
              final field = fields[index];
              final label = (field.label ?? field.name ?? 'Information').trim();
              final value = _jobFieldValue(field)!;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: Text(
                            label,
                            style: TextStyle(
                              color: context.color.textLightColor,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 5,
                          child: Text(
                            value,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              color: context.color.textDefaultColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (index != fields.length - 1)
                    Divider(
                      height: 1,
                      color:
                          context.color.borderColor.withValues(alpha: 0.45),
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  bool _isCarListing() {
    final catName = (model.category?.name ?? "").toLowerCase();
    final catSlug = (model.category?.slug ?? "").toLowerCase();
    if (catName.contains("car") ||
        catName.contains("motor") ||
        catName.contains("vehicle") ||
        catName.contains("auto") ||
        catSlug.contains("car") ||
        catSlug.contains("motor") ||
        catSlug.contains("vehicle") ||
        catSlug.contains("auto")) {
      return true;
    }
    // Check custom fields for vehicle specific attributes (e.g. kilometers, transmission, trim, year)
    if (model.customFields != null) {
      for (var cf in model.customFields!) {
        final n = (cf.name ?? "").toLowerCase();
        if (n.contains("kilometer") ||
            n.contains("mileage") ||
            n.contains("trim") ||
            n.contains("car_make") ||
            n.contains("transmission") ||
            n.contains("specs")) {
          return true;
        }
      }
    }
    return false;
  }

  Widget _buildKeyHighlights() {
    List<Widget> chips = [];
    if (model.customFields != null) {
      for (var cf in model.customFields!) {
        final nameLower = (cf.name ?? "").toLowerCase();
        if (cf.value != null && cf.value!.isNotEmpty) {
          final val = cf.value![0].toString();
          if (nameLower.contains("year") || nameLower.contains("model")) {
            chips.add(_specChip(Icons.calendar_today_outlined, val));
          } else if (nameLower.contains("kilometer") ||
              nameLower.contains("mileage") ||
              nameLower.contains("km")) {
            chips.add(_specChip(Icons.speed_outlined, "$val km"));
          } else if (nameLower.contains("spec") ||
              nameLower.contains("regional")) {
            chips.add(_specChip(Icons.public_outlined, val));
          }
        }
      }
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: chips,
      ),
    );
  }

  Widget _specChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.color.borderColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 14,
              color: context.color.textDefaultColor.withValues(alpha: 0.65)),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: context.color.textDefaultColor.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  bool _isPropertyListing() {
    final catName = (model.category?.name ?? "").toLowerCase();
    final catSlug = (model.category?.slug ?? "").toLowerCase();
    final allCatIds = model.allCategoryIds ?? "";
    if (catName.contains("property") ||
        catName.contains("residential") ||
        catName.contains("commercial") ||
        catName.contains("rent") ||
        catSlug.contains("property") ||
        catSlug.contains("residential") ||
        catSlug.contains("commercial") ||
        allCatIds.contains("65") ||
        allCatIds.contains("139") ||
        allCatIds.contains("3") ||
        allCatIds.contains("66") ||
        allCatIds.contains("77") ||
        allCatIds.contains("78") ||
        allCatIds.contains("85")) {
      return true;
    }
    if (model.customFields != null) {
      for (var cf in model.customFields!) {
        final n = (cf.name ?? "").toLowerCase();
        if (n.contains("amenit") ||
            n.contains("bedroom") ||
            n.contains("bathroom") ||
            n.contains("furnish") ||
            n.contains("sqft") ||
            n.contains("rera") ||
            n.contains("brn")) {
          return true;
        }
      }
    }
    return false;
  }

  IconData _getAmenityIcon(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.contains("pool") || lower.contains("swimming")) {
      return Icons.pool_outlined;
    }
    if (lower.contains("ac") ||
        lower.contains("a/c") ||
        lower.contains("heat") ||
        lower.contains("climate") ||
        lower.contains("air condition")) {
      return Icons.ac_unit_outlined;
    }
    if (lower.contains("balcony")) {
      return Icons.balcony_outlined;
    }
    if (lower.contains("maid")) {
      return Icons.cleaning_services_outlined;
    }
    if (lower.contains("study") ||
        lower.contains("office") ||
        lower.contains("desk")) {
      return Icons.menu_book_outlined;
    }
    if (lower.contains("concierge") || lower.contains("reception")) {
      return Icons.room_service_outlined;
    }
    if (lower.contains("garden") ||
        lower.contains("yard") ||
        lower.contains("park")) {
      return Icons.yard_outlined;
    }
    if (lower.contains("gym") ||
        lower.contains("fitness") ||
        lower.contains("workout")) {
      return Icons.fitness_center_outlined;
    }
    if (lower.contains("park") || lower.contains("garage")) {
      return Icons.local_parking_outlined;
    }
    if (lower.contains("wardrobe") || lower.contains("closet")) {
      return Icons.checkroom_outlined;
    }
    if (lower.contains("pet")) {
      return Icons.pets_outlined;
    }
    if (lower.contains("security") || lower.contains("cctv")) {
      return Icons.security_outlined;
    }
    if (lower.contains("view") ||
        lower.contains("landmark") ||
        lower.contains("water")) {
      return Icons.visibility_outlined;
    }
    if (lower.contains("elevator") || lower.contains("lift")) {
      return Icons.elevator_outlined;
    }
    if (lower.contains("bbq") || lower.contains("barbeque")) {
      return Icons.outdoor_grill_outlined;
    }
    if (lower.contains("play") ||
        lower.contains("kid") ||
        lower.contains("children")) {
      return Icons.child_care_outlined;
    }
    return Icons.verified_outlined;
  }

  Widget _buildAmenitiesSection() {
    if (!_isPropertyListing()) return const SizedBox.shrink();
    if (model.customFields == null || model.customFields!.isEmpty) {
      return const SizedBox.shrink();
    }

    CustomFieldModel? amenityField;
    for (var cf in model.customFields!) {
      if ((cf.name ?? "").toLowerCase().contains("amenit")) {
        amenityField = cf;
        break;
      }
    }

    if (amenityField == null ||
        amenityField.value == null ||
        amenityField.value!.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<dynamic> allAmenities = amenityField.value!;
    final displayedAmenities =
        _showAllAmenities ? allAmenities : allAmenities.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Text("Amenities".translate(context))
            .bold(weight: FontWeight.w700)
            .size(18)
            .color(context.color.textDefaultColor),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayedAmenities.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.05,
          ),
          itemBuilder: (context, index) {
            final amenityName = displayedAmenities[index].toString().trim();
            final icon = _getAmenityIcon(amenityName);

            String? optionImageUrl;
            if (amenityField?.image != null &&
                amenityField!.image!.isNotEmpty) {
              optionImageUrl = amenityField.image;
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: context.color.secondaryColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: context.color.borderColor.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (optionImageUrl != null && optionImageUrl.isNotEmpty)
                    SizedBox(
                      height: 26,
                      width: 26,
                      child:
                          UiUtils.getImage(optionImageUrl, fit: BoxFit.contain),
                    )
                  else
                    Icon(
                      icon,
                      size: 24,
                      color: context.color.territoryColor,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    amenityName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: context.color.textDefaultColor,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (allAmenities.length > 6) ...[
          const SizedBox(height: 8),
          Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                setState(() {
                  _showAllAmenities = !_showAllAmenities;
                });
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _showAllAmenities
                          ? "Show Less".translate(context)
                          : "Show More (${allAmenities.length - 6} more)"
                              .translate(context),
                      style: TextStyle(
                        color: context.color.territoryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _showAllAmenities
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: context.color.territoryColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  bool _isOverviewSpecField(String name, int valueCount) {
    final lower = name.toLowerCase().trim();
    if (lower.contains("color") ||
        lower.contains("year") ||
        lower.contains("kilometer") ||
        lower.contains("mileage") ||
        lower.contains("door") ||
        lower.contains("steering") ||
        lower.contains("body type") ||
        lower.contains("fuel") ||
        lower.contains("cylinder") ||
        lower.contains("transmission") ||
        lower.contains("seating") ||
        lower.contains("engine capacity") ||
        lower.contains("horsepower") ||
        lower.contains("warranty") ||
        lower.contains("regional spec") ||
        lower.contains("specs") ||
        lower.contains("make") ||
        lower.contains("model") ||
        lower.contains("trim") ||
        lower.contains("price") ||
        lower.contains("bedroom") ||
        lower.contains("bathroom") ||
        lower.contains("furnish") ||
        lower.contains("sqft") ||
        lower.contains("size") ||
        lower.contains("area") ||
        lower.contains("building") ||
        lower.contains("developer") ||
        lower.contains("ready by") ||
        lower.contains("listed by") ||
        lower.contains("rera") ||
        lower.contains("brn")) {
      return true;
    }
    if (valueCount <= 1 && !lower.contains("feature")) {
      return true;
    }
    return false;
  }

  IconData _getFeatureCategoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains("safety") ||
        lower.contains("assist") ||
        lower.contains("driver")) {
      return Icons.shield_outlined;
    }
    if (lower.contains("entertain") ||
        lower.contains("tech") ||
        lower.contains("audio") ||
        lower.contains("screen")) {
      return Icons.devices_other_outlined;
    }
    if (lower.contains("comfort") ||
        lower.contains("convenien") ||
        lower.contains("seat")) {
      return Icons.airline_seat_recline_extra_outlined;
    }
    if (lower.contains("exterior") ||
        lower.contains("wheel") ||
        lower.contains("roof")) {
      return Icons.directions_car_outlined;
    }
    if (lower.contains("interior")) {
      return Icons.meeting_room_outlined;
    }
    return Icons.auto_awesome_outlined;
  }

  void _showAllOverviewBottomSheet(
      BuildContext context, List<CustomFieldModel> overviewFields) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // BottomSheet Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${model.category?.name != null ? "${model.category!.name!} " : ""}Overview"
                            .translate(context),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 22),
                        color: context.color.textDefaultColor,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    itemCount: overviewFields.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 0.8,
                      color: context.color.borderColor.withValues(alpha: 0.25),
                    ),
                    itemBuilder: (context, index) {
                      final cf = overviewFields[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Text(
                                cf.name ?? "",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.color.textDefaultColor
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 6,
                              child: Text(
                                cf.value != null && cf.value!.isNotEmpty
                                    ? cf.value!.join(', ')
                                    : "-",
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: context.color.textDefaultColor,
                                ),
                              ),
                            ),
                          ],
                        ),
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
  }

  Widget _buildOverviewSection() {
    if (model.customFields == null || model.customFields!.isEmpty) {
      return const SizedBox.shrink();
    }

    final overviewFields = model.customFields!.where((cf) {
      if (cf.value == null || cf.value!.isEmpty) return false;
      final name = (cf.name ?? "").toLowerCase();
      // Exclude CV / Resume uploads from Overview
      if (name.contains("upload your cv") ||
          name.contains("cv") ||
          name.contains("resume") ||
          cf.type == "fileinput") {
        return false;
      }
      if (_isPropertyListing() && name.contains("amenit")) {
        return false;
      }
      return _isOverviewSpecField(cf.name ?? "", cf.value!.length) ||
          cf.value!.length <= 1;
    }).toList();

    if (overviewFields.isEmpty) return const SizedBox.shrink();

    final displayedFields = overviewFields.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Text(
          "${model.category?.name != null ? "${model.category!.name!} " : ""}Overview",
        )
            .bold(weight: FontWeight.w700)
            .size(18)
            .color(context.color.textDefaultColor),
        const SizedBox(height: 12),
        Column(
          children: [
            ...displayedFields.asMap().entries.map((entry) {
              final cf = entry.value;
              final isLast = entry.key == displayedFields.length - 1;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text(
                            cf.name ?? "",
                            style: TextStyle(
                              fontSize: 14,
                              color: context.color.textDefaultColor
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 6,
                          child: Text(
                            cf.value != null && cf.value!.isNotEmpty
                                ? cf.value!.join(', ')
                                : "-",
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.color.textDefaultColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!isLast) ...[
                      const SizedBox(height: 8),
                      Divider(
                        height: 1,
                        thickness: 0.8,
                        color:
                            context.color.borderColor.withValues(alpha: 0.25),
                      ),
                    ],
                  ],
                ),
              );
            }),
            if (overviewFields.length > 6) ...[
              const SizedBox(height: 6),
              Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    _showAllOverviewBottomSheet(context, overviewFields);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 6.0, horizontal: 12.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Show More (${overviewFields.length - 6} more)"
                              .translate(context),
                          style: TextStyle(
                            color: context.color.territoryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: context.color.territoryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    if (model.description == null || model.description!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Text("aboutThisItemLbl".translate(context))
            .bold(weight: FontWeight.w700)
            .size(18)
            .color(context.color.textDefaultColor),
        const SizedBox(height: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              model.description ?? "",
              maxLines: _isDescriptionExpanded ? null : 4,
              overflow: _isDescriptionExpanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: context.color.textDefaultColor.withValues(alpha: 0.75),
              ),
            ),
            if ((model.description?.length ?? 0) > 160) ...[
              const SizedBox(height: 6),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () {
                  setState(() {
                    _isDescriptionExpanded = !_isDescriptionExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isDescriptionExpanded
                            ? "Read Less".translate(context)
                            : "Read More".translate(context),
                        style: TextStyle(
                          color: context.color.territoryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isDescriptionExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: context.color.territoryColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (model.created != null) ...[
              const SizedBox(height: 8),
              Text(
                "Posted On: ${model.created!.formatDate(format: "d MMMM, yyyy")}",
                style: TextStyle(
                  fontSize: 12,
                  color: context.color.textDefaultColor.withValues(alpha: 0.45),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildFeaturesSection() {
    if (model.customFields == null || model.customFields!.isEmpty) {
      return const SizedBox.shrink();
    }

    final featureFields = model.customFields!.where((cf) {
      if (cf.value == null || cf.value!.isEmpty) return false;
      final name = (cf.name ?? "").toLowerCase();
      if (name.contains("upload your cv") ||
          name.contains("cv") ||
          name.contains("resume") ||
          cf.type == "fileinput") {
        return false;
      }
      if (_isPropertyListing() && name.contains("amenit")) {
        return false;
      }
      if (_isOverviewSpecField(cf.name ?? "", cf.value!.length)) {
        return false;
      }
      return cf.value!.length > 1 ||
          name.contains("feature") ||
          name.contains("safety") ||
          name.contains("comfort") ||
          name.contains("technology") ||
          name.contains("entertainment");
    }).toList();

    if (featureFields.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Text("Features".translate(context))
            .bold(weight: FontWeight.w700)
            .size(18)
            .color(context.color.textDefaultColor),
        const SizedBox(height: 10),
        ...featureFields.asMap().entries.map((entry) {
          final index = entry.key;
          final cf = entry.value;
          final isExpanded = _expandedFeatures[index] ?? true;
          final values = cf.value ?? [];
          final categoryIcon = _getFeatureCategoryIcon(cf.name ?? "");

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: context.color.secondaryColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: context.color.borderColor.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              children: [
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      setState(() {
                        _expandedFeatures[index] = !isExpanded;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            categoryIcon,
                            size: 18,
                            color: context.color.territoryColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cf.name ?? "Feature",
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: context.color.textDefaultColor,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.color.territoryColor
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "${values.length}",
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: context.color.territoryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: context.color.textLightColor,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isExpanded) ...[
                  Divider(
                    height: 1,
                    thickness: 0.8,
                    color: context.color.borderColor.withValues(alpha: 0.25),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Column(
                      children: values.map((val) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.12),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.check_rounded,
                                    size: 12,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  val.toString(),
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: context.color.textDefaultColor,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLocationSection() {
    final LatLng currentPosition =
        LatLng(model.latitude ?? 0.0, model.longitude ?? 0.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Text("locationLbl".translate(context))
            .bold(weight: FontWeight.w700)
            .size(18)
            .color(context.color.textDefaultColor),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 20,
              color: context.color.territoryColor,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                model.address ?? "",
                style: TextStyle(
                  fontSize: 14,
                  color: context.color.textDefaultColor.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 190,
            child: Stack(
              children: [
                GoogleMap(
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  compassEnabled: false,
                  mapToolbarEnabled: false,
                  liteModeEnabled: true,
                  zoomGesturesEnabled: false,
                  scrollGesturesEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  initialCameraPosition:
                      CameraPosition(target: currentPosition, zoom: 14),
                  mapType: MapType.normal,
                  markers: {
                    Marker(
                      markerId: const MarkerId('currentPosition'),
                      position: currentPosition,
                    )
                  },
                ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      _navigateToGoogleMapScreen(context);
                    },
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSellerSection() {
    if (isAddedByMe) {
      return const SizedBox.shrink();
    }
    final user = model.user ?? widget.model.user;
    if (user == null && model.contact == null && model.userId == null) {
      return const SizedBox.shrink();
    }

    final isVerified = user?.isVerified == 1;
    final userName = user?.name ?? "Owner / Seller";
    final profileUrl = user?.profile;

    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Centered Profile Image (Rounded square portrait)
          Container(
            height: 72,
            width: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: context.color.territoryColor.withValues(alpha: 0.12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: profileUrl != null && profileUrl.isNotEmpty
                  ? UiUtils.getImage(profileUrl, fit: BoxFit.cover)
                  : Center(
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : "U",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: context.color.territoryColor,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),

          // Seller Name + Verified Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  userName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isVerified) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.verified,
                  color: Colors.blue,
                  size: 18,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),

          // "View All Properties" / "View All Listings" link
          if (user != null)
            InkWell(
              onTap: () {
                Navigator.pushNamed(context, Routes.sellerProfileScreen,
                    arguments: {
                      "model": user,
                      "total": context
                              .read<FetchSellerRatingsCubit>()
                              .totalSellerRatings() ??
                          0,
                      "rating": context
                          .read<FetchSellerRatingsCubit>()
                          .sellerData()
                          ?.averageRating
                    });
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 3, horizontal: 8),
                child: Text(
                  "View All Properties",
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          // "View Agency Profile >" / "View Profile >"
          if (user != null)
            InkWell(
              onTap: () {
                Navigator.pushNamed(context, Routes.sellerProfileScreen,
                    arguments: {
                      "model": user,
                      "total": context
                              .read<FetchSellerRatingsCubit>()
                              .totalSellerRatings() ??
                          0,
                      "rating": context
                          .read<FetchSellerRatingsCubit>()
                          .sellerData()
                          ?.averageRating
                    });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "View Agency Profile",
                      style: TextStyle(
                        fontSize: 13,
                        color: context.color.textDefaultColor
                            .withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color:
                          context.color.textDefaultColor.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReportAdRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: InkWell(
        onTap: () {
          UiUtils.checkUser(
            onNotGuest: () {
              _bottomSheet(model.id!);
            },
            context: context,
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: context.color.borderColor.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.flag_outlined,
                size: 18,
                color: context.color.textDefaultColor.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                "reportItem".translate(context),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.color.textDefaultColor.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget reportedAdsWidget() {
    return BlocBuilder<UpdatedReportItemCubit, UpdatedReportItemState>(
      builder: (context, state) {
        bool isItemInCubit =
            context.read<UpdatedReportItemCubit>().containsItem(model.id!);

        if (!isItemInCubit) {
          if (model.isAlreadyReported != null && !model.isAlreadyReported!) {
            return setReportAd();
          } else {
            return SizedBox(); // Return an empty widget if conditions are not met
          }
        } else {
          return SizedBox(); // Return an empty widget if item is not in cubit
        }
      },
    );
  }

  Widget relatedAds() {
    return BlocBuilder<FetchRelatedItemsCubit, FetchRelatedItemsState>(
        builder: (context, state) {
      if (state is FetchRelatedItemsInProgress) {
        return relatedItemShimmer();
      }
      if (state is FetchRelatedItemsFailure) {
        if (state.errorMessage is ApiException) {
          if (state.errorMessage == "no-internet") {
            return NoInternet(
              onRetry: () {
                context.read<FetchRelatedItemsCubit>().fetchRelatedItems(
                    categoryId: categoryId!,
                    itemId: model.id ?? widget.model.id,
                    city: HiveUtils.getCityName(),
                    areaId: HiveUtils.getAreaId(),
                    country: HiveUtils.getCountryName(),
                    state: HiveUtils.getStateName());
              },
            );
          }
        }

        return const SomethingWentWrong();
      }

      if (state is FetchRelatedItemsSuccess) {
        if (state.itemModel.isEmpty || state.itemModel.length == 1) {
          return SizedBox.shrink();
        }

        return buildRelatedListWidget(state);
      }

      return const SizedBox.square();
    });
  }

  Widget buildRelatedListWidget(FetchRelatedItemsSuccess state) {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_isJobAd() ? "Similar Jobs" : "Similar Ads")
              .size(context.font.large)
              .bold(weight: FontWeight.w600)
              .setMaxLines(lines: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5.0),
            child: Row(
              children: [
                SvgPicture.asset(
                  AppIcons.location,
                  colorFilter: ColorFilter.mode(
                      context.color.textLightColor, BlendMode.srcIn),
                  width: 12,
                  height: 12,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(model.address ?? "")
                      .size(context.font.small)
                      .color(context.color.textDefaultColor
                          .withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 10,
          ),
          GridListAdapter(
            type: ListUiType.List,
            height: MediaQuery.of(context).size.height / 3.5.rh(context),
            controller: _pageScrollController,
            listAxis: Axis.horizontal,
            listSaperator: (BuildContext p0, int p1) => const SizedBox(
              width: 14,
            ),
            isNotSidePadding: true,
            builder: (context, int index, bool) {
              ItemModel? item = state.itemModel[index];

              if (item.id != model.id) {
                return ItemCard(
                  item: item,
                  width: 162,
                );
              } else {
                return SizedBox.shrink();
              }
            },
            total: state.itemModel.length,
          ),
        ],
      ),
    );
  }

  Widget relatedItemShimmer() {
    return SizedBox(
        height: 200,
        child: ListView.builder(
            itemCount: 5,
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(
              horizontal: sidePadding,
            ),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: index == 0 ? 0 : 8),
                child: const CustomShimmer(
                  height: 200,
                  width: 300,
                ),
              );
            }));
  }

  Widget createFeaturesAds() {
    if (model.status == "active" || model.status == "approved") {
      return MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => CreateFeaturedAdCubit(),
          ),
          BlocProvider(
            create: (context) => FetchUserPackageLimitCubit(),
          ),
        ],
        child: Builder(builder: (context) {
          return BlocListener<CreateFeaturedAdCubit, CreateFeaturedAdState>(
            listener: (context, state) {
              if (state is CreateFeaturedAdInSuccess) {
                HelperUtils.showSnackBarMessage(
                    context, state.responseMessage.toString(),
                    messageDuration: 3);

                Navigator.pop(context, "refresh");
              }
              if (state is CreateFeaturedAdFailure) {
                HelperUtils.showSnackBarMessage(context, state.error.toString(),
                    messageDuration: 3);
              }
            },
            child: BlocListener<FetchUserPackageLimitCubit,
                FetchUserPackageLimitState>(
              listener: (context, state) async {
                if (state is FetchUserPackageLimitFailure) {
                  UiUtils.noPackageAvailableDialog(context);
                }
                if (state is FetchUserPackageLimitInSuccess) {
                  await UiUtils.showBlurredDialoge(
                    context,
                    dialoge: BlurredDialogBox(
                        title: "createFeaturedAd".translate(context),
                        content: Text(
                          "areYouSureToCreateThisItemAsAFeaturedAd"
                              .translate(context),
                        ),
                        isAcceptContainesPush: true,
                        onAccept: () => Future.value().then((_) {
                              Future.delayed(
                                Duration.zero,
                                () {
                                  context
                                      .read<CreateFeaturedAdCubit>()
                                      .createFeaturedAds(
                                        itemId: model.id!,
                                      );
                                  Navigator.pop(context);
                                  return;
                                },
                              );
                            })),
                  );
                }
              },
              child: AnimatedCrossFade(
                duration: Duration(milliseconds: 500),
                crossFadeState: isFeaturedWidget
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  padding: const EdgeInsets.all(12),
                  //height: 116,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: context.color.territoryColor.withValues(alpha: 0.1),
                    border:
                        Border.all(color: context.color.borderColor.darken(30)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 12),
                        child: SvgPicture.asset(
                          AppIcons.createAddIcon,
                          height: 74,
                          width: 62,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${"featureYourAdsAttractMore".translate(context)}\n${"clientsAndSellFaster".translate(context)}",
                              style: TextStyle(
                                color: context.color.textDefaultColor
                                    .withValues(alpha: 0.7),
                                fontSize: context.font.large,
                              ),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () {
                                context
                                    .read<FetchUserPackageLimitCubit>()
                                    .fetchUserPackageLimit(
                                        packageType: "advertisement");
                              },
                              child: Container(
                                height: 33,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: context.color.territoryColor,
                                ),
                                child: Text(
                                  "createFeaturedAd".translate(context),
                                  style: TextStyle(
                                    color: context.color.secondaryColor,
                                    fontSize: context.font.small,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                secondChild: SizedBox.shrink(),
              ),
            ),
          );
        }),
      );
    } else {
      return SizedBox.shrink();
    }
  }

  Widget customFields() {
    if (model.customFields == null || model.customFields!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Wrap(
        children: [
          ...List.generate(model.customFields!.length, (index) {
            final field = model.customFields![index];
            if (field.value != null && field.value!.isNotEmpty) {
              if (field.type != "textbox") {
                return SizedBox(
                  width: (context.screenWidth / 2) - (sidePadding / 2) - 5,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 33,
                        width: 33,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: UiUtils.imageType(field.image ?? "",
                              fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tooltip(
                              message: field.name ?? "",
                              child: Text(field.name ?? "")
                                  .setMaxLines(lines: 1)
                                  .size(context.font.small)
                                  .color(context.color.textDefaultColor
                                      .withValues(alpha: 0.5)),
                            ),
                            valueContent(field.value),
                            const SizedBox(
                              height: 12,
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                return const SizedBox.shrink();
              }
            } else {
              return const SizedBox.shrink();
            }
          }),
          ...List.generate(model.customFields!.length, (index) {
            final field = model.customFields![index];
            if (field.value != null && field.value!.isNotEmpty) {
              if (field.type == "textbox") {
                return SizedBox(
                  width: (context.screenWidth / 2) - (sidePadding / 2) - 5,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 33,
                        width: 33,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: UiUtils.imageType(field.image ?? "",
                              fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Tooltip(
                            message: field.name ?? "",
                            child: Text(field.name ?? "")
                                .setMaxLines(lines: 1)
                                .size(context.font.small)
                                .color(context.color.textDefaultColor
                                    .withValues(alpha: 0.5)),
                          ),
                          valueContent(field.value),
                          const SizedBox(
                            height: 12,
                          )
                        ],
                      )),
                    ],
                  ),
                );
              } else {
                return const SizedBox.shrink();
              }
            } else {
              return const SizedBox.shrink();
            }
          })
        ],
      ),
    );
  }

  Widget valueContent(List<dynamic>? value) {
    if (value == null || value.isEmpty || value[0] == null) {
      return const SizedBox.shrink();
    }
    String valStr = value[0].toString();
    if (valStr.startsWith("http://") || valStr.startsWith("https://")) {
      if (valStr.toLowerCase().endsWith(".pdf")) {
        // Render PDF link as clickable text
        return GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, Routes.pdfViewerScreen,
                  arguments: {"url": valStr});
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 5.0),
              child: UiUtils.getSvg(AppIcons.pdfIcon,
                  color: context.color.textColorDark),
            ));
      } else if (valStr.toLowerCase().endsWith(".png") ||
          valStr.toLowerCase().endsWith(".jpg") ||
          valStr.toLowerCase().endsWith(".jpeg") ||
          valStr.toLowerCase().endsWith(".svg")) {
        // Render image
        return InkWell(
          onTap: () {
            UiUtils.showFullScreenImage(
              context,
              provider: NetworkImage(
                valStr,
              ),
            );
          },
          child: Container(
              width: 50,
              height: 50,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: context.color.territoryColor.withValues(alpha: 0.1)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: UiUtils.imageType(
                  valStr,
                  color: context.color.territoryColor,
                  fit: BoxFit.cover,
                ),
              )),
        );
      }
    }

    // Default text if not a supported format or not a URL
    return Text(
      value.length == 1
          ? valStr
          : value.map((e) => e?.toString() ?? '').join(','),
    ).color(context.color.textDefaultColor);
  }

  Widget itemData(
      int index, SubscriptionPackageModel model, StateSetter stateSetter) {
    return Padding(
      padding: const EdgeInsets.only(top: 7.0),
      child: Stack(
        alignment: Alignment.topLeft,
        children: [
          if (model.isActive!)
            Padding(
              padding: EdgeInsetsDirectional.only(start: 13.0),
              child: ClipPath(
                clipper: CapShapeClipper(),
                child: Container(
                  color: context.color.territoryColor,
                  width: MediaQuery.of(context).size.width / 3,
                  height: 17,
                  padding: EdgeInsets.only(top: 3),
                  child: Text('activePlanLbl'.translate(context))
                      .color(context.color.secondaryColor)
                      .centerAlign()
                      .bold(weight: FontWeight.w500)
                      .size(12),
                ),
              ),
            ),
          InkWell(
            onTap: () {
              _selectedPackageIndex = index;
              stateSetter(() {});
              setState(() {});
            },
            child: Container(
              margin: EdgeInsets.only(top: 17),
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(
                      color: index == _selectedPackageIndex
                          ? context.color.territoryColor
                          : context.color.textDefaultColor
                              .withValues(alpha: 0.1),
                      width: 1.5)),
              child:
                  !model.isActive! ? adsWidget(model) : activeAdsWidget(model),
            ),
          ),
        ],
      ),
    );
  }

  Widget adsWidget(SubscriptionPackageModel model) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(model.name!)
                  .firstUpperCaseWidget()
                  .bold(weight: FontWeight.w600)
                  .size(context.font.large),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${model.limit == "unlimited" ? "unlimitedLbl".translate(context) : model.limit.toString()}\t${"adsLbl".translate(context)}\t\t·\t\t',
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                  ).color(
                      context.color.textDefaultColor.withValues(alpha: 0.5)),
                  Flexible(
                    child: Text(
                      '${model.duration.toString()}\t${"days".translate(context)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ).color(
                        context.color.textDefaultColor.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsetsDirectional.only(start: 10.0),
          child: Text(
            model.finalPrice! > 0
                ? "${Constant.currencySymbol}${model.finalPrice.toString()}"
                : "free".translate(context),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget activeAdsWidget(SubscriptionPackageModel model) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(model.name!)
                  .firstUpperCaseWidget()
                  .bold(weight: FontWeight.w600)
                  .size(context.font.large),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: model.limit == "unlimited"
                          ? "${"unlimitedLbl".translate(context)}\t${"adsLbl".translate(context)}\t\t·\t\t"
                          : '',
                      style: TextStyle(
                        color: context.color.textDefaultColor
                            .withValues(alpha: 0.5),
                      ),
                      children: [
                        if (model.limit != "unlimited")
                          TextSpan(
                            text:
                                '${model.userPurchasedPackages![0].remainingItemLimit}',
                            style: TextStyle(
                                color: context.color.textDefaultColor),
                          ),
                        if (model.limit != "unlimited")
                          TextSpan(
                            text:
                                '/${model.limit.toString()}\t${"adsLbl".translate(context)}\t\t·\t\t',
                          ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                  ),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        text: model.duration == "unlimited"
                            ? "${"unlimitedLbl".translate(context)}\t${"days".translate(context)}"
                            : '',
                        style: TextStyle(
                          color: context.color.textDefaultColor
                              .withValues(alpha: 0.5),
                        ),
                        children: [
                          if (model.duration != "unlimited")
                            TextSpan(
                              text:
                                  '${model.userPurchasedPackages![0].remainingDays}',
                              style: TextStyle(
                                  color: context.color.textDefaultColor),
                            ),
                          if (model.duration != "unlimited")
                            TextSpan(
                              text:
                                  '/${model.duration.toString()}\t${"days".translate(context)}',
                            ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsetsDirectional.only(start: 10.0),
          child: Text(
            model.finalPrice! > 0
                ? "${Constant.currencySymbol}${model.finalPrice.toString()}"
                : "free".translate(context),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

/*  void selectPackageDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: true,

      // Set to false if you don't want the dialog to close by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: context.color.secondaryColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Center(child: Text("selectPackage".translate(context))),
          content: packageList(),
        );
      },
    );
  }*/

  void showPackageSelectBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.color.secondaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(15.0),
          topRight: Radius.circular(15.0),
        ),
      ),
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(maxHeight: context.screenHeight * 0.85),
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(15),
              topRight: Radius.circular(15),
            ),
          ),
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
                padding: EdgeInsets.symmetric(vertical: 17, horizontal: 20),
                child: Text(
                  'selectPackage'.translate(context),
                  textAlign: TextAlign.start,
                ).bold(weight: FontWeight.bold).size(context.font.large),
              ),

              Divider(height: 1), // Add some space between title and options
              Expanded(child: packageList()),
            ],
          ),
        );
      },
    );
  }

  Widget packageList() {
    return BlocBuilder<FetchAdsListingSubscriptionPackagesCubit,
        FetchAdsListingSubscriptionPackagesState>(
      builder: (context, state) {
        print("state package***$state");
        if (state is FetchAdsListingSubscriptionPackagesInProgress) {
          return Center(
            child: UiUtils.progress(),
          );
        }
        if (state is FetchAdsListingSubscriptionPackagesFailure) {
          if (state.errorMessage is ApiException) {
            if (state.errorMessage == "no-internet") {
              return NoInternet(
                onRetry: () {
                  context
                      .read<FetchAdsListingSubscriptionPackagesCubit>()
                      .fetchPackages();
                },
              );
            }
          }

          return const SomethingWentWrong();
        }
        if (state is FetchAdsListingSubscriptionPackagesSuccess) {
          print(
              "subscription plan list***${state.subscriptionPackages.length}");
          if (state.subscriptionPackages.isEmpty) {
            return NoDataFound(
              onTap: () {
                context
                    .read<FetchAdsListingSubscriptionPackagesCubit>()
                    .fetchPackages();
              },
            );
          }

          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setStater) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.symmetric(horizontal: 18),
                      itemBuilder: (context, index) {
                        return itemData(index,
                            state.subscriptionPackages[index], setStater);
                      },
                      itemCount: state.subscriptionPackages.length),
                ),
                Builder(builder: (context) {
                  return BlocListener<RenewItemCubit, RenewItemState>(
                    listener: (context, changeState) {
                      if (changeState is RenewItemInSuccess) {
                        HelperUtils.showSnackBarMessage(
                            context, changeState.responseMessage);
                        Future.delayed(Duration.zero, () {
                          Navigator.pop(context);
                          Navigator.pop(context, "refresh");
                        });
                      } else if (changeState is RenewItemFailure) {
                        Navigator.pop(context);
                        HelperUtils.showSnackBarMessage(
                            context, changeState.error);
                      }
                    },
                    child: UiUtils.buildButton(context, onPressed: () {
                      if (state.subscriptionPackages[_selectedPackageIndex!]
                          .isActive!) {
                        Future.delayed(Duration.zero, () {
                          context.read<RenewItemCubit>().renewItem(
                              packageId: state
                                  .subscriptionPackages[_selectedPackageIndex!]
                                  .id!,
                              itemId: model.id!);
                        });
                      } else {
                        Navigator.pop(context);
                        HelperUtils.showSnackBarMessage(context,
                            "pleasePurchasePackage".translate(context));
                        Navigator.pushNamed(
                            context, Routes.subscriptionPackageListRoute);
                      }
                    },
                        radius: 10,
                        height: 46,
                        disabled: _selectedPackageIndex == null,
                        disabledColor:
                            context.color.textLightColor.withValues(alpha: 0.3),
                        fontSize: context.font.large,
                        buttonColor: context.color.territoryColor,
                        textColor: context.color.secondaryColor,
                        buttonTitle: "renewItem".translate(context),
                        outerPadding: const EdgeInsets.all(20)),
                  );
                })
              ],
            );
          });
        }

        return Container();
      },
    );
  }

  bool _isPaymentPendingStatus(String status) {
    final normalized = status.trim().toLowerCase().replaceAll('_', ' ');
    return normalized == 'pending payment' || normalized == 'pending';
  }

  String _editStatusFor(ItemModel item) {
    final routedStatus = widget.editStatus?.trim() ?? '';
    if (routedStatus.isNotEmpty) return routedStatus;
    final currentStatus = item.status?.trim() ?? '';
    if (currentStatus.isNotEmpty) return currentStatus;
    final initialStatus = widget.model.status?.trim() ?? '';
    if (initialStatus.isNotEmpty) return initialStatus;

    // Unpaid owned ads can be returned with a blank status until a package is
    // assigned. Preserve that flow when editing directly from Ad Details.
    return isAddedByMe ? 'pending payment' : '';
  }

  Future<void> _navigateToEditAd(BuildContext context, ItemModel item) async {
    final editStatus = _editStatusFor(item);
    Widgets.showLoader(context);
    ItemModel fullItem = item;
    try {
      // Keep this identical to the My Ads popup: get-item must be ID-only so
      // the API returns saved values such as Bedrooms for nested categories.
      final res = await ItemRepository().fetchItemFromItemId(item.id!);
      if (res.modelList.isNotEmpty) {
        fullItem = res.modelList.first;
        if ((fullItem.image ?? '').trim().isEmpty) {
          fullItem.image = item.image;
        }
        if ((fullItem.status ?? '').trim().isEmpty) {
          fullItem.status = editStatus;
        }
        if ((fullItem.galleryImages == null ||
                fullItem.galleryImages!.isEmpty) &&
            item.galleryImages != null) {
          fullItem.galleryImages = item.galleryImages;
        }
      }
    } catch (e) {
      log("⚠️ [EDIT AD FETCH ERROR]: $e");
    } finally {
      Widgets.hideLoder(context);
    }

    if (!context.mounted) return;

    fullItem.status = editStatus;
    addCloudData("edit_request", fullItem);
    addCloudData("edit_from", editStatus);

    final allCategoryIds =
        fullItem.allCategoryIds ?? "${fullItem.categoryId ?? ''}";
    final catIdList = allCategoryIds.split(',').map((e) => e.trim()).toList();
    final catSlug = (fullItem.category?.slug ?? '').toLowerCase();
    final catName = (fullItem.category?.name ?? '').toLowerCase();

    // Check if Car
    final isCar = fullItem.carMake != null ||
        fullItem.carMakeName != null ||
        catIdList.contains('5') ||
        catIdList.contains('6') ||
        catSlug.contains('car') ||
        catName.contains('car');

    // Check if Property
    final isProperty = fullItem.isPropertyCategory;

    // Check if Motor (non-car)
    final isMotor = !isCar && fullItem.isMotorsCategory;

    final breadcrumbs =
        fullItem.category != null ? [fullItem.category!] : <CategoryModel>[];

    final routeName = isCar
        ? Routes.carSpecsFormScreen
        : isProperty
            ? Routes.propertyPostingFormScreen
            : isMotor
                ? Routes.motorPostingFormScreen
                : Routes.classifiedsPostingFormScreen;
    final editResult = await Navigator.pushNamed(
      context,
      routeName,
      arguments: {
        'category': fullItem.category,
        'breadcrumbs': breadcrumbs,
        'item': fullItem,
        'isEdit': true,
        'customFields': fullItem.customFields,
      },
    );

    if (!context.mounted || editResult == null) return;
    if (editResult is ItemModel) {
      editResult.status = editStatus;
      if (_isPaymentPendingStatus(editStatus)) {
        final paidItem = await Navigator.pushNamed(
          context,
          Routes.carPackagePaymentScreen,
          arguments: {
            'model': editResult,
            'isEdit': true,
          },
        );
        if (paidItem is ItemModel) {
          editResult.status = "approved";
          editResult.active = true;
        }
        if (context.mounted) Navigator.pop(context, "refresh");
        return;
      }
    }

    if (context.mounted) Navigator.pop(context, "refresh");
  }

  Widget _buildPaymentPendingOwnerActions(ItemModel item) {
    return Row(
      children: [
        Expanded(
          child: _buildButton('editBtnLbl'.translate(context), () {
            _navigateToEditAd(context, item);
          }, context.color.secondaryColor, context.color.territoryColor),
        ),
        SizedBox(width: 10.rw(context)),
        Expanded(
          child: _buildButton('Pay & Activate', () {
            Navigator.pushNamed(
              context,
              Routes.carPackagePaymentScreen,
              arguments: {
                'model': item,
                'isEdit': true,
              },
            );
          }, null, null),
        ),
      ],
    );
  }

  Widget bottomButtonWidget() {
    if (isAddedByMe) {
      final model = this.model;
      final contextColor = context.color;
      final editStatus = _editStatusFor(model);
      if (_isPaymentPendingStatus(editStatus)) {
        model.status = editStatus;
        return _buildPaymentPendingOwnerActions(model);
      }

      if (model.status == "review") {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildButton("editBtnLbl".translate(context), () {
                _navigateToEditAd(context, model);
              }, contextColor.secondaryColor, contextColor.territoryColor),
            ),
            SizedBox(width: 10.rw(context)),
            BlocProvider(
              create: (context) => DeleteItemCubit(),
              child: Builder(builder: (context) {
                return BlocListener<DeleteItemCubit, DeleteItemState>(
                  listener: (context, deleteState) {
                    if (deleteState is DeleteItemSuccess) {
                      HelperUtils.showSnackBarMessage(
                          context, "deleteItemSuccessMsg".translate(context));
                      context.read<FetchMyItemsCubit>().deleteItem(model);
                      Navigator.pop(context, "refresh");
                    } else if (deleteState is DeleteItemFailure) {
                      HelperUtils.showSnackBarMessage(
                          context, deleteState.errorMessage);
                    }
                  },
                  child: Expanded(
                    child: _buildButton("lblremove".translate(context), () {
                      Future.delayed(
                        Duration.zero,
                        () {
                          /*  if (Constant.isDemoModeOn) {
                            HelperUtils.showSnackBarMessage(
                                context,
                                UiUtils.getTranslatedLabel(
                                    context, "thisActionNotValidDemo"));
                            return;
                          }*/
                          context.read<DeleteItemCubit>().deleteItem(model.id!);
                        },
                      );
                    }, null, null),
                  ),
                );
              }),
            ),
          ],
        );
      } else if (model.status == "active" || model.status == "approved") {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildButton("editBtnLbl".translate(context), () {
                _navigateToEditAd(context, model);
              }, contextColor.secondaryColor, contextColor.territoryColor),
            ),
            SizedBox(width: 10.rw(context)),
            Expanded(
              child: _buildButton("soldOut".translate(context), () async {
                Navigator.pushNamed(context, Routes.soldOutBoughtScreen,
                    arguments: {
                      "itemId": model.id,
                      "price": model.price,
                      "itemName": model.name,
                      "itemImage": model.image
                    });
              }, null, null),
            ),
          ],
        );
      } else if (model.status == "sold out" ||
          model.status == "inactive" ||
          model.status == "rejected") {
        return BlocProvider(
          create: (context) => DeleteItemCubit(),
          child: Builder(builder: (context) {
            return BlocListener<DeleteItemCubit, DeleteItemState>(
              listener: (context, deleteState) {
                if (deleteState is DeleteItemSuccess) {
                  HelperUtils.showSnackBarMessage(
                      context, "deleteItemSuccessMsg".translate(context));

                  context.read<FetchMyItemsCubit>().deleteItem(model);
                  Navigator.pop(context, "refresh");
                } else if (deleteState is DeleteItemFailure) {
                  HelperUtils.showSnackBarMessage(
                      context, deleteState.errorMessage);
                }
              },
              child: _buildButton("lblremove".translate(context), () {
                Future.delayed(
                  Duration.zero,
                  () {
                    context.read<DeleteItemCubit>().deleteItem(model.id!);
                  },
                );
              }, null, null),
            );
          }),
        );
      } else if (model.status == "expired") {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildButton("renew".translate(context), () {
                // selectPackageDialog();
                showPackageSelectBottomSheet();
              }, contextColor.secondaryColor, contextColor.territoryColor),
            ),
            SizedBox(width: 10.rw(context)),
            BlocProvider(
              create: (context) => DeleteItemCubit(),
              child: Builder(builder: (context) {
                return BlocListener<DeleteItemCubit, DeleteItemState>(
                  listener: (context, deleteState) {
                    if (deleteState is DeleteItemSuccess) {
                      HelperUtils.showSnackBarMessage(
                          context, "deleteItemSuccessMsg".translate(context));
                      context.read<FetchMyItemsCubit>().deleteItem(model);
                      Navigator.pop(context, "refresh");
                    } else if (deleteState is DeleteItemFailure) {
                      HelperUtils.showSnackBarMessage(
                          context, deleteState.errorMessage);
                    }
                  },
                  child: Expanded(
                    child: _buildButton("lblremove".translate(context), () {
                      Future.delayed(
                        Duration.zero,
                        () {
                          context.read<DeleteItemCubit>().deleteItem(model.id!);
                        },
                      );
                    }, null, null),
                  ),
                );
              }),
            ),
          ],
        );
      } else {
        return const SizedBox();
      }
    } else {
      return _buildBottomContactButtons();
    }
  }

  bool _isJobAd() {
    if (model.isJobsCategory || widget.model.isJobsCategory) return true;
    final allCategoryIds =
        model.allCategoryIds ?? widget.model.allCategoryIds ?? '';
    final catIdList = allCategoryIds.split(',').map((e) => e.trim()).toList();
    final catId = model.categoryId ?? widget.model.categoryId;
    final catSlug = (model.category?.slug ?? widget.model.category?.slug ?? '')
        .toLowerCase();
    final catName = (model.category?.name ?? widget.model.category?.name ?? '')
        .toLowerCase();

    return catIdList.contains('4') ||
        catIdList.contains('356') ||
        catIdList.contains('357') ||
        catId == 4 ||
        catId == 356 ||
        catId == 357 ||
        catSlug.contains('job') ||
        catName.contains('job');
  }

  bool _isHireTalentAd() {
    final allCategoryIds =
        model.allCategoryIds ?? widget.model.allCategoryIds ?? '';
    final catIdList = allCategoryIds.split(',').map((e) => e.trim()).toList();
    final catId = model.categoryId ?? widget.model.categoryId;
    final catSlug = (model.category?.slug ?? widget.model.category?.slug ?? '')
        .toLowerCase();
    final catName = (model.category?.name ?? widget.model.category?.name ?? '')
        .toLowerCase();

    return catIdList.contains('357') ||
        catId == 357 ||
        catSlug.contains('recruit') ||
        catName.contains('recruit') ||
        catSlug.contains('hire') ||
        catName.contains('hire');
  }

  bool _isPropertyAd() {
    if (_isJobAd()) return false;
    if (model.isPropertyCategory || widget.model.isPropertyCategory) {
      return true;
    }
    final catSlug = (model.category?.slug ?? widget.model.category?.slug ?? '')
        .toLowerCase();
    final catName = (model.category?.name ?? widget.model.category?.name ?? '')
        .toLowerCase();

    if (catSlug.contains('property') ||
        catSlug.contains('rent') ||
        catSlug.contains('residential') ||
        catSlug.contains('commercial') ||
        catName.contains('property') ||
        catName.contains('rent') ||
        (catName.contains('sale') &&
            !catSlug.contains('car') &&
            !catSlug.contains('motor'))) {
      return true;
    }
    return false;
  }

  bool _isMotorsAd() {
    if (_isJobAd() || _isPropertyAd()) return false;
    if (model.isMotorsCategory || widget.model.isMotorsCategory) return true;
    final catSlug = (model.category?.slug ?? widget.model.category?.slug ?? '')
        .toLowerCase();
    final catName = (model.category?.name ?? widget.model.category?.name ?? '')
        .toLowerCase();

    if (catSlug.contains('motor') ||
        catSlug.contains('car') ||
        catSlug.contains('auto') ||
        catSlug.contains('vehicle') ||
        catSlug.contains('bike') ||
        catName.contains('motor') ||
        catName.contains('car') ||
        catName.contains('vehicle') ||
        catName.contains('bike') ||
        model.customFields?.any((f) =>
                f.name?.toLowerCase().contains('kilometer') == true ||
                f.name?.toLowerCase().contains('engine') == true) ==
            true) {
      return true;
    }
    return false;
  }

  void _showCandidateDetailsAndCvModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final fields = model.customFields ?? [];
        final phone = model.contact ?? model.user?.mobile;
        final isPhoneHidden = model.hidePhoneNumber == true;

        // Detect candidate's CV file URL
        String? cvUrl;
        for (var f in fields) {
          final fName = (f.name ?? "").toLowerCase();
          if (fName.contains("cv") ||
              fName.contains("resume") ||
              f.type == "fileinput") {
            if (f.value != null && f.value!.isNotEmpty) {
              final raw = f.value!.first.toString();
              if (raw.isNotEmpty) {
                cvUrl = raw;
                break;
              }
            }
          }
        }
        if (cvUrl == null || cvUrl.isEmpty) {
          cvUrl = model.user?.resume;
        }

        // Filter out CV upload / fileinput fields from attribute chips
        final nonCvFields = fields.where((f) {
          if (f.value == null || f.value!.isEmpty) return false;
          final fName = (f.name ?? "").toLowerCase();
          if (fName.contains("cv") ||
              fName.contains("resume") ||
              f.type == "fileinput") {
            return false;
          }
          final val =
              (f.value is List) ? f.value!.join(', ') : f.value.toString();
          if (val.startsWith("http") &&
              (val.endsWith(".jpg") ||
                  val.endsWith(".png") ||
                  val.endsWith(".pdf") ||
                  val.endsWith(".docx") ||
                  val.endsWith(".doc"))) {
            return false;
          }
          return true;
        }).toList();

        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: model.user?.profile != null &&
                                model.user!.profile!.isNotEmpty
                            ? UiUtils.getImage(model.user!.profile!,
                                fit: BoxFit.cover)
                            : const Icon(Icons.person,
                                color: Color(0xFF1E88E5), size: 28),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            model.name ??
                                model.user?.name ??
                                "Candidate Profile",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: context.color.textDefaultColor,
                            ),
                          ),
                          if (model.category?.name != null)
                            Text(
                              model.category!.name!,
                              style: TextStyle(
                                fontSize: 13,
                                color: context.color.textLightColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 10),

                // Candidate CV / Resume Card
                if (cvUrl != null && cvUrl.isNotEmpty) ...[
                  Text(
                    "Candidate Resume / CV",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.color.secondaryColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF1E88E5).withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF1E88E5).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Icon(
                              cvUrl.toLowerCase().endsWith('.pdf')
                                  ? Icons.picture_as_pdf_rounded
                                  : cvUrl.toLowerCase().endsWith('.doc') ||
                                          cvUrl.toLowerCase().endsWith('.docx')
                                      ? Icons.description_rounded
                                      : Icons.insert_drive_file_rounded,
                              color: const Color(0xFF1E88E5),
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cvUrl.split('/').last.split('?').first,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: context.color.textDefaultColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                cvUrl.toLowerCase().endsWith('.pdf')
                                    ? "PDF Document"
                                    : cvUrl.toLowerCase().endsWith('.docx') ||
                                            cvUrl.toLowerCase().endsWith('.doc')
                                        ? "Word Document"
                                        : "Attached CV File",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: context.color.textLightColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E88E5),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () async {
                            final uri = Uri.parse(cvUrl!);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            } else {
                              HelperUtils.showSnackBarMessage(
                                context,
                                "Cannot open CV file",
                                type: MessageType.error,
                              );
                            }
                          },
                          icon: const Icon(Icons.download_rounded,
                              size: 16, color: Colors.white),
                          label: const Text(
                            "View / Download",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                if (nonCvFields.isNotEmpty) ...[
                  Text(
                    "Candidate Qualifications & Details",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: nonCvFields.map((f) {
                      final val = (f.value is List)
                          ? f.value!.join(', ')
                          : f.value.toString();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: context.color.secondaryColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: context.color.borderColor
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        child: Text(
                          "${f.label ?? f.name ?? 'Info'}: $val",
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: context.color.textDefaultColor,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                ],

                if (model.description != null &&
                    model.description!.trim().isNotEmpty) ...[
                  Text(
                    "Summary & Experience",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    model.description!,
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          context.color.textDefaultColor.withValues(alpha: 0.8),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                const Divider(),
                const SizedBox(height: 10),

                Row(
                  children: [
                    if (!isPhoneHidden &&
                        phone != null &&
                        phone.trim().isNotEmpty) ...[
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFEF2F2),
                              foregroundColor: const Color(0xFFDC2626),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side:
                                    const BorderSide(color: Color(0xFFFEE2E2)),
                              ),
                            ),
                            onPressed: () {
                              SellerContactBottomSheet.show(context,
                                  model: model);
                            },
                            icon: const Icon(Icons.phone_outlined,
                                size: 18, color: Color(0xFFDC2626)),
                            label: const Text(
                              "Call",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E88E5),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            InquireAdBottomSheet.show(context, model: model);
                          },
                          icon: const Icon(Icons.mail_outline_rounded,
                              size: 18, color: Colors.white),
                          label: const Text(
                            "Contact / Inquire",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomContactButtons() {
    final isPhoneHidden =
        model.hidePhoneNumber == true || widget.model.hidePhoneNumber == true;
    final phone = model.sellerPhone ?? widget.model.sellerPhone;
    final canShowPhoneActions =
        !isPhoneHidden && phone != null && phone.trim().isNotEmpty;

    // 0. Jobs Actions (Apply or See CV)
    if (_isJobAd()) {
      final applicationStatus = widget.jobApplicationStatus?.trim();
      if (applicationStatus != null && applicationStatus.isNotEmpty) {
        final normalizedStatus = applicationStatus.toLowerCase();
        final isRejected = normalizedStatus.contains('reject');
        final isReview = normalizedStatus.contains('review') ||
            normalizedStatus.contains('pending');
        final statusColor = isRejected
            ? Colors.red
            : isReview
                ? Colors.blue.shade700
                : Colors.green.shade700;

        return Container(
          width: double.infinity,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.work_history_outlined, size: 19, color: statusColor),
              const SizedBox(width: 8),
              Text(
                'Application status: $applicationStatus',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }

      if (_isHireTalentAd()) {
        return SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => _showCandidateDetailsAndCvModal(context),
            icon: const Icon(Icons.description_outlined,
                size: 20, color: Colors.white),
            label: const Text(
              "See all detail and CV of this candidate",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                color: Colors.white,
              ),
            ),
          ),
        );
      } else {
        return SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD31027),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              UiUtils.checkUser(
                onNotGuest: () {
                  Navigator.pushNamed(
                    context,
                    Routes.jobApplyFormScreen,
                    arguments: {
                      'itemId': model.id ?? widget.model.id,
                      'itemTitle': model.name ?? widget.model.name ?? '',
                      'categoryName': model.category?.name ?? '',
                      'customFields':
                          model.customFields ?? widget.model.customFields,
                    },
                  );
                },
                context: context,
              );
            },
            icon: const Icon(Icons.assignment_turned_in_outlined,
                size: 20, color: Colors.white),
            label: const Text(
              "Apply",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        );
      }
    }

    // 1. Inquiry Button (Email)
    Widget buildInquiryButton() {
      return Expanded(
        child: SizedBox(
          height: 42,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEFF6FF),
              foregroundColor: const Color(0xFF2563EB),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(
                  color: Color(0xFFDBEAFE),
                  width: 1,
                ),
              ),
            ),
            onPressed: () {
              InquireAdBottomSheet.show(context, model: model);
            },
            icon: const Icon(
              Icons.mail_outline_rounded,
              color: Color(0xFF2563EB),
              size: 16,
            ),
            label: Text(
              "Inquiry".translate(context),
              style: const TextStyle(
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }

    // 2. Call Button
    Widget buildCallButton() {
      return Expanded(
        child: SizedBox(
          height: 42,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFEF2F2),
              foregroundColor: const Color(0xFFDC2626),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(
                  color: Color(0xFFFEE2E2),
                  width: 1,
                ),
              ),
            ),
            onPressed: () {
              SellerContactBottomSheet.show(context, model: model);
            },
            icon: const Icon(
              Icons.phone_outlined,
              color: Color(0xFFDC2626),
              size: 16,
            ),
            label: Text(
              "Call".translate(context),
              style: const TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }

    // 3. WhatsApp Button
    Widget buildWhatsAppButton() {
      return Expanded(
        child: SizedBox(
          height: 42,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF0FDF4),
              foregroundColor: const Color(0xFF16A34A),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(
                  color: Color(0xFFDCFCE7),
                  width: 1,
                ),
              ),
            ),
            onPressed: () async {
              if (isPhoneHidden) {
                HelperUtils.showSnackBarMessage(
                  context,
                  "Phone number is hidden by seller",
                );
                return;
              }
              if (phone == null || phone.trim().isEmpty) {
                HelperUtils.showSnackBarMessage(
                  context,
                  "Seller WhatsApp number not available",
                );
                return;
              }

              String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
              final message =
                  "Hi, I am interested in your ad '${model.name ?? ''}' on ${Constant.appName}.";
              final whatsappApiUrl = Uri.parse(
                  "https://api.whatsapp.com/send?phone=$cleanPhone&text=${Uri.encodeComponent(message)}");

              try {
                if (await canLaunchUrl(whatsappApiUrl)) {
                  await launchUrl(whatsappApiUrl,
                      mode: LaunchMode.externalApplication);
                } else {
                  final fallbackUrl = Uri.parse(
                      "https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");
                  if (await canLaunchUrl(fallbackUrl)) {
                    await launchUrl(fallbackUrl,
                        mode: LaunchMode.externalApplication);
                  } else {
                    HelperUtils.showSnackBarMessage(
                      context,
                      "WhatsApp is not installed",
                    );
                  }
                }
              } catch (e) {
                HelperUtils.showSnackBarMessage(
                  context,
                  "Could not open WhatsApp: $e",
                );
              }
            },
            icon: const Icon(
              Icons.chat_outlined,
              color: Color(0xFF16A34A),
              size: 16,
            ),
            label: const Text(
              "WhatsApp",
              style: TextStyle(
                color: Color(0xFF16A34A),
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
              ),
            ),
          ),
        ),
      );
    }

    // 4. Chat Button
    Widget buildChatButton() {
      return Expanded(
        child: SizedBox(
          height: 42,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF5F3FF),
              foregroundColor: const Color(0xFF7C3AED),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(
                  color: Color(0xFFEDE9FE),
                  width: 1,
                ),
              ),
            ),
            onPressed: () {
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
                              profilePicture: model.user?.profile ?? "",
                              itemTitle: model.name ?? "",
                              userId: model.user?.id?.toString() ??
                                  model.userId?.toString() ??
                                  "",
                              itemImage: model.image ?? "",
                              userName: model.user?.name ?? "",
                              itemId: model.id?.toString() ?? "",
                              date: model.created ?? "",
                              from: "item",
                              itemOfferId: 0,
                              itemPrice: model.price ?? 0.0,
                              itemOfferPrice: null,
                              status: model.status,
                              buyerId: HiveUtils.getUserId(),
                              alreadyReview: false,
                              isPurchased: model.isPurchased ?? 0,
                            );
                          }),
                        );
                      },
                    ),
                  );
                },
                context: context,
              );
            },
            icon: const Icon(
              Icons.forum_outlined,
              color: Color(0xFF7C3AED),
              size: 16,
            ),
            label: Text(
              "Chat".translate(context),
              style: const TextStyle(
                color: Color(0xFF7C3AED),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }

    final isProp = _isPropertyAd();
    final isMot = _isMotorsAd();

    List<Widget> buttons = [];

    if (isProp) {
      // 1) Properties (Property for Sale, Property for Rent) -> Inquiry, Call, WhatsApp
      buttons = [
        buildInquiryButton(),
        if (canShowPhoneActions) ...[
          const SizedBox(width: 6),
          buildCallButton(),
          const SizedBox(width: 6),
          buildWhatsAppButton(),
        ],
      ];
    } else if (isMot) {
      // 2) Motors -> Chat, plus phone actions when the number is visible.
      buttons = [
        buildChatButton(),
        if (canShowPhoneActions) ...[
          const SizedBox(width: 6),
          buildCallButton(),
          const SizedBox(width: 6),
          buildWhatsAppButton(),
        ],
      ];
    } else if (model.isClassifiedsCategory ||
        widget.model.isClassifiedsCategory) {
      // 3) Classifieds and mobiles -> Chat only
      buttons = [
        buildChatButton(),
      ];
    } else {
      // Unknown/service categories never receive chat implicitly.
      buttons = [
        buildInquiryButton(),
        if (canShowPhoneActions) ...[
          const SizedBox(width: 8),
          buildCallButton(),
          const SizedBox(width: 8),
          buildWhatsAppButton(),
        ],
      ];
    }

    if (buttons.isEmpty) return const SizedBox.shrink();
    return Row(
      children: buttons,
    );
  }

  Widget _buildButton(String title, VoidCallback onPressed, Color? buttonColor,
      Color? textColor) {
    return UiUtils.buildButton(
      context,
      onPressed: onPressed,
      radius: 10,
      height: 46,
      border: buttonColor != null
          ? BorderSide(color: context.color.territoryColor)
          : null,
      buttonColor: buttonColor,
      textColor: textColor,
      buttonTitle: title,
      width: 10.rw(context),
    );
  }

//ImageView
  Widget setImageViewer() {
    return SizedBox(
      height: 320.rh(context),
      width: double.infinity,
      child: Stack(children: [
        PageView.builder(
          itemCount: images.length,
          controller: pageController,
          onPageChanged: (index) {
            setState(() {
              currentPage = index;
            });
          },
          itemBuilder: (context, index) {
            if (index == images.length - 1 &&
                model.videoLink != "" &&
                model.videoLink != null) {
              return Stack(
                children: [
                  // Thumbnail Image
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) {
                            return VideoViewScreen(
                              videoUrl: model.videoLink ?? "",
                              flickManager: flickManager,
                            );
                          },
                        ),
                      );
                    },
                    child: UiUtils.getImage(
                      youtubeVideoThumbnail,
                      fit: BoxFit.cover,
                      height: 320.rh(context),
                      width: double.maxFinite,
                    ),
                  ),
                  // Play Button
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) {
                              return VideoViewScreen(
                                videoUrl: model.videoLink ?? "",
                                flickManager: flickManager,
                              );
                            },
                          ),
                        );
                      },
                      child: Container(
                        color: Colors.transparent,
                        child: Center(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.5),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              // Display image directly without dark shade
              return InkWell(
                child: UiUtils.getImage(
                  images[index]!,
                  fit: BoxFit.cover,
                  height: 320.rh(context),
                  width: double.infinity,
                ),
                onTap: () {
                  UiUtils.imageGallaryView(context,
                      images: images, initalIndex: index);
                },
              );
            }
          },
        ),
        // Top Floating Back Button
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 14,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.arrow_back, color: Colors.black, size: 20),
              ),
            ),
          ),
        ),
        // Top Floating More Button (if added by me)
        if (isAddedByMe)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 14,
            child: MultiBlocProvider(
              providers: [
                BlocProvider(create: (context) => DeleteItemCubit()),
                BlocProvider(create: (context) => ChangeMyItemStatusCubit()),
              ],
              child: Builder(builder: (context) {
                return BlocListener<DeleteItemCubit, DeleteItemState>(
                  listener: (context, deleteState) {
                    if (deleteState is DeleteItemSuccess) {
                      HelperUtils.showSnackBarMessage(
                          context, "deleteItemSuccessMsg".translate(context));
                      context.read<FetchMyItemsCubit>().deleteItem(model);
                      FetchMyPromotedItemsCubit.globalInstance
                          ?.delete(model.id);
                      Navigator.pop(context, "refresh");
                    } else if (deleteState is DeleteItemFailure) {
                      HelperUtils.showSnackBarMessage(
                          context, deleteState.errorMessage);
                    }
                  },
                  child: BlocListener<ChangeMyItemStatusCubit,
                      ChangeMyItemStatusState>(
                    listener: (context, changeState) {
                      if (changeState is ChangeMyItemStatusSuccess) {
                        HelperUtils.showSnackBarMessage(
                            context, changeState.message);
                        Navigator.pop(context, "refresh");
                      } else if (changeState is ChangeMyItemStatusFailure) {
                        HelperUtils.showSnackBarMessage(
                            context, changeState.errorMessage);
                      }
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert,
                            color: Colors.black, size: 20),
                        padding: EdgeInsets.zero,
                        color: context.color.secondaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (val) async {
                          if (val == "edit") {
                            _navigateToEditAd(context, model);
                          } else if (val == "deactivate") {
                            context
                                .read<ChangeMyItemStatusCubit>()
                                .changeMyItemStatus(
                                    id: model.id!, status: 'inactive');
                          } else if (val == "activate") {
                            context
                                .read<ChangeMyItemStatusCubit>()
                                .changeMyItemStatus(
                                    id: model.id!, status: 'active');
                          } else if (val == "sold_out") {
                            context
                                .read<ChangeMyItemStatusCubit>()
                                .changeMyItemStatus(
                                    id: model.id!, status: 'sold out');
                          } else if (val == "pay") {
                            Navigator.pushNamed(
                              context,
                              Routes.carPackagePaymentScreen,
                              arguments: {
                                'model': model,
                                'isEdit': true,
                              },
                            );
                          } else if (val == "renew") {
                            try {
                              final response = await Api.post(
                                url: Api.renewItemApi,
                                parameter: {"item_id": model.id},
                              );
                              if (response['error'] == true) {
                                HelperUtils.showSnackBarMessage(
                                  context,
                                  response['message']?.toString() ??
                                      "Failed to renew ad",
                                  type: MessageType.error,
                                );
                              } else {
                                HelperUtils.showSnackBarMessage(
                                  context,
                                  "Ad renewed successfully!",
                                  type: MessageType.success,
                                );
                                Navigator.pop(context, "refresh");
                              }
                            } catch (e) {
                              HelperUtils.showSnackBarMessage(
                                context,
                                "Failed to renew ad: $e",
                                type: MessageType.error,
                              );
                            }
                          } else if (val == "delete") {
                            var delete = await UiUtils.showBlurredDialoge(
                              context,
                              dialoge: BlurredDialogBox(
                                title: "deleteBtnLbl".translate(context),
                                content: Text(
                                    "deleteitemwarning".translate(context)),
                              ),
                            );
                            if (delete == true) {
                              context
                                  .read<DeleteItemCubit>()
                                  .deleteItem(model.id!);
                            }
                          }
                        },
                        itemBuilder: (context) {
                          final status = (model.status ?? "").toLowerCase();
                          final isLive =
                              status == "active" || status == "approved";
                          final isInactive = status == "inactive";
                          final isSoldOut =
                              status == "sold out" || status == "sold_out";
                          final isPaymentPending =
                              status == "pending payment" ||
                                  status == "payment_pending";
                          final isExpired = status == "expired";

                          return [
                            PopupMenuItem(
                              value: "edit",
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined,
                                      size: 18,
                                      color: context.color.textDefaultColor),
                                  const SizedBox(width: 8),
                                  Text("Edit Ad",
                                      style: TextStyle(
                                          color: context.color.textDefaultColor,
                                          fontSize: 13.5)),
                                ],
                              ),
                            ),
                            if (isLive) ...[
                              PopupMenuItem(
                                value: "deactivate",
                                child: Row(
                                  children: [
                                    Icon(Icons.pause_circle_outline_rounded,
                                        size: 18, color: Colors.amber.shade800),
                                    const SizedBox(width: 8),
                                    Text("Deactivate Ad",
                                        style: TextStyle(
                                            color: Colors.amber.shade800,
                                            fontSize: 13.5)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: "sold_out",
                                child: const Row(
                                  children: [
                                    Icon(Icons.check_circle_outline_rounded,
                                        size: 18, color: Colors.purple),
                                    SizedBox(width: 8),
                                    Text("Mark as Sold Out",
                                        style: TextStyle(
                                            color: Colors.purple,
                                            fontSize: 13.5)),
                                  ],
                                ),
                              ),
                            ],
                            if (isInactive || isSoldOut)
                              PopupMenuItem(
                                value: "activate",
                                child: const Row(
                                  children: [
                                    Icon(Icons.play_circle_outline_rounded,
                                        size: 18, color: Colors.green),
                                    SizedBox(width: 8),
                                    Text("Activate Ad",
                                        style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 13.5)),
                                  ],
                                ),
                              ),
                            if (isPaymentPending)
                              PopupMenuItem(
                                value: "pay",
                                child: const Row(
                                  children: [
                                    Icon(Icons.payment_outlined,
                                        size: 18, color: Color(0xFFD31027)),
                                    SizedBox(width: 8),
                                    Text("Pay & Activate",
                                        style: TextStyle(
                                            color: Color(0xFFD31027),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5)),
                                  ],
                                ),
                              ),
                            if (isExpired)
                              PopupMenuItem(
                                value: "renew",
                                child: Row(
                                  children: [
                                    Icon(Icons.refresh_rounded,
                                        size: 18, color: Colors.amber.shade800),
                                    const SizedBox(width: 8),
                                    Text("Renew Ad",
                                        style: TextStyle(
                                            color: Colors.amber.shade800,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5)),
                                  ],
                                ),
                              ),
                            PopupMenuItem(
                              value: "delete",
                              child: const Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded,
                                      size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text("Delete Ad",
                                      style: TextStyle(
                                          color: Colors.red, fontSize: 13.5)),
                                ],
                              ),
                            ),
                          ];
                        },
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        // Photo Counter Pill
        if (images.isNotEmpty)
          Positioned(
            bottom: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_camera_outlined,
                      color: Colors.white, size: 14),
                  const SizedBox(width: 5),
                  Text(
                    "${currentPage + 1}/${images.length}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Indicator Dots
        Align(
          alignment: AlignmentDirectional.bottomCenter,
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (index) => buildDot(index),
              ),
            ),
          ),
        ),
        if (widget.model.isFeature != null && widget.model.isFeature!)
          Positioned(
            top: MediaQuery.of(context).padding.top + 55,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.color.territoryColor,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text("featured".translate(context))
                  .size(context.font.small)
                  .color(context.color.backgroundColor),
            ),
          ),
        // Floating Action Buttons (Like & Share over the border)
        imageActionButtons(),
      ]),
    );
  }

  Widget imageActionButtons() {
    return Positioned(
      bottom: 10,
      right: 14,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isAddedByMe)
            BlocBuilder<FavoriteCubit, FavoriteState>(
              bloc: context.read<FavoriteCubit>(),
              builder: (context, favState) {
                bool isLike = context.select(
                    (FavoriteCubit cubit) => cubit.isItemFavorite(model.id!));

                return BlocConsumer<UpdateFavoriteCubit, UpdateFavoriteState>(
                  bloc: context.read<UpdateFavoriteCubit>(),
                  listener: (context, state) {
                    if (state is UpdateFavoriteSuccess) {
                      if (state.wasProcess) {
                        context
                            .read<FavoriteCubit>()
                            .addFavoriteitem(state.item);
                      } else {
                        context
                            .read<FavoriteCubit>()
                            .removeFavoriteItem(state.item);
                      }
                    }
                  },
                  builder: (context, state) {
                    return Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          UiUtils.checkUser(
                              onNotGuest: () {
                                if (isLike) {
                                  context
                                      .read<UpdateFavoriteCubit>()
                                      .setFavoriteItem(
                                        item: model,
                                        type: 0,
                                      );
                                  HelperUtils.showSnackBarMessage(
                                    context,
                                    "Removed from Favorites".translate(context),
                                  );
                                } else {
                                  context
                                      .read<UpdateFavoriteCubit>()
                                      .setFavoriteItem(
                                        item: model,
                                        type: 1,
                                      );
                                  SaveToFavoriteBottomSheet.show(context,
                                      item: model);
                                }
                              },
                              context: context);
                        },
                        child: Center(
                          child: state is UpdateFavoriteInProgress
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  isLike
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isLike ? Colors.red : Colors.grey[700],
                                  size: 20,
                                ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          const SizedBox(width: 10),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                HelperUtils.share(context, model.slug ?? "");
              },
              child: Center(
                child: Icon(
                  Icons.share_outlined,
                  size: 20,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget setTopRowItem(
      {required AlignmentDirectional alignment,
      required double marginVal,
      required double cornerRadius,
      required Color backgroundColor,
      required Widget childWidget}) {
    return Align(
        alignment: alignment,
        child: Container(
            margin: EdgeInsets.all(marginVal),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(cornerRadius),
                color: backgroundColor),
            child: childWidget)
        );
  }

  Widget buildDot(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3.0),
      width: currentPage == index ? 12.0 : 8.0,
      height: 8.0,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: currentPage == index ? Colors.white : Colors.grey),
    );
  }

//ImageView

  Widget setRejectedReason() {
    if (model.status == "rejected" &&
        (model.rejectedReason != null || model.rejectedReason != "")) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: context.color.textDefaultColor.withValues(alpha: 0.1)),

          // Background color
        ),
        margin: const EdgeInsets.symmetric(vertical: 15),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
        child: Row(
            //crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.report,
                size: 20,
                color: Colors.red, // Icon color can be adjusted
              ),
              SizedBox(
                width: 5,
              ),
              Expanded(
                child: Text(
                  '${"rejection_reason".translate(context)}: ${model.rejectedReason}',
                )
                    .color(context.color.textDefaultColor)
                    .size(context.font.large),
              ),
            ]),
      );
    } else {
      return SizedBox.shrink();
    }
  }

  Widget setPriceAndStatus() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Text("${Constant.currencySymbol} ${model.price.toString()}")
              .size(context.font.larger)
              .color(context.color.territoryColor)
              .bold(),
        ),
        if (model.status != null && isAddedByMe)
          Container(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: _getStatusColor(model.status),
            ),
            child: Text(
              _getStatusText(model.status)!,
            ).size(context.font.normal).color(
                  _getStatusTextColor(model.status),
                ),
          )
      ],
    );
  }

  String? _getStatusText(String? status) {
    switch (status) {
      case "review":
        return "underReview".translate(context);
      case "active":
        return "active".translate(context);
      case "approved":
        return "approved".translate(context);
      case "inactive":
        return "deactivate".translate(context);
      case "sold out":
        return "soldOut".translate(context);
      case "rejected":
        return "rejected".translate(context);
      case "expired":
        return "expired".translate(context);
      default:
        return status;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case "review":
        return pendingButtonColor.withValues(alpha: 0.1);
      case "active" || "approved":
        return activateButtonColor.withValues(alpha: 0.1);
      case "inactive":
        return deactivateButtonColor.withValues(alpha: 0.1);
      case "sold out":
        return soldOutButtonColor.withValues(alpha: 0.1);
      case "rejected":
        return deactivateButtonColor.withValues(alpha: 0.1);
      case "expired":
        return deactivateButtonColor.withValues(alpha: 0.1);
      default:
        return context.color.territoryColor.withValues(alpha: 0.1);
    }
  }

  Color _getStatusTextColor(String? status) {
    switch (status) {
      case "review":
        return pendingButtonColor;
      case "active" || "approved":
        return activateButtonColor;
      case "inactive":
        return deactivateButtonColor;
      case "sold out":
        return soldOutButtonColor;
      case "rejected":
        return deactivateButtonColor;
      case "expired":
        return deactivateButtonColor;
      default:
        return context.color.territoryColor;
    }
  }

  Widget setAddress({required bool isDate}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment:
            (isDate) ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvgPicture.asset(
            AppIcons.location,
            colorFilter:
                ColorFilter.mode(context.color.textLightColor, BlendMode.srcIn),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: EdgeInsetsDirectional.only(start: 5.0),
              child: Text(model.address ?? "")
                  .color(context.color.textDefaultColor),
            ),
          ),
          (isDate && model.created != null)
              ? Expanded(
                  child: Text(model.created!.formatDate(format: "d MMM yyyy"))
                      .setMaxLines(lines: 1)
                      .color(context.color.textDefaultColor
                          .withValues(alpha: 0.5)))
              : const SizedBox.shrink()
        ],
      ),
    );
  }

  Widget setDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("aboutThisItemLbl".translate(context)).bold().size(context
            .font.large),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5.0),
          child: Text(model.description ?? "")
              .color(context.color.textDefaultColor.withValues(alpha: 0.5)),
        ),
      ],
    );
  }

  void _navigateToGoogleMapScreen(BuildContext context) {
    Navigator.push(
      context,
      BlurredRouter(
        barrierDismiss: true,
        builder: (context) {
          return GoogleMapScreen(
            item: model,
            kInitialPlace: _kInitialPlace,
            controller: _controller,
          );
        },
      ),
    );
  }

  Widget setLocation() {
    final LatLng currentPosition =
        LatLng(model.latitude ?? 0.0, model.longitude ?? 0.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("locationLbl".translate(context)).bold().size(context.font.large),
        setAddress(isDate: false),
        SizedBox(
          height: 5,
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 200.rh(context),
            child: Stack(
              children: [
                GoogleMap(
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  compassEnabled: false,
                  mapToolbarEnabled: false,
                  liteModeEnabled: true,
                  zoomGesturesEnabled:
                      false, // Changed to false to prevent map from consuming event
                  scrollGesturesEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  initialCameraPosition:
                      CameraPosition(target: currentPosition, zoom: 14),
                  mapType: MapType.normal,
                  markers: {
                    Marker(
                      markerId: MarkerId('currentPosition'),
                      position: currentPosition,
                    )
                  },
                ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      _navigateToGoogleMapScreen(context);
                    },
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget setReportAd() {
    if (!isShowReportAds) return SizedBox.shrink();

    return BlocListener<ItemReportCubit, ItemReportState>(
      listener: (context, state) {
        if (state is ItemReportFailure) {
          HelperUtils.showSnackBarMessage(context, state.error.toString());
        }
        if (state is ItemReportInSuccess) {
          HelperUtils.showSnackBarMessage(
              context, state.responseMessage.toString());
          context.read<UpdatedReportItemCubit>().addItem(model);
        }

        if (!Constant.isDemoModeOn && state is ItemReportInSuccess)
          setState(() {
            isShowReportAds = false;
          });
      },
      child: Column(
        children: [
          Divider(
            thickness: 1,
            color: context.color.textDefaultColor.withValues(alpha: 0.1),
          ),
          InkWell(
            onTap: () {
              UiUtils.checkUser(
                  onNotGuest: () {
                    _bottomSheet(model.id!);
                  },
                  context: context);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.flag_outlined,
                    color: context.color.textDefaultColor,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text("reportThisAd".translate(context))
                      .color(context.color.textDefaultColor)
                      .size(context.font.large)
                      .bold(weight: FontWeight.w500),
                ],
              ),
            ),
          ),
          Divider(
            thickness: 1,
            color: context.color.textDefaultColor.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }

  Future<void> _bottomSheet(int itemId) async {
    await ReportListingDialog.show(
      context,
      itemId: model.id ?? itemId,
      itemModel: model,
    );
  }

  String formatPhoneNumber(String fullNumber, String countryCode) {
    // Normalize the country code (remove '+' if present)
    countryCode = countryCode.replaceAll('+', '');

    // Remove '+' from fullNumber if present
    fullNumber = fullNumber.replaceAll('+', '');

    // Check if the fullNumber already starts with the country code
    if (!fullNumber.startsWith(countryCode)) {
      // If not, prepend the country code
      fullNumber = countryCode + fullNumber;
    }

    // Add '+' to the beginning of the full number
    fullNumber = '+' + fullNumber;

    return fullNumber;
  }

  Widget setSellerDetails() {
    return InkWell(
      onTap: () {
        if (model.user == null) return;
        Navigator.pushNamed(context, Routes.sellerProfileScreen, arguments: {
          "model": model.user!,
          "total":
              context.read<FetchSellerRatingsCubit>().totalSellerRatings() ?? 0,
          "rating": context
              .read<FetchSellerRatingsCubit>()
              .sellerData()
              ?.averageRating
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(children: [
          Container(
              height: 60.rh(context),
              width: 60.rw(context),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: model.user?.profile != null &&
                          model.user!.profile != ""
                      ? UiUtils.getImage(model.user!.profile!, fit: BoxFit.fill)
                      : UiUtils.getSvg(
                          AppIcons.defaultPersonLogo,
                          color: context.color.territoryColor,
                          fit: BoxFit.none,
                        ))),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 20.0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(model.user?.name ?? "")
                        .bold()
                        .size(context.font.large),
                    Text("Owner")
                        .size(context.font.small)
                        .bold(weight: FontWeight.w500)
                        .color(context.color.textDefaultColor),
                    Text("View Profile")
                        .size(context.font.small)
                        .color(Colors.blue),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget setIconButtons({
    required String assetName,
    required void Function() onTap,
    Color? color,
    double? height,
    double? width,
  }) {
    return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.color.borderColor.darken(30))),
        child: Padding(
            padding: const EdgeInsets.all(5),
            child: InkWell(
                onTap: onTap,
                child: SvgPicture.asset(
                  assetName,
                  colorFilter: color == null
                      ? ColorFilter.mode(
                          context.color.territoryColor, BlendMode.srcIn)
                      : ColorFilter.mode(color, BlendMode.srcIn),
                ))));
  }

  Widget reportReason() {
    double bottomPadding = MediaQuery.of(context).viewInsets.bottom - 50;
    bool isBottomPaddingNegative = bottomPadding.isNegative;
    reasons = context.read<FetchItemReportReasonsListCubit>().getList() ?? [];

    if (reasons?.isEmpty ?? true) {
      selectedId = -10;
    } else {
      selectedId = reasons!.first.id;
    }
    setState(() {});
    return StatefulBuilder(builder: (context, setState) {
      return SizedBox(
        width: MediaQuery.of(context).size.width,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListView.separated(
                  shrinkWrap: true,
                  itemCount: reasons?.length ?? 0,
                  physics: const BouncingScrollPhysics(),
                  separatorBuilder: (context, index) {
                    return const SizedBox(height: 10);
                  },
                  itemBuilder: (context, index) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        setState(() {
                          selectedId = reasons![index].id;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.color.primaryColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selectedId == reasons![index].id
                                ? context.color.territoryColor
                                : context.color.borderColor,
                            width: 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Text(
                            reasons![index].reason.firstUpperCase(),
                          ).color(
                            selectedId == reasons![index].id
                                ? context.color.territoryColor
                                : context.color.textColorDark,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (selectedId.isNegative)
                  Padding(
                    padding: EdgeInsetsDirectional.only(
                      bottom: isBottomPaddingNegative ? 0 : bottomPadding,
                      start: 0,
                      end: 0,
                    ),
                    child: TextFormField(
                      maxLines: null,
                      controller: _reportmessageController,
                      cursorColor: context.color.territoryColor,
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return "addReportReason".translate(context);
                        } else {
                          return null;
                        }
                      },
                      decoration: InputDecoration(
                        hintText: "writeReasonHere".translate(context),
                        focusColor: context.color.territoryColor,
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: context.color.territoryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                /*  const SizedBox(
                    height: 14,
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MaterialButton(
                          height: 40,
                          minWidth: 104.rw(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                            side: BorderSide(
                              color: context.color.borderColor,
                              width: 1.5,
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text("cancelLbl".translate(context))
                              .color(context.color.territoryColor),
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        MaterialButton(
                          height: 40,
                          minWidth: 104.rw(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          color: context.color.territoryColor,
                          onPressed: () async {
                            if (selectedId.isNegative) {
                              if (_formKey.currentState!.validate()) {
                                context.read<ItemReportCubit>().report(
                                      item_id: model.id!,
                                      reason_id: selectedId,
                                      message: _reportmessageController.text,
                                    );
                              }
                            } else {
                              context.read<ItemReportCubit>().report(
                                    item_id: model.id!,
                                    reason_id: selectedId,
                                  );
                              Navigator.pop(context);
                            }
                          },
                          child: Text("report".translate(context))
                              .color(context.color.buttonColor),
                        ),
                      ],
                    ),
                  )*/
              ],
            ),
          ),
        ),
      );
    });
  }
}
