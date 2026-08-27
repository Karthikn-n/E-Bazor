import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/auth/authentication_cubit.dart';
import 'package:Ebozor/data/cubits/auth/delete_user_cubit.dart';
import 'package:Ebozor/data/cubits/chat/blocked_users_list_cubit.dart';
import 'package:Ebozor/data/cubits/chat/get_buyer_chat_users_cubit.dart';
import 'package:Ebozor/data/cubits/favorite/favorite_cubit.dart';
import 'package:Ebozor/data/cubits/item/fetch_my_promoted_items_cubit.dart';
import 'package:Ebozor/data/cubits/report/update_report_items_list_cubit.dart';
import 'package:Ebozor/data/cubits/system/user_details.dart';
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
import 'package:google_sign_in/google_sign_in.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  static Route route(RouteSettings routeSettings) {
    return BlurredRouter(
      builder: (_) => const AccountSettingsScreen(),
    );
  }

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Widget _buildItemTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
    bool showChevron = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 14.0),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: iconColor ?? (textColor ?? context.color.textColorDark),
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
              if (showChevron)
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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: Scaffold(
        backgroundColor: context.color.backgroundColor,
        appBar: UiUtils.buildAppBar(
          context,
          title: "account".translate(context),
          showBackButton: true,
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildItemTile(
                  icon: Icons.phone_android_rounded,
                  title: "primaryPhoneNumber".translate(context),
                  onTap: () {
                    Navigator.pushNamed(context, Routes.phoneNumbersScreen);
                  },
                ),
                // _buildItemTile(
                //   icon: Icons.receipt_long_outlined,
                //   title: "transactionHistory".translate(context),
                //   onTap: () {
                //     Navigator.pushNamed(context, Routes.transactionHistory);
                //   },
                // ),
                Divider(
                  height: 32,
                  thickness: 0.8,
                  color: context.color.borderColor.withValues(alpha: 0.35),
                ),

                // Delete Account Tile at the bottom
                _buildItemTile(
                  icon: Icons.delete_outline_rounded,
                  title: "deleteAccount".translate(context),
                  textColor: Colors.red,
                  iconColor: Colors.red,
                  showChevron: true,
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
                    _deleteConfirmWidget();
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

  void _deleteConfirmWidget() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: context.color.secondaryColor,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                  "deleteAccountConfirmMsg".translate(context),
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
                            color: context.color.borderColor
                                .withValues(alpha: 0.8),
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
                              ? _proceedToDeleteProfile()
                              : _askToLoginAgain();
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

  void _askToLoginAgain() {
    HelperUtils.showSnackBarMessage(context, 'loginReqMsg'.translate(context));
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
    Navigator.of(context)
        .pushNamedAndRemoveUntil(Routes.login, (route) => false);
  }

  Future<void> _signOut(AuthenticationType? type) async {
    if (type == AuthenticationType.google) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }

  void _proceedToDeleteProfile() async {
    try {
      await _auth.currentUser!.delete().then((value) {
        context.read<DeleteUserCubit>().deleteUser().then((value) {
          HelperUtils.showSnackBarMessage(context, (value["message"]));
          for (int i = 0; i < AuthenticationType.values.length; i++) {
            if (AuthenticationType.values[i].name ==
                HiveUtils.getUserDetails().type) {
              _signOut(AuthenticationType.values[i]).then((value) {
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
            _signOut(AuthenticationType.values[i]).then((value) {
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
}
