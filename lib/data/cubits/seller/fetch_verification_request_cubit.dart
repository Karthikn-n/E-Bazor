import 'package:Ebozor/data/cubits/system/user_details.dart';
import 'package:Ebozor/data/model/verification_request_model.dart';
import 'package:Ebozor/data/repositories/seller/seller_verification_field_repository.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class FetchVerificationRequestState {}

class FetchVerificationRequestInitial extends FetchVerificationRequestState {}

class FetchVerificationRequestInProgress
    extends FetchVerificationRequestState {}

class FetchVerificationRequestSuccess extends FetchVerificationRequestState {
  final VerificationRequestModel data;

  FetchVerificationRequestSuccess(this.data);
}

class FetchVerificationRequestFail extends FetchVerificationRequestState {
  final dynamic error;

  FetchVerificationRequestFail(this.error);
}

class FetchVerificationRequestsCubit
    extends Cubit<FetchVerificationRequestState> {
  FetchVerificationRequestsCubit() : super(FetchVerificationRequestInitial());
  final SellerVerificationFieldRepository repository =
      SellerVerificationFieldRepository();

  void fetchVerificationRequests() async {
    try {
      emit(FetchVerificationRequestInProgress());
      VerificationRequestModel result =
          await repository.getVerificationRequest();

      if (result.isApproved) {
        await HiveUtils.setUserData({'is_verified': 1});
        _syncUserDetails();
      } else if (result.isRejected) {
        await HiveUtils.setUserData({'is_verified': 0});
        _syncUserDetails();
      }

      emit(FetchVerificationRequestSuccess(result));
    } catch (e) {
      emit(FetchVerificationRequestFail(e.toString()));
    }
  }

  void _syncUserDetails() {
    try {
      final context = Constant.navigatorKey.currentContext;
      if (context != null) {
        context.read<UserDetailsCubit>().copy(HiveUtils.getUserDetails());
      }
    } catch (_) {}
  }

//while edit
  void fillVerificationRequests(VerificationRequestModel fields) {
    emit(FetchVerificationRequestSuccess(fields));
  }

  List<VerificationFieldValues> getFields() {
    if (state is FetchVerificationRequestSuccess) {
      return (state as FetchVerificationRequestSuccess)
          .data
          .verificationFieldValues ?? [];
    }
    return [];
  }

  bool? isEmpty() {
    if (state is FetchVerificationRequestSuccess) {
      return (state as FetchVerificationRequestSuccess)
          .data
          .verificationFieldValues
          ?.isEmpty;
    }
    return null;
  }
}
