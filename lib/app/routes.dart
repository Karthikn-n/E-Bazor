import 'package:Ebozor/ui/screens/auth/sign_up/mobile_signup_screen.dart';
import 'package:Ebozor/ui/screens/filter_screen.dart';
import 'package:Ebozor/ui/screens/home/widgets/categoryFilterScreen.dart';
import 'package:Ebozor/ui/screens/home/widgets/postedSinceFilter.dart';
import 'package:Ebozor/ui/screens/home/widgets/subCategoryFilterScreen.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/widgets/pdf_viewer.dart';
import 'package:Ebozor/ui/screens/item/viewAll.dart';
import 'package:Ebozor/ui/screens/main_activity.dart';
import 'package:Ebozor/ui/screens/sub_category/sub_category_filter_screen.dart';
import 'package:Ebozor/ui/screens/sub_category/sub_category_screen.dart';
import 'package:Ebozor/ui/screens/auth/login/forgot_password.dart';
import 'package:Ebozor/ui/screens/auth/sign_up/signup_main_screen.dart';
import 'package:Ebozor/ui/screens/auth/sign_up/signup_screen.dart';
import 'package:Ebozor/ui/screens/chat/blocked_user_list_screen.dart';

import 'package:Ebozor/ui/screens/favorite_screen.dart';
import 'package:Ebozor/ui/screens/favorite/favorite_collection_items_screen.dart';

import 'package:Ebozor/ui/screens/item/add_item_screen/add_item_details.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/cars/car_specs_form_screen.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/cars/car_posting_details_screen.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/cars/car_package_payment_screen.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/motors/motor_posting_form_screen.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/common_title_input_screen.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/property/property_posting_form_screen.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/classifieds/classifieds_posting_form_screen.dart';
import 'package:Ebozor/ui/screens/jobs/job_home_screen.dart';
import 'package:Ebozor/ui/screens/jobs/job_search_screen.dart';
import 'package:Ebozor/ui/screens/jobs/my_job_applications_screen.dart';
import 'package:Ebozor/ui/screens/jobs/my_job_profile_screen.dart';
import 'package:Ebozor/ui/screens/jobs/job_apply_form_screen.dart';
import 'package:Ebozor/ui/screens/location/user_address_list_screen.dart';
import 'package:Ebozor/ui/screens/location/location_details_form_screen.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/confirm_location_screen.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/more_details.dart';
import 'package:Ebozor/ui/screens/item/items_list.dart';
import 'package:Ebozor/ui/screens/location/cities_screen.dart';
import 'package:Ebozor/ui/screens/location/countries_screen.dart';
import 'package:Ebozor/ui/screens/location/states_screen.dart';
import 'package:Ebozor/ui/screens/seller/seller_verification_complete.dart';

import 'package:Ebozor/ui/screens/ad_details_screen.dart';
import 'package:Ebozor/ui/screens/faqs_screen.dart';
import 'package:Ebozor/ui/screens/location_permission_screen.dart';
import 'package:Ebozor/ui/screens/my_review_screen.dart';
import 'package:Ebozor/ui/screens/sold_out_bought_screen.dart';
import 'package:Ebozor/ui/screens/user_profile/edit_profile.dart';
import 'package:Ebozor/ui/screens/user_profile/saved_searches_screen.dart';
import 'package:Ebozor/ui/screens/user_profile/account_settings_screen.dart';
import 'package:Ebozor/ui/screens/user_profile/phone_numbers_screen.dart';
import 'package:Ebozor/ui/screens/user_profile/choose_otp_method_screen.dart';
import 'package:Ebozor/ui/screens/user_profile/confirm_phone_number_screen.dart';
import 'package:Ebozor/ui/screens/user_profile/security_screen.dart';
import 'package:Ebozor/ui/screens/help_me_buy/help_me_buy_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:Ebozor/ui/screens/jobs/introduction_recording_screen.dart';
import 'package:Ebozor/ui/screens/advertisement/my_advertisment_screen.dart';
import 'package:Ebozor/ui/screens/auth/login/login_screen.dart';

import 'package:Ebozor/ui/screens/blogs/blog_details.dart';
import 'package:Ebozor/ui/screens/blogs/blogs_screen.dart';

import 'package:Ebozor/ui/screens/home/category_list.dart';
import 'package:Ebozor/ui/screens/home/change_language_screen.dart';
import 'package:Ebozor/ui/screens/home/search_screen.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/widgets/success_item_screen.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/select_category.dart';
import 'package:Ebozor/ui/screens/item/my_items_screen.dart';

