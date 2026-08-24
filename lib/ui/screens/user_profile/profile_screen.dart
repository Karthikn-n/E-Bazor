import 'dart:io';
import 'package:Ebozor/app/app_theme.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/category/fetch_category_cubit.dart';
import 'package:Ebozor/data/cubits/home/fetch_home_screen_cubit.dart';
import 'package:Ebozor/data/cubits/item/fetch_my_promoted_items_cubit.dart';
import 'package:Ebozor/data/cubits/system/app_theme_cubit.dart';
import 'package:Ebozor/data/cubits/system/fetch_language_cubit.dart';
import 'package:Ebozor/data/cubits/system/fetch_system_settings_cubit.dart';
import 'package:Ebozor/data/cubits/system/language_cubit.dart';
import 'package:Ebozor/data/cubits/system/user_details.dart';
import 'package:Ebozor/data/helper/widgets.dart';
import 'package:Ebozor/ui/screens/main_activity.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_keys.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/data/cubits/chat/blocked_users_list_cubit.dart';
import 'package:Ebozor/data/cubits/favorite/favorite_cubit.dart';
import 'package:Ebozor/data/cubits/seller/fetch_verification_request_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import 'package:Ebozor/data/cubits/report/update_report_items_list_cubit.dart';
import 'package:Ebozor/data/cubits/chat/get_buyer_chat_users_cubit.dart';
import 'package:Ebozor/data/model/system_settings_model.dart';

