import 'dart:io';
import 'dart:ui' as ui;
import 'package:Ebozor/app/app_theme.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/system/app_theme_cubit.dart';
import 'package:Ebozor/data/cubits/system/fetch_system_settings_cubit.dart';
import 'package:Ebozor/data/cubits/system/user_details.dart';
import 'package:Ebozor/ui/screens/main_activity.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_keys.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/data/cubits/chat/blocked_users_list_cubit.dart';
import 'package:Ebozor/data/cubits/favorite/favorite_cubit.dart';
import 'package:Ebozor/data/cubits/seller/fetch_verification_request_cubit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import 'package:Ebozor/data/cubits/report/update_report_items_list_cubit.dart';
import 'package:Ebozor/data/cubits/auth/authentication_cubit.dart';
import 'package:Ebozor/data/cubits/auth/delete_user_cubit.dart';
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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  bool isExpanded = false;
  String _appVersion = "";

  @override
  void initState() {
    var settings = context.read<FetchSystemSettingsCubit>();
    //userData();
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
    super.initState();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = "v${packageInfo.version}+${packageInfo.buildNumber}";
        });
      }
    } catch (e) {
      debugPrint("Error loading package info: $e");
    }
  }

/*  void userData() {
    if (HiveUtils.isUserAuthenticated()) {
      username = (HiveUtils.getUserDetails().name ?? "").firstUpperCase();
      email = ((HiveUtils.getUserDetails().email ?? ""));
    } else {
      Future.delayed(Duration.zero, () {
        username = "anonymous".translate(context);
        email = "loginFirst".translate(context);
      });
    }
  }*/

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

  Widget setIconButtons({
    required String assetName,
    required void Function() onTap,
    Color? color,
    double? height,
    double? width,
  }) {
    return Container(
      height: 36,
      width: 36,
      alignment: AlignmentDirectional.center,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: context.color.textDefaultColor.withValues(alpha: 0.1))),
      child: InkWell(
          onTap: onTap,
          child: SvgPicture.asset(
            assetName,
            height: 24,
            width: 24,
            colorFilter: color == null
                ? ColorFilter.mode(
                    context.color.territoryColor, BlendMode.srcIn)
                : ColorFilter.mode(color, BlendMode.srcIn),
          )),
    );
  }

  Widget getProfileImage() {
    if (HiveUtils.isUserAuthenticated()) {
      if ((HiveUtils.getUserDetails().profile ?? "").isEmpty) {
        return UiUtils.getSvg(
          AppIcons.defaultPersonLogo,
          color: context.color.territoryColor,
          fit: BoxFit.none,
        );
      } else {
        return UiUtils.getImage(
          height: 100,
          width: 100,
          HiveUtils.getUserDetails().profile!,
          fit: BoxFit.cover,
        );
      }
    } else {
      return UiUtils.getSvg(
        AppIcons.defaultPersonLogo,
        color: context.color.territoryColor,
        fit: BoxFit.none,
      );
    }
  }

  String sellerStatus(String status) {
    if (status == 'pending') {
      return 'underReview'.translate(context);
    } else if (status == 'approved') {
      return 'approved'.translate(context);
    } else if (status == 'rejected') {
      return 'rejected'.translate(context);
    } else if (status == 'resubmitted') {
      return 'resubmitted'.translate(context);
    } else {
      return '';
    }
  }

  @override
  bool get wantKeepAlive => true;

  Widget profileHeader() {
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
            if (isAuthenticated && user.createdAt != null && user.createdAt!.isNotEmpty) {
              final parsed = DateTime.tryParse(user.createdAt!);
              if (parsed != null) {
                joinedDate = "Joined on ${DateFormat('MMMM yyyy').format(parsed)}";
              }
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
                  Stack(
                    children: [
                      Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.color.territoryColor.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          backgroundColor: context.color.territoryColor.withValues(alpha: 0.08),
                          radius: 32,
                          child: isAuthenticated
                              ? ((user.profile ?? "").isEmpty
                                  ? UiUtils.getSvg(
                                      AppIcons.defaultPersonLogo,
                                      color: context.color.territoryColor,
                                      fit: BoxFit.none,
                                    )
                                  : UiUtils.getImage(
                                      height: 64,
                                      width: 64,
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
                                  Routes.completeProfile, context, false,
                                  args: {"from": "profile"});
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: context.color.territoryColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.color.secondaryColor,
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAuthenticated
                              ? (user.name ?? 'User')
                              : "anonymous".translate(context),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: context.color.textColorDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        if (isAuthenticated) ...[
                          if (isVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: context.color.forthColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
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
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: context.color.forthColor,
                                    ),
                                  ),
                                ],
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
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: context.color.borderColor.withValues(alpha: 0.8),
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
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 14,
                                      color: context.color.textLightColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                        if (joinedDate.isNotEmpty) ...[
                          const SizedBox(height: 4),
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
          });
    });
  }

  Widget _buildCardBox({required List<Widget> children}) {
    final validChildren = children
        .where((w) => w is! SizedBox || (w.height != 0 && w.width != 0))
        .toList();
    if (validChildren.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(validChildren.length, (index) {
          return Column(
            children: [
              validChildren[index],
              if (index < validChildren.length - 1)
                Divider(
                  height: 1,
                  thickness: 0.7,
                  indent: 60,
                  endIndent: 14,
                  color: context.color.borderColor.withValues(alpha: 0.35),
                ),
            ],
          );
        }),
      ),
    );
  }

  void _handleJobProfileTap() {
    final user = HiveUtils.getUserDetails();
    showModalBottomSheet(
      context: context,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.color.territoryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.work_outline_rounded,
                        color: context.color.territoryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "My Job Profile",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: context.color.textDefaultColor,
                            ),
                          ),
                          Text(
                            user.name ?? "Job Seeker",
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
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.color.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.color.borderColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Email",
                            style: TextStyle(
                              fontSize: 13,
                              color: context.color.textLightColor,
                            ),
                          ),
                          Text(
                            user.email ?? "Not added",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.color.textDefaultColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Mobile",
                            style: TextStyle(
                              fontSize: 13,
                              color: context.color.textLightColor,
                            ),
                          ),
                          Text(
                            user.mobile ?? "Not added",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.color.textDefaultColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Verified Candidate",
                            style: TextStyle(
                              fontSize: 13,
                              color: context.color.textLightColor,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                user.isVerified == 1
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_outlined,
                                size: 16,
                                color: user.isVerified == 1
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                user.isVerified == 1 ? "Verified" : "Unverified",
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: user.isVerified == 1
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(bottomSheetCtx);
                      HelperUtils.goToNextPage(
                        Routes.completeProfile,
                        context,
                        false,
                        args: {"from": "profile"},
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.color.territoryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      "Edit Profile & Resume Info",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _testCategoriesApi() async {
    HelperUtils.showSnackBarMessage(
      context,
      "Calling GET /api/get-categories...",
    );

    try {
      final response = await Api.get(
        url: Api.getCategoriesApi,
        queryParameters: {},
      );

      final total = response['data']?['total'] ??
          (response['data'] is List ? (response['data'] as List).length : 0);

      if (mounted) {
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            backgroundColor: context.color.secondaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  "getCategories API Success",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Endpoint: GET /api/get-categories\nTotal Categories Returned: $total\nResponse status: ${response['error'] == false ? '200 OK' : 'Error'}",
                      style: TextStyle(
                        fontSize: 13,
                        color: context.color.textDefaultColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.color.backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        response.toString().length > 600
                            ? "${response.toString().substring(0, 600)}...\n[truncated]"
                            : response.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: context.color.textLightColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(
                  "Close",
                  style: TextStyle(color: context.color.territoryColor),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          "GET /api/get-categories failed: $e",
          type: MessageType.error,
        );
      }
    }
  }

  Future<void> _testHomeCategoriesApi() async {
    HelperUtils.showSnackBarMessage(
      context,
      "Calling GET /api/get-home-categories...",
    );

    try {
      final response = await Api.get(
        url: Api.getHomeCategoriesApi,
        queryParameters: {},
      );

      final total = response['data']?['total'] ??
          (response['data'] is List
              ? (response['data'] as List).length
              : (response['data'] is Map ? (response['data'] as Map).length : 0));

      if (mounted) {
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            backgroundColor: context.color.secondaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  "getHomeCategories Response",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Endpoint: GET /api/get-home-categories\nTotal Elements: $total\nResponse error: ${response['error']}",
                      style: TextStyle(
                        fontSize: 13,
                        color: context.color.textDefaultColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.color.backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        response.toString().length > 800
                            ? "${response.toString().substring(0, 800)}...\n[truncated]"
                            : response.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: context.color.textLightColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(
                  "Close",
                  style: TextStyle(color: context.color.territoryColor),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          "GET /api/get-home-categories failed: $e",
          type: MessageType.error,
        );
      }
    }
  }

  customTile(
    BuildContext context, {
    required String title,
    required VoidCallback onTap,
    String? svgImage,
    IconData? iconData,
    bool? isSwitchBox,
    Function(dynamic value)? onTapSwitch,
    dynamic switchValue,
    Color? color,
    BorderRadius? borderRadius,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      clipBehavior: borderRadius != null ? Clip.antiAlias : Clip.none,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: (color ?? context.color.territoryColor).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: iconData != null
                      ? Icon(
                          iconData,
                          size: 19,
                          color: color ?? context.color.textColorDark,
                        )
                      : UiUtils.getSvg(
                          svgImage!,
                          color: color ?? context.color.textColorDark,
                          width: 17,
                          height: 17,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color ?? context.color.textDefaultColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isSwitchBox == true)
                Switch(
                  value: switchValue ?? false,
                  onChanged: onTapSwitch,
                  activeColor: Colors.white,
                  activeTrackColor: context.color.territoryColor,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.grey.shade400,
                  trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                )
              else
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: context.color.textLightColor.withValues(alpha: 0.8),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              children: <Widget>[
                profileHeader(),
                const SizedBox(height: 14),

                // BOX 1: Profile & Personal Details
                if (HiveUtils.isUserAuthenticated())
                  _buildCardBox(
                    children: [
                      customTile(
                        context,
                        title: "editprofile".translate(context),
                        iconData: Icons.person_outline_rounded,
                        onTap: () {
                          HelperUtils.goToNextPage(
                              Routes.completeProfile, context, false,
                              args: {"from": "profile"});
                        },
                      ),
                      customTile(
                        context,
                        title: "Addresses",
                        iconData: Icons.location_on_outlined,
                        onTap: () {
                          Navigator.pushNamed(
                              context, Routes.userAddressListScreen);
                        },
                      ),
                      customTile(
                        context,
                        title: "My Job Profile",
                        iconData: Icons.work_outline_rounded,
                        onTap: () {
                          _handleJobProfileTap();
                        },
                      ),
                      customTile(
                        context,
                        title: "blockedUsers".translate(context),
                        iconData: Icons.person_off_outlined,
                        onTap: () {
                          Navigator.pushNamed(
                              context, Routes.blockedUserListScreen);
                        },
                      ),
                    ],
                  ),

                // BOX 2: Settings (App Related)
                _buildCardBox(
                  children: [
                    customTile(
                      context,
                      title: "notifications".translate(context),
                      iconData: Icons.notifications_none_rounded,
                      onTap: () {
                        UiUtils.checkUser(
                          onNotGuest: () {
                            Navigator.pushNamed(context, Routes.notificationPage);
                          },
                          context: context,
                        );
                      },
                    ),
                    customTile(
                      context,
                      title: "language".translate(context),
                      iconData: Icons.translate_rounded,
                      onTap: () {
                        Navigator.pushNamed(
                            context, Routes.languageListScreenRoute);
                      },
                    ),
                    ValueListenableBuilder(
                      valueListenable: isDarkTheme,
                      builder: (context, v, c) {
                        final bool isDark = v == true;
                        return customTile(
                          context,
                          title: "darkTheme".translate(context),
                          iconData: isDark
                              ? Icons.dark_mode_outlined
                              : Icons.light_mode_outlined,
                          isSwitchBox: true,
                          onTapSwitch: (value) {
                            context.read<AppThemeCubit>().changeTheme(
                                value == true ? AppTheme.dark : AppTheme.light);
                            setState(() {
                              isDarkTheme.value = value;
                            });
                          },
                          switchValue: v,
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
                  ],
                ),

                // BOX 3: Activity & Commercials
                _buildCardBox(
                  children: [
                    customTile(
                      context,
                      title: "myAds".translate(context).isNotEmpty
                          ? "myAds".translate(context)
                          : "My Ads",
                      iconData: Icons.view_list_rounded,
                      onTap: () {
                        APICallTrigger.trigger();
                        UiUtils.checkUser(
                          onNotGuest: () {
                            Navigator.pushNamed(
                                context, Routes.myAdvertisment,
                                arguments: {"fromProfile": true});
                          },
                          context: context,
                        );
                      },
                    ),
                    customTile(
                      context,
                      title: "favorites".translate(context),
                      iconData: Icons.favorite_border_rounded,
                      onTap: () {
                        UiUtils.checkUser(
                          onNotGuest: () {
                            Navigator.pushNamed(context, Routes.favoritesScreen);
                          },
                          context: context,
                        );
                      },
                    ),
                    customTile(
                      context,
                      title: "myReview".translate(context).isNotEmpty
                          ? "myReview".translate(context)
                          : "My Reviews",
                      iconData: Icons.rate_review_outlined,
                      onTap: () {
                        UiUtils.checkUser(
                          onNotGuest: () {
                            Navigator.pushNamed(context, Routes.myReviewsScreen);
                          },
                          context: context,
                        );
                      },
                    ),
                    customTile(
                      context,
                      title: "transactionHistory".translate(context).isNotEmpty
                          ? "transactionHistory".translate(context)
                          : "Transaction History",
                      iconData: Icons.receipt_long_outlined,
                      onTap: () {
                        UiUtils.checkUser(
                          onNotGuest: () {
                            Navigator.pushNamed(
                                context, Routes.transactionHistory);
                          },
                          context: context,
                        );
                      },
                    ),
                  ],
                ),

                // BOX 4: Support & Test Tools
                _buildCardBox(
                  children: [
                    customTile(
                      context,
                      title: "blogs".translate(context),
                      iconData: Icons.article_outlined,
                      onTap: () {
                        UiUtils.checkUser(
                          onNotGuest: () {
                            Navigator.pushNamed(context, Routes.blogsScreenRoute);
                          },
                          context: context,
                        );
                      },
                    ),
                    customTile(
                      context,
                      title: "faqsLbl".translate(context),
                      iconData: Icons.help_outline_rounded,
                      onTap: () {
                        UiUtils.checkUser(
                          onNotGuest: () {
                            Navigator.pushNamed(context, Routes.faqsScreen);
                          },
                          context: context,
                        );
                      },
                    ),
                    customTile(
                      context,
                      title: "contactUs".translate(context),
                      iconData: Icons.headset_mic_outlined,
                      onTap: () {
                        Navigator.pushNamed(context, Routes.contactUs);
                      },
                    ),
                    customTile(
                      context,
                      title: "Test get-home-categories API",
                      iconData: Icons.category_rounded,
                      color: Colors.indigo.shade700,
                      onTap: () {
                        _testHomeCategoriesApi();
                      },
                    ),
                  ],
                ),

                // BOX 5: Legal & About
                _buildCardBox(
                  children: [
                    customTile(
                      context,
                      title: "aboutUs".translate(context),
                      iconData: Icons.info_outline_rounded,
                      onTap: () {
                        Navigator.pushNamed(context, Routes.profileSettings, arguments: {
                          'title': "aboutUs".translate(context),
                          'param': Api.aboutUs,
                        });
                      },
                    ),
                    customTile(
                      context,
                      title: "termsConditions".translate(context),
                      iconData: Icons.description_outlined,
                      onTap: () {
                        Navigator.pushNamed(context, Routes.profileSettings, arguments: {
                          'title': "termsConditions".translate(context),
                          'param': Api.termsAndConditions,
                        });
                      },
                    ),
                    customTile(
                      context,
                      title: "privacyPolicy".translate(context),
                      iconData: Icons.privacy_tip_outlined,
                      onTap: () {
                        Navigator.pushNamed(context, Routes.profileSettings, arguments: {
                          'title': "privacyPolicy".translate(context),
                          'param': Api.privacyPolicy,
                        });
                      },
                    ),
                    customTile(
                      context,
                      title: "shareApp".translate(context),
                      iconData: Icons.share_outlined,
                      onTap: shareApp,
                    ),
                    customTile(
                      context,
                      title: "rateUs".translate(context),
                      iconData: Icons.star_outline_rounded,
                      onTap: rateUs,
                    ),
                    if (Constant.isUpdateAvailable == true)
                      updateTile(
                        context,
                        isUpdateAvailable: Constant.isUpdateAvailable,
                        title: "update".translate(context),
                        newVersion: Constant.newVersionNumber,
                        svgImagePath: AppIcons.update,
                        onTap: () async {
                          if (Platform.isIOS) {
                            await launchUrl(Uri.parse(Constant.appstoreURLios));
                          } else if (Platform.isAndroid) {
                            await launchUrl(Uri.parse(Constant.playstoreURLAndroid));
                          }
                        },
                      ),
                  ],
                ),

                // BOX 6: Account Actions (Logout / Delete)
                if (HiveUtils.isUserAuthenticated())
                  _buildCardBox(
                    children: [
                      customTile(
                        context,
                        title: "deleteAccount".translate(context),
                        iconData: Icons.delete_outline_rounded,
                        color: Colors.red,
                        onTap: () {
                          if (Constant.isDemoModeOn) {
                            if (HiveUtils.getUserDetails().mobile != null &&
                                Constant.demoMobileNumber ==
                                    (HiveUtils.getUserDetails().mobile!.replaceFirst(
                                        "+${HiveUtils.getCountryCode()}", ""))) {
                              HelperUtils.showSnackBarMessage(context,
                                  "thisActionNotValidDemo".translate(context));
                              return;
                            }
                          }
                          deleteConfirmWidget();
                        },
                      ),
                      customTile(
                        context,
                        title: "logout".translate(context),
                        iconData: Icons.logout_rounded,
                        color: Colors.red,
                        onTap: () {
                          logOutConfirmWidget();
                        },
                      ),
                    ],
                  ),
                if (_appVersion.isNotEmpty) ...[
                  const SizedBox(height: 16),
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
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget updateTile(BuildContext context,
      {required String title,
      required String newVersion,
      required bool isUpdateAvailable,
      required String svgImagePath,
      Function(dynamic value)? onTapSwitch,
      dynamic switchValue,
      required VoidCallback onTap}) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            if (isUpdateAvailable) {
              onTap.call();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 13.0),
            child: Row(
              children: [
                UiUtils.getSvg(svgImagePath,
                    height: 20,
                    width: 20,
                    color: context.color.territoryColor),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    isUpdateAvailable == false ? "uptoDate".translate(context) : title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: context.color.textColorDark,
                    ),
                  ),
                ),
                if (isUpdateAvailable)
                  Text("v$newVersion", style: TextStyle(color: context.color.textLightColor, fontSize: 13)),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: context.color.textLightColor,
                ),
              ],
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 0.8,
          color: context.color.borderColor.withValues(alpha: 0.35),
        ),
      ],
    );
  }

  deleteConfirmWidget() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: context.color.secondaryColor,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.delete_forever_rounded,
                      color: Colors.red,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "deleteProfileMessageTitle".translate(context),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "This action is permanent and cannot be undone. All your ads, messages, saved preferences, and account history will be permanently deleted.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: context.color.textLightColor,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(
                            color: context.color.borderColor.withValues(alpha: 0.8),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(
                          "cancelLbl".translate(context),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.color.textDefaultColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          (_auth.currentUser != null)
                              ? proceedToDeleteProfile()
                              : askToLoginAgain();
                        },
                        child: Text(
                          "deleteBtnLbl".translate(context),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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

  askToLoginAgain() {
    HelperUtils.showSnackBarMessage(context, 'loginReqMsg'.translate(context));
    HiveUtils.clear();
    Constant.favoriteItemList.clear();
    context.read<UserDetailsCubit>().clear();
    context.read<FavoriteCubit>().resetState();
    context.read<UpdatedReportItemCubit>().clearItem();
    context.read<GetBuyerChatListCubit>().resetState();
    context.read<BlockedUsersListCubit>().resetState();
    HiveUtils.logoutUser(
      context,
      onLogout: () {},
    );
    Navigator.of(context)
        .pushNamedAndRemoveUntil(Routes.login, (route) => false);
  }

  Future<void> signOut(AuthenticationType? type) async {
    if (type == AuthenticationType.google) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }

  proceedToDeleteProfile() async {
    //delete user from firebase
    try {
      await _auth.currentUser!.delete().then((value) {
        //delete user prefs from App-local
        context.read<DeleteUserCubit>().deleteUser().then((value) {
          HelperUtils.showSnackBarMessage(context, (value["message"]));
          for (int i = 0; i < AuthenticationType.values.length; i++) {
            if (AuthenticationType.values[i].name ==
                HiveUtils.getUserDetails().type) {
              signOut(AuthenticationType.values[i]).then((value) {
                HiveUtils.clear();
                Constant.favoriteItemList.clear();
                context.read<UserDetailsCubit>().clear();
                context.read<FavoriteCubit>().resetState();
                context.read<UpdatedReportItemCubit>().clearItem();
                context.read<GetBuyerChatListCubit>().resetState();
                context.read<BlockedUsersListCubit>().resetState();

                HiveUtils.logoutUser(
                  context,
                  onLogout: () {},
                );
                Navigator.of(context)
                    .pushNamedAndRemoveUntil(Routes.login, (route) => false);
              });
            }
          }
        });
      });
    } on FirebaseAuthException catch (error) {
      if (error.code == "requires-recent-login") {
        for (int i = 0; i < AuthenticationType.values.length; i++) {
          if (AuthenticationType.values[i].name ==
              HiveUtils.getUserDetails().type) {
            signOut(AuthenticationType.values[i]).then((value) {
              HiveUtils.clear();
              Constant.favoriteItemList.clear();
              context.read<UserDetailsCubit>().clear();
              context.read<FavoriteCubit>().resetState();
              context.read<UpdatedReportItemCubit>().clearItem();
              context.read<GetBuyerChatListCubit>().resetState();
              context.read<BlockedUsersListCubit>().resetState();
              HiveUtils.logoutUser(
                context,
                onLogout: () {},
              );
              Navigator.of(context)
                  .pushNamedAndRemoveUntil(Routes.login, (route) => false);
            });
          }
        }
      } else {
        throw HelperUtils.showSnackBarMessage(context, '${error.message}');
      }
    } catch (e) {
      debugPrint("unable to delete user - ${e.toString()}");
    }
  }

  Widget profileImgWidget() {
    return GestureDetector(
      onTap: () {
        if (HiveUtils.getUserDetails().profile != "" &&
            HiveUtils.getUserDetails().profile != null) {
          UiUtils.showFullScreenImage(
            context,
            provider: NetworkImage(
                context.read<UserDetailsCubit>().state.user?.profile ?? ""),
          );
        }
      },
      child: (context.watch<UserDetailsCubit>().state.user?.profile ?? "")
              .trim()
              .isEmpty
          ? buildDefaultPersonSVG(context)
          : Image.network(
              context.watch<UserDetailsCubit>().state.user?.profile ?? "",
              fit: BoxFit.cover,
              width: 49,
              height: 49,
              errorBuilder: (BuildContext context, Object exception,
                  StackTrace? stackTrace) {
                return buildDefaultPersonSVG(context);
              },
              loadingBuilder: (BuildContext context, Widget? child,
                  ImageChunkEvent? loadingProgress) {
                if (loadingProgress == null) return child!;
                return buildDefaultPersonSVG(context);
              },
            ),
    );
  }

  Widget buildDefaultPersonSVG(BuildContext context) {
    return Container(
      width: 49,
      height: 49,
      color: context.color.territoryColor.withValues(alpha: 0.1),
      child: FittedBox(
        fit: BoxFit.none,
        child: UiUtils.getSvg(AppIcons.defaultPersonLogo,
            color: context.color.territoryColor, width: 30, height: 30),
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

/*  Future<void> rateUs() async {
    LaunchReview.launch(
      androidAppId: Constant.androidPackageName,
      iOSAppId: Constant.iOSAppId,
    );
  }*/

  Future<void> rateUs() => _inAppReview.openStoreListing(
      appStoreId: Constant.iOSAppId, microsoftStoreId: 'microsoftStoreId');

  void logOutConfirmWidget() {
    UiUtils.showBlurredDialoge(context,
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
                  HiveUtils.logoutUser(
                    context,
                    onLogout: () {},
                  );
                },
              );
            },
            cancelTextColor: context.color.textColorDark,
            svgImagePath: AppIcons.logoutIcon,
            content: Text("confirmLogOutMsg".translate(context))));
  }
}