import 'package:Ebozor/ui/screens/location/areas_screen.dart';
import 'package:Ebozor/ui/screens/location/location_map_screen.dart';
import 'package:Ebozor/ui/screens/location/nearby_location.dart';
import 'package:Ebozor/ui/screens/location/select_location_screen.dart';
import 'package:Ebozor/ui/screens/onboarding/onboarding_screen.dart';

import 'package:Ebozor/ui/screens/seller/seller_intro_verification.dart';
import 'package:Ebozor/ui/screens/seller/seller_profile.dart';
import 'package:Ebozor/ui/screens/seller/seller_verification.dart';
import 'package:Ebozor/ui/screens/settings/contact_us.dart';
import 'package:Ebozor/ui/screens/settings/notification_detail.dart';
import 'package:Ebozor/ui/screens/settings/notifications.dart';
import 'package:Ebozor/ui/screens/settings/profile_setting.dart';
import 'package:Ebozor/ui/screens/subscription/packages_list.dart';

import 'package:Ebozor/ui/screens/subscription/transaction_history_screen.dart';
import 'package:Ebozor/ui/screens/motors_services/motors_service_screen.dart';
import 'package:Ebozor/ui/screens/motors_services/motors_service_request_screen.dart';
import 'package:Ebozor/ui/screens/motors_services/motors_inspection_checkout_screen.dart';
import 'package:Ebozor/ui/screens/motors_services/car_inspection_history_screen.dart';
import 'package:Ebozor/ui/screens/motors_services/car_appointments_screen.dart';

import 'package:Ebozor/ui/screens/splash_screen.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/maintenance_mode.dart';
import 'package:Ebozor/ui/screens/user_profile/profile_menu_screen.dart';
import 'package:Ebozor/data/repositories/item/item_repository.dart';
import 'package:Ebozor/data/model/data_output.dart';
import 'package:Ebozor/data/model/item/item_model.dart';

class Routes {
  //private constructor
  //Routes._();
  static const filterpage = 'filterpage';
  static const splash = 'splash';
  static const onboarding = 'onboarding';
  static const login = 'login';
  static const forgotPassword = 'forgotPassword';
  static const signup = 'signup';
  static const signupMainScreen = 'signUpMainScreen';
  static const mobileSignUp = 'mobileSignUp';
  static const completeProfile = 'complete_profile';
  static const main = 'main';
  static const home = 'Home';
  static const addItem = 'addItem';
  static const waitingScreen = 'waitingScreen';
  static const categories = 'Categories';
  static const addresses = 'address';
  static const chooseAdrs = 'chooseAddress';
  static const itemsList = 'itemsList';
  static const contactUs = 'ContactUs';
  static const profileSettings = 'profileSettings';
  static const filterScreen = 'filterScreen';
  static const notificationPage = 'notificationpage';
  static const notificationDetailPage = 'notificationdetailpage';
  static const addItemScreenRoute = 'addItemScreenRoute';
  static const blogsScreenRoute = 'blogsScreenRoute';
  static const subscriptionPackageListRoute = 'subscriptionPackageListRoute';
  static const subscriptionScreen = 'subscriptionScreen';
  static const maintenanceMode = '/maintenanceMode';
  static const favoritesScreen = '/favoritescreen';
  static const favoriteCollectionItemsScreen = '/favoriteCollectionItemsScreen';
  static const promotedItemsScreen = '/promotedItemsScreen';
  static const mostLikedItemsScreen = '/mostLikedItemsScreen';
  static const mostViewedItemsScreen = '/mostViewedItemsScreen';
  static const blogDetailsScreenRoute = '/blogDetailsScreenRoute';
  static const myReviewsScreen = '/myReviewsScreenRoute';

  static const languageListScreenRoute = '/languageListScreenRoute';
  static const searchScreenRoute = '/searchScreenRoute';
  static const itemMapScreen = '/ItemMap';
  static const dashboard = '/dashboard';
  static const subCategoryScreen = '/subCategoryScreen';
  static const categoryFilterScreen = '/categoryFilterScreen';
  static const subCategoryFilterScreen = '/subCategoryFilterScreen';
  static const postedSinceFilterScreen = '/postedSinceFilterScreen';
  static const locationPermissionScreen = '/locationPermissionScreen';
  static const sellerProfileScreen = '/sellerProfileScreen';
  static const nearbyLocationScreen = '/nearbyLocationScreen';
  static const selectLocationScreen = '/selectLocationScreen';
  static const locationMapScreen = '/locationMapScreen';

