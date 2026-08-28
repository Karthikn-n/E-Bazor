import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/seller/fetch_verification_request_cubit.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_keys.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

class VerificationBanner extends StatelessWidget {
  final EdgeInsetsGeometry padding;

  const VerificationBanner({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
  });

  void _handleBannerTap(BuildContext context, FetchVerificationRequestState state) {
    if (!HiveUtils.isUserAuthenticated()) {
      UiUtils.checkUser(onNotGuest: () {}, context: context);
      return;
    }

    if (HiveUtils.getUserDetails().isVerified == 1) {
      HelperUtils.showSnackBarMessage(
        context,
        "Your account is already verified!",
        type: MessageType.success,
      );
      return;
    }

    if (state is FetchVerificationRequestSuccess) {
      final status = state.data.status?.trim().toLowerCase();
      if (status == 'approved') {
        HelperUtils.showSnackBarMessage(
          context,
          "Your account is already verified!",
          type: MessageType.success,
        );
        return;
      }
      if (status == 'pending' || status == 'under review') {
        HelperUtils.showSnackBarMessage(
          context,
          'Your verification request is currently under review.',
          type: MessageType.warning,
        );
        return;
      }
      if (status == 'rejected') {
        Navigator.pushNamed(
          context,
          Routes.sellerVerificationScreen,
          arguments: {'isResubmitted': true},
        );
        return;
      }
    }

    Navigator.pushNamed(
      context,
      Routes.chooseOtpMethodScreen,
      arguments: {
        'phoneNumber': HiveUtils.getUserDetails().mobile ?? '',
        'verificationPurpose': 'sellerVerification',
        'isFromSellerVerification': true,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FetchVerificationRequestsCubit,
        FetchVerificationRequestState>(
      builder: (context, state) {
        return ValueListenableBuilder(
          valueListenable: Hive.box(HiveKeys.userDetailsBox).listenable(),
          builder: (context, Box box, _) {
            final requestApproved = state is FetchVerificationRequestSuccess &&
                state.data.status?.trim().toLowerCase() == 'approved';
            final userVerified = HiveUtils.getUserDetails().isVerified == 1;
            if (requestApproved || userVerified) {
              return const SizedBox.shrink();
            }

            return GestureDetector(
              onTap: () => _handleBannerTap(context, state),
              child: Padding(
                padding: padding,
                child: Material(
                  elevation: 6,
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    "assets/verifiedBanner.png",
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

