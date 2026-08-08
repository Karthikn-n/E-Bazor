import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Widgets {
  static bool isLoadingShowing = false;
  static Route<dynamic>? _loaderOwnerRoute;

  static bool isCurrentOrLoaderOwner(BuildContext context) {
    final route = ModalRoute.of(context);
    return route?.isCurrent == true ||
        (isLoadingShowing && identical(route, _loaderOwnerRoute));
  }

  static void showLoader(BuildContext context) async {
    if (isLoadingShowing) {
      return;
    }
    isLoadingShowing = true;
    _loaderOwnerRoute = ModalRoute.of(context);
    showDialog(
        context: context,
        barrierDismissible: false,
        useSafeArea: true,
        builder: (BuildContext context) {
          return AnnotatedRegion(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.black.withValues(alpha: 0),
            ),
            child: SafeArea(
              child: PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) {
                  return;
                },
                child: Center(
                  child: UiUtils.progress(
                    normalProgressColor: context.color.territoryColor,
                  ),
                ),
                /*onWillPop: () {
                  return Future(
                    () => false,
                  );
                },*/
              ),
            ),
          );
        });
  }

  static void hideLoder(BuildContext context) {
    if (isLoadingShowing &&
        identical(ModalRoute.of(context), _loaderOwnerRoute)) {
      isLoadingShowing = false;
      _loaderOwnerRoute = null;
      Navigator.of(context).pop();
    }
  }

  static Center noDataFound(String errorMsg) {
    return Center(child: Text(errorMsg));
  }
}
