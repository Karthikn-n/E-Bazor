import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';

class ProfileMenuScreen extends StatefulWidget {
  const ProfileMenuScreen({super.key});

  static Route route(RouteSettings routeSettings) {
    return BlurredRouter(
      builder: (_) => const ProfileMenuScreen(),
    );
  }

  @override
  State<ProfileMenuScreen> createState() => _ProfileMenuScreenState();
}

class _ProfileMenuScreenState extends State<ProfileMenuScreen> {
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
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 15.0),
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

  void _openPublicProfile() {
    UiUtils.checkUser(
      onNotGuest: () {
        final userDetails = HiveUtils.getUserDetails();
        final user = User(
          id: userDetails.id,
          name: userDetails.name,
          mobile: userDetails.mobile,
          email: userDetails.email,
          type: userDetails.type,
          profile: userDetails.profile,
          createdAt: userDetails.createdAt,
          updatedAt: userDetails.updatedAt,
          isVerified: userDetails.isVerified,
        );

        Navigator.pushNamed(
          context,
          Routes.sellerProfileScreen,
          arguments: {
            'model': user,
          },
        );
      },
      context: context,
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
          title: "profileTab".translate(context),
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
                  icon: Icons.person_outline_rounded,
                  title: "myProfile".translate(context),
                  onTap: () {
                    UiUtils.checkUser(
                      onNotGuest: () {
                        HelperUtils.goToNextPage(
                          Routes.completeProfile,
                          context,
                          false,
                          args: {"from": "profile"},
                        );
                      },
                      context: context,
                    );
                  },
                ),
                
                _buildItemTile(
                  icon: Icons.location_on_outlined,
                  title: "myAddresses".translate(context),
                  onTap: () {
                    UiUtils.checkUser(
                      onNotGuest: () {
                        Navigator.pushNamed(
                            context, Routes.userAddressListScreen);
                      },
                      context: context,
                    );
                  },
                ),
                _buildItemTile(
                  icon: Icons.public_outlined,
                  title: "myPublicProfile".translate(context),
                  onTap: _openPublicProfile,
                ),
                _buildItemTile(
                  icon: Icons.work_outline,
                  title: "myJobProfile".translate(context),
                  onTap: () {
                    UiUtils.checkUser(
                        onNotGuest: () => Navigator.pushNamed(
                            context, Routes.myJobProfileScreen),
                        context: context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
