import 'package:Ebozor/data/cubits/profile_setting_cubit.dart';
import 'package:Ebozor/data/helper/widgets.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileSettings extends StatefulWidget {
  final String? title;
  final String? param;

  const ProfileSettings({super.key, this.title, this.param});

  @override
  ProfileSettingsState createState() => ProfileSettingsState();

  static Route route(RouteSettings routeSettings) {
    Map? arguments = routeSettings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => ProfileSettings(
        title: arguments?['title'] as String,
        param: arguments?['param'] as String,
      ),
    );
  }
}

class ProfileSettingsState extends State<ProfileSettings> {
  @override
  void initState() {
    super.initState();

    Future.delayed(Duration.zero, () {
      context
          .read<ProfileSettingCubit>()
          .fetchProfileSetting(context, widget.param!, forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: UiUtils.buildAppBar(
        context,
        title: widget.title ?? "",
        showBackButton: true,
      ),
      body: BlocBuilder<ProfileSettingCubit, ProfileSettingState>(
        builder: (context, state) {
          if (state is ProfileSettingFetchProgress) {
            return Center(
              child: UiUtils.progress(
                normalProgressColor: context.color.territoryColor,
              ),
            );
          } else if (state is ProfileSettingFetchSuccess) {
            if (state.data.trim().isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 48,
                        color: context.color.textLightColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "No content available yet".translate(context),
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
            return contentWidget(state, context);
          } else if (state is ProfileSettingFetchFailure) {
            return Widgets.noDataFound(state.errmsg);
          } else {
            return const SizedBox.shrink();
          }
        },
      ),
    );
  }

  Widget contentWidget(ProfileSettingFetchSuccess state, BuildContext context) {
    final textColor = context.color.textDefaultColor;
    final primaryColor = context.color.territoryColor;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.color.borderColor.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: HtmlWidget(
          state.data.toString(),
          textStyle: TextStyle(
            color: textColor,
            fontSize: 14.5,
            height: 1.6,
          ),
          onTapUrl: (url) => launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          ),
          customStylesBuilder: (element) {
            if (element.localName == 'h1' ||
                element.localName == 'h2' ||
                element.localName == 'h3') {
              return {
                'color': '#${primaryColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
                'font-weight': '700',
                'margin-top': '16px',
                'margin-bottom': '8px',
              };
            }
            if (element.localName == 'a') {
              return {
                'color': '#1E88E5',
                'text-decoration': 'underline',
              };
            }
            if (element.localName == 'table') {
              return {
                'border': '1px solid #E0E0E0',
                'border-collapse': 'collapse',
                'width': '100%',
                'margin': '12px 0',
              };
            }
            if (element.localName == 'th') {
              return {
                'background-color': '#F5F5F5',
                'border': '1px solid #E0E0E0',
                'padding': '8px',
                'font-weight': 'bold',
              };
            }
            if (element.localName == 'td') {
              return {
                'border': '1px solid #E0E0E0',
                'padding': '8px',
              };
            }
            return null;
          },
        ),
      ),
    );
  }
}
