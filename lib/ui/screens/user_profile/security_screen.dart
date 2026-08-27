import 'dart:io';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/auth/user_devices_cubit.dart';
import 'package:Ebozor/data/model/user_device_model.dart';
import 'package:Ebozor/ui/screens/user_profile/email_sent_screen.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  static Route route(RouteSettings routeSettings) {
    return BlurredRouter(
      builder: (_) => BlocProvider(
        create: (_) => UserDevicesCubit()..fetchDevices(),
        child: const SecurityScreen(),
      ),
    );
  }

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _isResettingPassword = false;

  Future<void> _handlePasswordReset() async {
    final user = HiveUtils.getUserDetails();
    final email = user.email?.trim() ?? "";

    if (email.isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        "noEmailAssociated".translate(context),
        type: MessageType.error,
      );
      return;
    }

    setState(() {
      _isResettingPassword = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        setState(() {
          _isResettingPassword = false;
        });
        EmailSentScreen.show(context, email: email);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isResettingPassword = false;
        });
        // If Firebase error, show user friendly message or still show email sent
        HelperUtils.showSnackBarMessage(
          context,
          e.toString(),
          type: MessageType.error,
        );
      }
    }
  }

  void _showSecureAccountBottomSheet() {
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
                // Drag handle
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

                // Shield Header
                Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 24,
                      color: context.color.textDefaultColor,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "secureYourAccount".translate(context),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: context.color.borderColor.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  "secureAccountDesc".translate(context),
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    color: context.color.textDefaultColor.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: context.color.borderColor.withValues(alpha: 0.8),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => Navigator.pop(bottomSheetCtx),
                        child: Text(
                          "close".translate(context),
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
                      flex: 6,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E2026),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(bottomSheetCtx);
                          _handlePasswordReset();
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "updatePassword".translate(context),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
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

  @override
  Widget build(BuildContext context) {
    final user = HiveUtils.getUserDetails();
    final userEmail = user.email ?? "Not provided";

    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: Scaffold(
        backgroundColor: context.color.backgroundColor,
        appBar: UiUtils.buildAppBar(
          context,
          title: "security".translate(context),
          showBackButton: true,
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Email Section
                Text(
                  "emailLbl".translate(context),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  userEmail,
                  style: TextStyle(
                    fontSize: 14.5,
                    color: context.color.textLightColor,
                  ),
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: context.color.borderColor.withValues(alpha: 0.35),
                ),
                const SizedBox(height: 16),

                // 2. Password Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "password".translate(context),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: context.color.textDefaultColor,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _isResettingPassword ? null : _handlePasswordReset,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "•••••••••",
                  style: TextStyle(
                    fontSize: 18,
                    letterSpacing: 2,
                    color: context.color.textDefaultColor.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: context.color.borderColor.withValues(alpha: 0.35),
                ),
                const SizedBox(height: 16),

                // Blocked Users Tile
                InkWell(
                  onTap: () {
                    Navigator.pushNamed(context, Routes.blockedUserListScreen);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "blockedUsers".translate(context),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: context.color.textDefaultColor,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: context.color.textLightColor,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: context.color.borderColor.withValues(alpha: 0.35),
                ),
                const SizedBox(height: 24),

                // 3. Your Devices Section
                Text(
                  "yourDevices".translate(context),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "yourDevicesDesc".translate(context),
                  style: TextStyle(
                    fontSize: 13.5,
                    color: context.color.textLightColor,
                  ),
                ),
                const SizedBox(height: 14),

                // Secure your account button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: context.color.borderColor.withValues(alpha: 0.8),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _showSecureAccountBottomSheet,
                    child: Text(
                      "secureYourAccount".translate(context),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Device List from API (GET /api/get-devices)
                BlocBuilder<UserDevicesCubit, UserDevicesState>(
                  builder: (context, state) {
                    if (state is UserDevicesFetchInProgress) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    List<UserDeviceModel> devices = [];
                    if (state is UserDevicesFetchSuccess && state.devices.isNotEmpty) {
                      devices = state.devices;
                    } else {
                      // Fallback current device
                      devices = [
                        UserDeviceModel(
                          id: 1,
                          deviceName:
                              "${Constant.appName} app from ${Platform.isAndroid ? 'Android' : 'iOS'}",
                          isCurrent: true,
                          location: HiveUtils.getCityName() ?? "UAE",
                          lastUsedAt: DateTime.now().toIso8601String(),
                        )
                      ];
                    }

                    return Column(
                      children: devices.map((device) {
                        final isCurrent = device.isCurrent == true;
                        final deviceName = device.deviceName ??
                            "${Constant.appName} app from ${Platform.isAndroid ? 'Android' : 'iOS'}";
                        final location = device.location ?? "activeSession".translate(context);
                        String addedDate = "${"addedOn".translate(context)} 27 Jul, 2026";
                        if (device.lastUsedAt != null) {
                          final parsed = DateTime.tryParse(device.lastUsedAt!);
                          if (parsed != null) {
                            addedDate =
                                "${"addedOn".translate(context)} ${DateFormat('d MMM, yyyy').format(parsed)}";
                          }
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.phone_android_rounded,
                                size: 26,
                                color: context.color.textDefaultColor.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isCurrent ? "$deviceName (${"thisDevice".translate(context)})" : deviceName,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                        color: context.color.textDefaultColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      location,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: context.color.textLightColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      addedDate,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: context.color.textLightColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isCurrent && device.id != null)
                                IconButton(
                                  icon: const Icon(
                                    Icons.logout_rounded,
                                    size: 20,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    final success = await context
                                        .read<UserDevicesCubit>()
                                        .logoutDevice(device.id!);
                                    if (mounted) {
                                      HelperUtils.showSnackBarMessage(
                                        context,
                                        success
                                            ? "Device logged out successfully"
                                            : "Failed to logout device",
                                      );
                                    }
                                  },
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
