import 'package:Ebozor/app/app_theme.dart';
import 'package:Ebozor/data/cubits/system/app_theme_cubit.dart';
import 'package:Ebozor/settings.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart';



class StripeService {
  // static BuildContext? currContext;
  static String paymentIntentSuccessResponse = "succeeded";

  static Future<void> initStripe(String? stripeId, String? stripeMode) async {
    final key = (stripeId != null && stripeId.isNotEmpty)
        ? stripeId
        : AppSettings.stripePublishableKey;
    if (key.isNotEmpty) {
      Stripe.publishableKey = key;
      Stripe.merchantIdentifier = 'merchant.flutter.stripe.test';
      Stripe.urlScheme = 'flutterstripe';
      await Stripe.instance.applySettings();
    }
  }

  static Future<bool> payWithPaymentSheet({
    required BuildContext context,
    String amount = "0",
    String currency = 'AED',
    String clientSecret = '',
    String paymentIntentId = '',
    String merchantDisplayName = "",
  }) async {
    try {
      final key = AppSettings.stripePublishableKey;
      if (key.isNotEmpty && Stripe.publishableKey.isEmpty) {
        Stripe.publishableKey = key;
        Stripe.merchantIdentifier = 'merchant.flutter.stripe.test';
        Stripe.urlScheme = 'flutterstripe';
        await Stripe.instance.applySettings();
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          style: context.read<AppThemeCubit>().state.appTheme == AppTheme.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          billingDetailsCollectionConfiguration:
              const BillingDetailsCollectionConfiguration(
                  address: AddressCollectionMode.full,
                  email: CollectionMode.always,
                  name: CollectionMode.always,
                  phone: CollectionMode.always),
          merchantDisplayName: merchantDisplayName.isNotEmpty
              ? merchantDisplayName
              : Constant.appName,
        ),
      );

      // Present payment sheet and await user completion
      await Stripe.instance.presentPaymentSheet();

      HelperUtils.showSnackBarMessage(
        context,
        "paymentSuccessfullyCompleted".translate(context),
        type: MessageType.success,
      );
      return true;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        HelperUtils.showSnackBarMessage(
          context,
          "Payment was cancelled",
          type: MessageType.warning,
        );
      } else {
        HelperUtils.showSnackBarMessage(
          context,
          'Stripe: ${e.error.localizedMessage ?? e.error.message}',
          type: MessageType.error,
        );
      }
      return false;
    } catch (e) {
      HelperUtils.showSnackBarMessage(
        context,
        'Payment error: $e',
        type: MessageType.error,
      );
      return false;
    }
  }

  static StripeTransactionResponse getPlatformExceptionErrorResult(err) {
    String message = "Something went wrong";
    if (err.code == 'cancelled') {
      message = "Transaction is cancelled";
    }
    return StripeTransactionResponse(
      message: message,
      success: false,
      status: 'cancelled',
    );
  }
}

class StripeTransactionResponse {
  final String? message, status;
  bool? success;

  StripeTransactionResponse({this.message, this.success, this.status});
}
