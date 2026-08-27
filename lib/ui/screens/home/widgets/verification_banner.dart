import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/seller/fetch_verification_request_cubit.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class VerificationBanner extends StatefulWidget {
  final EdgeInsetsGeometry padding;

  const VerificationBanner({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
  });

  @override
  State<VerificationBanner> createState() => _VerificationBannerState();
}

class _VerificationBannerState extends State<VerificationBanner> {
  @override
  void initState() {
    super.initState();
    if (HiveUtils.isUserAuthenticated()) {
      final cubit = context.read<FetchVerificationRequestsCubit>();
      if (cubit.state is FetchVerificationRequestInitial) {
        cubit.fetchVerificationRequests();
      }
    }
  }

  void _handleBannerTap() {
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

    final requestState = context.read<FetchVerificationRequestsCubit>().state;
    if (requestState is FetchVerificationRequestSuccess) {
      final status =
          requestState.data.status?.trim().toLowerCase().replaceAll('_', ' ');
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
        if (state is FetchVerificationRequestSuccess) {
          if (state.data.status?.toLowerCase() == "approved" ||
              HiveUtils.getUserDetails().isVerified == 1) {
            return const SizedBox.shrink();
          }
        }

        return GestureDetector(
          onTap: _handleBannerTap,
          child: Padding(
            padding: widget.padding,
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
  }
}
