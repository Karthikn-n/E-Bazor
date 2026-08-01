import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/ui/screens/home/home_screen.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';

class SellerIntroVerificationScreen extends StatefulWidget {
  final bool isResubmitted;
   SellerIntroVerificationScreen({super.key, required this.isResubmitted});

  @override
  State<SellerIntroVerificationScreen> createState() =>
      _SellerIntroVerificationScreenState();

  static Route route(RouteSettings routeSettings) {
    Map? arguments = routeSettings.arguments as Map?;
    return BlurredRouter(builder: (_) => SellerIntroVerificationScreen(isResubmitted: arguments?["isResubmitted"]));
  }
}

class _SellerIntroVerificationScreenState
    extends State<SellerIntroVerificationScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: context.color.backgroundColor,
        appBar: UiUtils.buildAppBar(context, showBackButton: true),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: mainBody(),
        ));
  }

  Widget mainBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: UiUtils.getSvg(
            AppIcons.userVerificationIcon,
          ),
        ),
        Text("userVerification".translate(context))
            .color(context.color.textDefaultColor)
            .size(context.font.extraLarge)
            .bold(weight: FontWeight.w600),
        SizedBox(height: 10,),
        Text(
          "userVerificationHeadline".translate(context),
          textAlign: TextAlign.center,
        ).color(context.color.textLightColor).size(context.font.normal),
        SizedBox(height: 10,),
        Text(
          "userVerificationHeadline1".translate(context),
          textAlign: TextAlign.center,
        )
            .color(context.color.textDefaultColor.withValues(alpha: 0.65))
            .size(context.font.normal)
            .bold(),
        SizedBox(height: 10,),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: sidePadding),
          child: UiUtils.buildButton(context, height: 46, radius: 8,
              onPressed: () {
            Navigator.pushNamed(
              context,
              Routes.sellerVerificationScreen,
                arguments: {"isResubmitted":widget.isResubmitted}
            );
          }, buttonTitle: "startVerification".translate(context)),
        ),

        InkWell(
          child: Text(
            "skipForLater".translate(context),
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
                decoration: TextDecoration.underline,
                color: context.color.textDefaultColor),
          ),
          onTap: () {
            Navigator.pop(context);
          },
        )
      ],
    );
  }
}
