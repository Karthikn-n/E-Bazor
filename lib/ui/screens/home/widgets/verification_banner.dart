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

    final requestApproved =
        state is FetchVerificationRequestSuccess && state.data.isApproved;
    final userVerified = HiveUtils.getUserDetails().isVerified == 1;

    if (userVerified || requestApproved) {
      HelperUtils.showSnackBarMessage(
        context,
        "Your account is already verified!",
        type: MessageType.success,
      );
      return;
    }

    if (state is FetchVerificationRequestSuccess) {
      if (state.data.isPending) {
        HelperUtils.showSnackBarMessage(
          context,
          'Your verification request is currently under review.',
          type: MessageType.warning,
        );
        return;
      }
      if (state.data.isRejected) {
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
            final requestApproved =
                state is FetchVerificationRequestSuccess && state.data.isApproved;
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

