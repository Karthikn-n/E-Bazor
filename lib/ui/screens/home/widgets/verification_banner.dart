import 'package:Ebozor/data/cubits/seller/fetch_verification_request_cubit.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:Ebozor/ui/screens/widgets/phone_verification_dialog.dart';

class VerificationBanner extends StatefulWidget {
  const VerificationBanner({super.key});

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

    PhoneVerificationDialog.show(
      context,
      onVerified: () {
        setState(() {});
        context
            .read<FetchVerificationRequestsCubit>()
            .fetchVerificationRequests();
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
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