  static const myAdvertisment = '/myAdvertisment';
  static const transactionHistory = '/transactionHistory';
  static const personalizedItemScreen = '/personalizedItemScreen';
  static const myItemScreen = '/myItemScreen';
  static const pdfViewerScreen = '/pdfViewerScreen';
  static const countriesScreen = '/countriesScreen';
  static const statesScreen = '/statesScreen';
  static const citiesScreen = '/citiesScreen';
  static const areasScreen = '/areasScreen';
  static const faqsScreen = '/faqsScreen';
  static const soldOutBoughtScreen = '/soldOutBoughtScreen';
  static const sellerIntroVerificationScreen = '/sellerIntroVerificationScreen';
  static const sellerVerificationScreen = '/sellerVerificationScreen';
  static const sellerVerificationComplteScreen =
      '/sellerVerificationComplteScreen';

  ///Add Item screens
  static const selectItemTypeScreen = '/selectItemType';
  static const addItemDetailsScreen = '/addItemDetailsScreen';
  static const setItemParametersScreen = '/setItemParametersScreen';
  static const selectOutdoorFacility = '/selectOutdoorFacility';
  static const adDetailsScreen = '/adDetailsScreen';
  static const successItemScreen = '/successItemScreen';

  ///Add item screens
  static const selectCategoryScreen = '/selectCategoryScreen';
  static const selectNestedCategoryScreen = '/selectNestedCategoryScreen';
  static const addItemDetails = '/addItemDetails';
  static const addMoreDetailsScreen = '/addMoreDetailsScreen';
  static const confirmLocationScreen = '/confirmLocationScreen';
  static const carSpecsFormScreen = '/carSpecsFormScreen';
  static const carPostingDetailsScreen = '/carPostingDetailsScreen';
  static const carPackagePaymentScreen = '/carPackagePaymentScreen';
  static const motorPostingFormScreen = '/motorPostingFormScreen';
  static const commonTitleInputScreen = '/commonTitleInputScreen';
  static const propertyPostingFormScreen = '/propertyPostingFormScreen';
  static const classifiedsPostingFormScreen = '/classifiedsPostingFormScreen';
  static const userAddressListScreen = '/userAddressListScreen';
  static const locationDetailsFormScreen = '/locationDetailsFormScreen';
  static const motorsServiceScreen = '/motorsServiceScreen';
  static const motorsServiceRequestScreen = '/motorsServiceRequestScreen';
  static const motorsInspectionCheckoutScreen =
      '/motorsInspectionCheckoutScreen';
  static const carInspectionHistoryScreen = '/carInspectionHistoryScreen';
  static const carAppointmentsScreen = '/carAppointmentsScreen';
  static const savedSearchesScreen = '/savedSearchesScreen';
  static const sectionWiseItemsScreen = '/sectionWiseItemsScreen';
  static const blockedUserListScreen = '/blockedUserListScreen';
  static const accountSettingsScreen = '/accountSettingsScreen';
  static const phoneNumbersScreen = '/phoneNumbersScreen';
  static const chooseOtpMethodScreen = '/chooseOtpMethodScreen';
  static const confirmPhoneNumberScreen = '/confirmPhoneNumberScreen';
  static const securityScreen = '/securityScreen';
  static const jobHomeScreen = '/jobHomeScreen';
  static const jobSearchScreen = '/jobSearchScreen';
  static const myJobApplicationsScreen = '/myJobApplicationsScreen';
  static const myJobProfileScreen = '/myJobProfileScreen';
  static const jobApplyFormScreen = '/jobApplyFormScreen';
  static const introductionRecordingScreen = '/introductionRecordingScreen';
  static const helpMeBuyScreen = '/helpMeBuyScreen';
  static const profileMenuScreen = '/profileMenuScreen';
  static const payStackWebViewScreen = '/payStackWebViewScreen';

  // static const myItemsScreen = '/myItemsScreen';

  //Sandbox[test]
  static const playground = 'playground';

  static String currentRoute = splash;

  //static String previousCustomerRoute = splash;