import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/network/apiCallTrigger.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/ui/screens/widgets/phone_verification_dialog.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/ui/screens/widgets/blurred_dialoge_box.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin<ProfileScreen> {
  ValueNotifier isDarkTheme = ValueNotifier(false);
  final InAppReview _inAppReview = InAppReview.instance;
  // final FirebaseAuth _auth = FirebaseAuth.instance;
  // final GoogleSignIn _googleSignIn = GoogleSignIn();
  String _appVersion = "3.35.2.0 (40445)";

  @override
  void initState() {
    super.initState();
    final settings = context.read<FetchSystemSettingsCubit>();
    if (HiveUtils.isUserAuthenticated()) {
      context
          .read<FetchVerificationRequestsCubit>()
          .fetchVerificationRequests();
    }
    if (!const bool.fromEnvironment("force-disable-demo-mode",
        defaultValue: false)) {
      Constant.isDemoModeOn =
          settings.getSetting(SystemSetting.demoMode) ?? false;
    }
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = "${packageInfo.version} (${packageInfo.buildNumber})";
        });
      }
    } catch (e) {
      debugPrint("Error loading package info: $e");
    }
  }

  @override
  void didChangeDependencies() {
    isDarkTheme.value = context.read<AppThemeCubit>().isDarkMode();
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    isDarkTheme.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  // ---------------------------------------------------------------------------
  // Top Profile Card
  // ---------------------------------------------------------------------------
  Widget _buildProfileHeader() {
    return BlocBuilder<FetchVerificationRequestsCubit,
        FetchVerificationRequestState>(builder: (context, state) {
      return ValueListenableBuilder(
        valueListenable: Hive.box(HiveKeys.userDetailsBox).listenable(),
        builder: (context, Box box, _) {
          final user = HiveUtils.getUserDetails();
          final isAuthenticated = HiveUtils.isUserAuthenticated();
          final isVerified = user.isVerified == 1 ||
              (state is FetchVerificationRequestSuccess &&
                  state.data.status == "approved");

          String joinedDate = "";
          if (isAuthenticated &&
              user.createdAt != null &&
              user.createdAt!.isNotEmpty) {
            final parsed = DateTime.tryParse(user.createdAt!);
            if (parsed != null) {
              joinedDate =
                  "Joined on ${DateFormat('MMMM yyyy').format(parsed)}";
            }
          }
          if (joinedDate.isEmpty && isAuthenticated) {
            joinedDate =
                "Joined on ${DateFormat('MMMM yyyy').format(DateTime.now())}";
          }

          return Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: context.color.secondaryColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: context.color.borderColor.withValues(alpha: 0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Profile Avatar with Edit Badge
                Stack(
                  children: [
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.color.territoryColor
                              .withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        backgroundColor: context.color.territoryColor
                            .withValues(alpha: 0.08),
                        radius: 34,
                        child: isAuthenticated
                            ? ((user.profile ?? "").isEmpty
                                ? UiUtils.getSvg(
                                    AppIcons.defaultPersonLogo,
                                    color: context.color.territoryColor,
                                    fit: BoxFit.none,
                                  )
                                : UiUtils.getImage(
                                    height: 68,
                                    width: 68,
                                    user.profile!,
                                    fit: BoxFit.cover,
                                  ))
                            : UiUtils.getSvg(
                                AppIcons.defaultPersonLogo,
                                color: context.color.territoryColor,
                                fit: BoxFit.none,
                              ),
                      ),
                    ),
                    if (isAuthenticated)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: InkWell(
                          onTap: () {
                            HelperUtils.goToNextPage(
                              Routes.completeProfile,
                              context,
                              false,
                              args: {"from": "profile"},
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C2C34),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.color.secondaryColor,
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 11,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),

                // Name, Verification, and Joined date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAuthenticated
                            ? (user.name ?? 'User')
                            : "anonymous".translate(context),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.color.textColorDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      if (isAuthenticated) ...[
                        if (isVerified)
                          GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, Routes.sellerVerificationScreen, arguments: {"isResubmitted": false});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: context.color.forthColor
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified_rounded,
                                    size: 14,
                                    color: context.color.forthColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "verifiedLbl".translate(context),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: context.color.forthColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          InkWell(
                            onTap: () {
                              PhoneVerificationDialog.show(
                                context,
                                onVerified: () {
                                  setState(() {});
                                  context
                                      .read<FetchVerificationRequestsCubit>()
                                      .fetchVerificationRequests();
                                },
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: context.color.borderColor
                                      .withValues(alpha: 0.8),
                                ),
                                color: context.color.backgroundColor,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "Get Verified",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: context.color.textColorDark,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 14,
                                    color: context.color.textLightColor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                      if (joinedDate.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          joinedDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.color.textLightColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isAuthenticated)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.color.territoryColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        Routes.login,
                        (route) => false,
                      );
                    },
                    child: Text(
                      "loginLbl".translate(context),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Top Quick Cards (My Ads, My Searches, My Bookings)
  // ---------------------------------------------------------------------------
  Widget _buildQuickCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.list_alt_rounded,
                title: "My Ads",
                onTap: () {
                  APICallTrigger.trigger();
                  UiUtils.checkUser(
                    onNotGuest: () {
                      Navigator.pushNamed(
                        context,
                        Routes.myAdvertisment,
                        arguments: {"fromProfile": true},
                      );
                    },
                    context: context,
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.bookmark_border_rounded,
                title: "My Searches",
                onTap: () {
                  UiUtils.checkUser(
                    onNotGuest: () {
                      Navigator.pushNamed(
                        context,
                        Routes.savedSearchesScreen,
                      );
                    },
                    context: context,
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.calendar_today_outlined,
                title: "My Bookings",
                badgeText: "NEW",
                onTap: () {
                  UiUtils.checkUser(
                    onNotGuest: () {
                      Navigator.pushNamed(
                        context,
                        Routes.carInspectionHistoryScreen,
                      );
                    },
                    context: context,
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? badgeText,
  }) {
    final redColor = context.color.territoryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: context.color.borderColor.withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (badgeText != null)
                Positioned(
                  top: -8,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: redColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 26,
                      color: redColor,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.color.textColorDark,
                      ),
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

  // ---------------------------------------------------------------------------
  // Menu Item Tile
  // ---------------------------------------------------------------------------
  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? trailingText,
    String? badgeText,
    Color? textColor,
    Color? iconColor,
    bool isSwitch = false,
    bool? switchValue,
    ValueChanged<bool>? onSwitchChanged,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 12.0),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: iconColor ??
                    (textColor ?? context.color.textColorDark),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: textColor ?? context.color.textColorDark,
                  ),
                ),
              ),
              if (isSwitch)
                Switch(
                  value: switchValue ?? false,
                  onChanged: onSwitchChanged,
                  activeThumbColor: Colors.white,
                  activeTrackColor: context.color.territoryColor,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.grey.shade400,
                  trackOutlineColor:
                      WidgetStateProperty.all(Colors.transparent),
                )
              else if (badgeText != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.color.territoryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: context.color.textLightColor,
                ),
              ] else if (trailingText != null) ...[
                Text(
                  trailingText,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: context.color.textLightColor,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: context.color.textLightColor,
                ),
              ] else if (textColor != Colors.red)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: context.color.textLightColor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionDivider() {
    return Divider(
      height: 24,
      thickness: 0.8,
      color: context.color.borderColor.withValues(alpha: 0.35),
    );
  }

  // ---------------------------------------------------------------------------
  // Security Bottom Sheet (Shows Blocked Users)
  // ---------------------------------------------------------------------------
  void _showSecurityBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.color.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Security",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                  ),
                ),
                const SizedBox(height: 12),
                _buildMenuTile(
                  icon: Icons.person_off_outlined,
                  title: "blockedUsers".translate(context),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, Routes.blockedUserListScreen);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Language Bottom Sheet
  // ---------------------------------------------------------------------------
  void _showLanguageBottomSheet() {
    final languageSetting = context
        .read<FetchSystemSettingsCubit>()
        .getSetting(SystemSetting.language);

    if (languageSetting == null ||
        languageSetting is! List ||
        languageSetting.isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        "No languages available",
      );
      return;
    }

    final List languages = languageSetting;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetCtx) {
        final currentLanguageState = context.watch<LanguageCubit>().state;
        final currentCode = (currentLanguageState is LanguageLoader)
            ? currentLanguageState.language['code']
            : HiveUtils.getLanguage()?['code'];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.color.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "chooseLanguage".translate(context),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 22,
                        color: context.color.textLightColor,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(bottomSheetCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: languages.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: context.color.borderColor.withValues(alpha: 0.35),
                    ),
                    itemBuilder: (ctx, index) {
                      final item = languages[index];
                      final isSelected = item['code'] == currentCode;

                      return InkWell(
                        onTap: () {
                          Navigator.pop(bottomSheetCtx);
                          context
                              .read<FetchLanguageCubit>()
                              .getLanguage(item['code']);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 4),
                          child: Row(
                            children: [
                              if (item['image'] != null &&
                                  item['image'].toString().isNotEmpty)
                                Container(
                                  width: 32,
                                  height: 32,
                                  margin: const EdgeInsets.only(right: 14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: UiUtils.imageType(
                                      item['image'],
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  item['name'] ?? "",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? context.color.territoryColor
                                        : context.color.textDefaultColor,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: context.color.territoryColor,
                                  size: 20,
                                ),
                            ],
                          ),
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

  // ---------------------------------------------------------------------------
  // Legal Hub Bottom Sheet
  // ---------------------------------------------------------------------------
  void _showLegalHubBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.color.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Legal Hub",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                  ),
                ),
                const SizedBox(height: 12),
                _buildMenuTile(
                  icon: Icons.info_outline_rounded,
                  title: "aboutUs".translate(context),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, Routes.profileSettings,
                        arguments: {
                          'title': "aboutUs".translate(context),
                          'param': Api.aboutUs,
                        });
                  },
                ),
                _buildMenuTile(
                  icon: Icons.description_outlined,
                  title: "termsConditions".translate(context),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, Routes.profileSettings,
                        arguments: {
                          'title': "termsConditions".translate(context),
                          'param': Api.termsAndConditions,
                        });
                  },
                ),
                _buildMenuTile(
                  icon: Icons.privacy_tip_outlined,
                  title: "privacyPolicy".translate(context),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, Routes.profileSettings,
                        arguments: {
                          'title': "privacyPolicy".translate(context),
                          'param': Api.privacyPolicy,
                        });
                  },
                ),
                _buildMenuTile(
                  icon: Icons.share_outlined,
                  title: "shareApp".translate(context),
                  onTap: () {
                    Navigator.pop(ctx);
                    shareApp();
                  },
                ),
                _buildMenuTile(
                  icon: Icons.star_outline_rounded,
                  title: "rateUs".translate(context),
                  onTap: () {
                    Navigator.pop(ctx);
                    rateUs();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Call Us Modern Dialog
  // ---------------------------------------------------------------------------
  void _showCallUsDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: dialogCtx.color.secondaryColor,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Green Phone Ringing Icon
                    const Icon(
                      Icons.phone_in_talk_rounded,
                      size: 52,
                      color: Color(0xFF22C55E),
                    ),
                    const SizedBox(height: 18),

                    // Title
                    Text(
                      "Call us to get in touch",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: dialogCtx.color.textDefaultColor,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Timings / Working Hours
                    Text(
                      "9:00 AM to 6:00 PM, Monday to Friday",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: dialogCtx.color.textLightColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Big Red Phone Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD31027),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          final phoneUri = Uri.parse("tel:80038249953");
                          if (await canLaunchUrl(phoneUri)) {
                            await launchUrl(phoneUri);
                          } else {
                            HelperUtils.showSnackBarMessage(
                              context,
                              "Support Line: 800-38249953",
                            );
                          }
                        },
                        child: const Text(
                          "800-38249953 (ebozor)",
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Email Support Link
                    InkWell(
                      onTap: () async {
                        final emailUri =
                            Uri.parse("mailto:customersupport@ebozor.com");
                        if (await canLaunchUrl(emailUri)) {
                          await launchUrl(emailUri);
                        }
                      },
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 13.5,
                            color: dialogCtx.color.textDefaultColor,
                          ),
                          children: const [
                            TextSpan(text: "Or email us at "),
                            TextSpan(
                              text: "customersupport@ebozor.com",
                              style: TextStyle(
                                color: Color(0xFF1E88E5),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Cancel / Close Icon at Top Right
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 22,
                    color: dialogCtx.color.textLightColor,
                  ),
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleJobProfileTap() {
    Navigator.pushNamed(context, Routes.myJobApplicationsScreen);
  }

  // ---------------------------------------------------------------------------
  // Main Build Method
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Current City
    final cityName = HiveUtils.getCityName() ??
        HiveUtils.getCurrentCityName() ??
        "Abu Dhabi";

    // Current Language
    final langData = HiveUtils.getLanguage();
    final langName = langData?['name'] ?? "English";

    final isAuthenticated = HiveUtils.isUserAuthenticated();

    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: BlocListener<FetchLanguageCubit, FetchLanguageState>(
        listener: (context, state) {
          if (state is FetchLanguageInProgress) {
            Widgets.showLoader(context);
          }
          if (state is FetchLanguageSuccess) {
            Widgets.hideLoder(context);

            Map<String, dynamic> map = state.toMap();
            var data = map['file_name'];
            map['data'] = data;
            map.remove("file_name");

            HiveUtils.storeLanguage(map);
            context.read<LanguageCubit>().changeLanguage(map);
            context.read<FetchCategoryCubit>().fetchCategories();
            context.read<FetchHomeScreenCubit>().fetch(
                  city: HiveUtils.getCityName(),
                  areaId: HiveUtils.getAreaId(),
                  country: HiveUtils.getCountryName(),
                  state: HiveUtils.getStateName(),
                );
            setState(() {});
          }
        },
        child: Scaffold(
          backgroundColor: context.color.backgroundColor,
          appBar: UiUtils.buildAppBar(
            context,
            title: "profileTab".translate(context).isNotEmpty &&
                    "profileTab".translate(context) != "profileTab"
                ? "profileTab".translate(context)
                : "Profile",
            showBackButton: false,
          ),
          body: SingleChildScrollView(
            controller: profileScreenController,
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Profile Header Card
                  _buildProfileHeader(),
                  const SizedBox(height: 14),

                  // 2. Quick Action Cards (My Ads, My Searches, My Bookings)
                  _buildQuickCards(),
                  const SizedBox(height: 18),

                  // -----------------------------------------------------------
                  // 3. Menu List Section
                  // -----------------------------------------------------------

                  // GROUP 1: Account & Profile
                  _buildMenuTile(
                    icon: Icons.person_outline_rounded,
                    title: "Profile",
                    onTap: () {
                      UiUtils.checkUser(
                        onNotGuest: () {
                          Navigator.pushNamed(
                              context, Routes.profileMenuScreen);
                        },
                        context: context,
                      );
                    },
                  ),
                  _buildMenuTile(
                    icon: Icons.settings_outlined,
                    title: "Account",
                    onTap: () {
                      UiUtils.checkUser(
                        onNotGuest: () {
                          Navigator.pushNamed(
                              context, Routes.accountSettingsScreen);
                        },
                        context: context,
                      );
                    },
                  ),
                  _buildMenuTile(
                    icon: Icons.notifications_none_rounded,
                    title: "Notification",
                    onTap: () {
                      UiUtils.checkUser(
                        onNotGuest: () {
                          Navigator.pushNamed(context, Routes.notificationPage);
                        },
                        context: context,
                      );
                    },
                  ),
                  _buildMenuTile(
                    icon: Icons.lock_outline_rounded,
                    title: "Security",
                    onTap: () {
                      UiUtils.checkUser(
                        onNotGuest: () {
                          Navigator.pushNamed(
                              context, Routes.securityScreen);
                        },
                        context: context,
                      );
                    },
                  ),

                  _buildSectionDivider(),

                  // GROUP 2: Appointments & Services
                  _buildMenuTile(
                    icon: Icons.calendar_today_outlined,
                    title: "Car Appointments",
                    onTap: () {
                      UiUtils.checkUser(
                        onNotGuest: () {
                          Navigator.pushNamed(
                            context,
                            Routes.carAppointmentsScreen,
                          );
                        },
                        context: context,
                      );
                    },
                  ),
                  _buildMenuTile(
                    icon: Icons.directions_car_outlined,
                    title: "Car Inspections",
                    onTap: () {
                      UiUtils.checkUser(
                        onNotGuest: () {
                          Navigator.pushNamed(
                            context,
                            Routes.carInspectionHistoryScreen,
                          );
                        },
                        context: context,
                      );
                    },
                  ),
                  _buildMenuTile(
                    icon: Icons.shopping_bag_outlined,
                    title: "Help Me Buy",
                    onTap: () {
                      Navigator.pushNamed(context, Routes.helpMeBuyScreen);
                    },
                  ),

                  _buildSectionDivider(),

                  // GROUP 3: Preferences / Localization
                  _buildMenuTile(
                    icon: Icons.apartment_rounded,
                    title: "City",
                    trailingText: cityName,
                    onTap: () {
                      Navigator.pushNamed(context, Routes.citiesScreen);
                    },
                  ),
                  _buildMenuTile(
                    icon: Icons.translate_rounded,
                    title: "Language",
                    trailingText: langName,
                    onTap: () {
                      _showLanguageBottomSheet();
                    },
                  ),
                  ValueListenableBuilder(
                    valueListenable: isDarkTheme,
                    builder: (context, v, c) {
                      final bool isDark = v == true;
                      return _buildMenuTile(
                        icon: isDark
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                        title: "Dark Theme",
                        isSwitch: true,
                        switchValue: v,
                        onSwitchChanged: (value) {
                          context.read<AppThemeCubit>().changeTheme(
                              value ? AppTheme.dark : AppTheme.light);
                          setState(() {
                            isDarkTheme.value = value;
                          });
                        },
                        onTap: () {
                          final newVal = !isDark;
                          context.read<AppThemeCubit>().changeTheme(
                              newVal ? AppTheme.dark : AppTheme.light);
                          setState(() {
                            isDarkTheme.value = newVal;
                          });
                        },
                      );
                    },
                  ),

                  _buildSectionDivider(),

                  // GROUP 4: Content & Support
                  _buildMenuTile(
                    icon: Icons.article_outlined,
                    title: "Blogs",
                    onTap: () {
                      UiUtils.checkUser(
                        onNotGuest: () {
                          Navigator.pushNamed(
                              context, Routes.blogsScreenRoute);
                        },
                        context: context,
                      );
                    },
                  ),
                  _buildMenuTile(
                    icon: Icons.headset_mic_outlined,
                    title: "Support",
                    onTap: () {
                      Navigator.pushNamed(context, Routes.faqsScreen);
                    },
                  ),
                  _buildMenuTile(
                    icon: Icons.phone_outlined,
                    title: "Call Us",
                    onTap: () {
                      _showCallUsDialog();
                    },
                  ),
                  _buildMenuTile(
                    icon: Icons.gavel_outlined,
                    title: "Legal Hub",
                    onTap: () {
                      _showLegalHubBottomSheet();
                    },
                  ),
                  if (isAuthenticated)
                    _buildMenuTile(
                      icon: Icons.logout_rounded,
                      title: "Log out",
                      textColor: Colors.red,
                      iconColor: Colors.red,
                      onTap: () {
                        logOutConfirmWidget();
                      },
                    )
                  else
                    _buildMenuTile(
                      icon: Icons.login_rounded,
                      title: "Log in",
                      textColor: context.color.territoryColor,
                      iconColor: context.color.territoryColor,
                      onTap: () {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          Routes.login,
                          (route) => false,
                        );
                      },
                    ),

                  const SizedBox(height: 24),

                  // 4. Build Version
                  Center(
                    child: Text(
                      "Build Version - $_appVersion",
                      style: TextStyle(
                        fontSize: 12,
                        color: context.color.textLightColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void shareApp() {
    try {
      if (Platform.isAndroid) {
        Share.share(
            '${Constant.appName}\n${Constant.playstoreURLAndroid}\n${Constant.shareappText}',
            subject: Constant.appName);
      } else {
        Share.share(
            '${Constant.appName}\n${Constant.appstoreURLios}\n${Constant.shareappText}',
            subject: Constant.appName,
            sharePositionOrigin: Rect.fromLTWH(
                0,
                0,
                MediaQuery.of(context).size.width,
                MediaQuery.of(context).size.height / 2));
      }
    } catch (e) {
      HelperUtils.showSnackBarMessage(context, e.toString());
    }
  }

  Future<void> rateUs() => _inAppReview.openStoreListing(
      appStoreId: Constant.iOSAppId, microsoftStoreId: 'microsoftStoreId');

  void logOutConfirmWidget() {
    UiUtils.showBlurredDialoge(
      context,
      dialoge: BlurredDialogBox(
        title: "confirmLogoutTitle".translate(context),
        onAccept: () async {
          Future.delayed(
            Duration.zero,
            () {
              HiveUtils.clear();
              Constant.favoriteItemList.clear();
              context.read<UserDetailsCubit>().clear();
              context.read<FavoriteCubit>().resetState();
              context.read<UpdatedReportItemCubit>().clearItem();
              context.read<GetBuyerChatListCubit>().resetState();
              context.read<BlockedUsersListCubit>().resetState();
              FetchMyPromotedItemsCubit.globalInstance?.resetState();
              HiveUtils.logoutUser(
                context,
                onLogout: () {},
              );
            },
          );
        },
        cancelTextColor: context.color.textColorDark,
        svgImagePath: AppIcons.logoutIcon,
        content: Text("confirmLogOutMsg".translate(context)),
      ),
    );
  }
}