  static Route onGenerateRouted(RouteSettings routeSettings) {
    currentRoute = routeSettings.name ?? "";

    if (routeSettings.name!.contains('/product-details/')) {
      String itemSlug = routeSettings.name!.split('/').last;
      // Fetch item details based on the itemId
      return MaterialPageRoute(builder: (context) {
        return FutureBuilder<DataOutput<ItemModel>>(
          future: ItemRepository().fetchItemFromItemSlug(itemSlug),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              // Return a loading indicator while fetching data
              return Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            } else if (snapshot.hasError) {
              // Handle error case
              return Scaffold(
                body: Center(
                  child: Text('Error: ${snapshot.error}'),
                ),
              );
            } else {
              return AdDetailsScreen(model: snapshot.data!.modelList.first);
            }
          },
        );
      });
    }

    switch (routeSettings.name) {
      case splash:
        return BlurredRouter(builder: ((context) => const SplashScreen()));
      case onboarding:
        return CupertinoPageRoute(
            builder: ((context) => const OnboardingScreen()));
      case main:
        return MainActivity.route(routeSettings);
      case login:
        return LoginScreen.route(routeSettings);
      case forgotPassword:
        return ForgotPasswordScreen.route(routeSettings);
      case signup:
        return SignupScreen.route(routeSettings);
      case signupMainScreen:
        return SignUpMainScreen.route(routeSettings);
      case mobileSignUp:
        return MobileSignUpScreen.route(routeSettings);
      case completeProfile:
        return UserProfileScreen.route(routeSettings);

      case categories:
        return CategoryList.route(routeSettings);
      case subCategoryScreen:
        return SubCategoryScreenOne.route(routeSettings);
      case categoryFilterScreen:
        return CategoryFilterScreen.route(routeSettings);
      case subCategoryFilterScreen:
        return SubCategoryFilterScreen.route(routeSettings);
      case postedSinceFilterScreen:
        return PostedSinceFilterScreen.route(routeSettings);
      case maintenanceMode:
        return MaintenanceMode.route(routeSettings);
      case languageListScreenRoute:
        return LanguagesListScreen.route(routeSettings);
      case contactUs:
        return ContactUs.route(routeSettings);
      case locationPermissionScreen:
        return LocationPermissionScreen.route(routeSettings);
      case profileSettings:
        return ProfileSettings.route(routeSettings);
      case filterScreen:
        return FilterScreen.route(routeSettings);
      case notificationPage:
        return Notifications.route(routeSettings);
      case notificationDetailPage:
        return NotificationDetail.route(routeSettings);
      case blogsScreenRoute:
        return BlogsScreen.route(routeSettings);
      case successItemScreen:
        return SuccessItemScreen.route(routeSettings);

      case blogDetailsScreenRoute:
        return BlogDetails.route(routeSettings);
      case subscriptionPackageListRoute:
        return SubscriptionPackageListScreen.route(routeSettings);

      case favoritesScreen:
        return FavoriteScreen.route(routeSettings);

      case favoriteCollectionItemsScreen:
        return FavoriteCollectionItemsScreen.route(routeSettings);

      case transactionHistory:
        return TransactionHistory.route(routeSettings);
      case blockedUserListScreen:
        return BlockedUserListScreen.route(routeSettings);
      case countriesScreen:
        return CountriesScreen.route(routeSettings);

      case statesScreen:
        return StatesScreen.route(routeSettings);
      case citiesScreen:
        return CitiesScreen.route(routeSettings);
      case areasScreen:
        return AreasScreen.route(routeSettings);

      case myAdvertisment:
        return MyAdvertisementScreen.route(routeSettings);
      case myItemScreen:
        return ItemsScreen.route(routeSettings);
      case searchScreenRoute:
        return SearchScreen.route(routeSettings);

      case itemsList:
        return ItemsList.route(routeSettings);
      case faqsScreen:
        return FaqsScreen.route(routeSettings);

      //Add item screen
      case selectCategoryScreen:
        return SelectCategoryScreen.route(routeSettings);
      case selectNestedCategoryScreen:
        return SelectNestedCategory.route(routeSettings);
      case addItemDetails:
        return AddItemDetails.route(routeSettings);
      case addMoreDetailsScreen:
        return AddMoreDetailsScreen.route(routeSettings);

      case confirmLocationScreen:
        return ConfirmLocationScreen.route(routeSettings);
      case sectionWiseItemsScreen:
        return SectionItemsScreen.route(routeSettings);

      case adDetailsScreen:
        return AdDetailsScreen.route(routeSettings);

      case pdfViewerScreen:
        return PdfViewer.route(routeSettings);
      case soldOutBoughtScreen:
        return SoldOutBoughtScreen.route(routeSettings);
      case sellerProfileScreen:
        return SellerProfileScreen.route(routeSettings);
      case sellerIntroVerificationScreen:
        return SellerIntroVerificationScreen.route(routeSettings);
      case sellerVerificationScreen:
        return SellerVerificationScreen.route(routeSettings);
      case sellerVerificationComplteScreen:
        return SellerVerificationCompleteScreen.route(routeSettings);
      case nearbyLocationScreen:
        return NearbyLocationScreen.route(routeSettings);
      case selectLocationScreen:
        return SelectLocationScreen.route(routeSettings);
      case locationMapScreen:
        return LocationMapScreen.route(routeSettings);
      case myReviewsScreen:
        return MyReviewScreen.route(routeSettings);
      case filterpage:
        return FiltersPage.route(routeSettings);
      case carSpecsFormScreen:
        return CarSpecsFormScreen.route(routeSettings);
      case carPostingDetailsScreen:
        return CarPostingDetailsScreen.route(routeSettings);
      case carPackagePaymentScreen:
        return CarPackagePaymentScreen.route(routeSettings);
      case motorPostingFormScreen:
        return MotorPostingFormScreen.route(routeSettings);
      case commonTitleInputScreen:
        return CommonTitleInputScreen.route(routeSettings);
      case propertyPostingFormScreen:
        return PropertyPostingFormScreen.route(routeSettings);
      case classifiedsPostingFormScreen:
        return ClassifiedsPostingFormScreen.route(routeSettings);
      case userAddressListScreen:
      case addresses:
        return UserAddressListScreen.route(routeSettings);
      case locationDetailsFormScreen:
        return LocationDetailsFormScreen.route(routeSettings);
      case motorsServiceScreen:
        return MotorsServiceScreen.route(routeSettings);
      case motorsServiceRequestScreen:
        return MotorsServiceRequestScreen.route(routeSettings);
      case motorsInspectionCheckoutScreen:
        return MotorsInspectionCheckoutScreen.route(routeSettings);
      case carInspectionHistoryScreen:
        return CarInspectionHistoryScreen.route(routeSettings);
      case carAppointmentsScreen:
        return CarAppointmentsScreen.route(routeSettings);
      case savedSearchesScreen:
        return SavedSearchesScreen.route(routeSettings);
      case accountSettingsScreen:
        return AccountSettingsScreen.route(routeSettings);
      case phoneNumbersScreen:
        return PhoneNumbersScreen.route(routeSettings);
      case chooseOtpMethodScreen:
        return ChooseOtpMethodScreen.route(routeSettings);
      case confirmPhoneNumberScreen:
        return ConfirmPhoneNumberScreen.route(routeSettings);
      case securityScreen:
        return SecurityScreen.route(routeSettings);
      case jobHomeScreen:
        return JobHomeScreen.route(routeSettings);
      case jobSearchScreen:
        return JobSearchScreen.route(routeSettings);
      case myJobApplicationsScreen:
        return MyJobApplicationsScreen.route(routeSettings);
      case myJobProfileScreen:
        return MyJobProfileScreen.route(routeSettings);
      case jobApplyFormScreen:
        return JobApplyFormScreen.route(routeSettings);
      case introductionRecordingScreen:
        final recType = routeSettings.arguments is RecordingType
            ? routeSettings.arguments as RecordingType
            : RecordingType.video;
        return IntroductionRecordingScreen.route(recType);
      case helpMeBuyScreen:
        return HelpMeBuyScreen.route(routeSettings);
      case profileMenuScreen:
        return ProfileMenuScreen.route(routeSettings);

      /*case payStackWebViewScreen:
        return PaystackWebView.route(routeSettings);*/

      /*  case myItemsScreen:
        return ItemsScreen.route(routeSettings);*/

      default:
        return CupertinoPageRoute(builder: (context) => const Scaffold());
      /*
        if (routeSettings.name!.contains(AppSettings.shareNavigationWebUrl)) {

          return NativeLinkWidget.render(routeSettings);
        }

        return BlurredRouter(
          builder: ((context) => Scaffold(
                body: Text(
                  "pageNotFoundErrorMsg".translate(context),
                ),
              )),
        );*/
    }
  }
}
