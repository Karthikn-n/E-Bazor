
import 'package:Ebozor/data/repositories/advertisement_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class GetPaymentIntentState {}

class GetPaymentIntentInitial extends GetPaymentIntentState {}

class GetPaymentIntentInProgress extends GetPaymentIntentState {}

class GetPaymentIntentInSuccess extends GetPaymentIntentState {
  final dynamic paymentIntent;


  GetPaymentIntentInSuccess(
      this.paymentIntent);
}

class GetPaymentIntentFailure extends GetPaymentIntentState {
  final dynamic error;

  GetPaymentIntentFailure(this.error);
}

class GetPaymentIntentCubit extends Cubit<GetPaymentIntentState> {
  GetPaymentIntentCubit() : super(GetPaymentIntentInitial());
  AdvertisementRepository repository = AdvertisementRepository();

  void getPaymentIntent(
      {required int packageId, required String paymentMethod}) async {
    emit(GetPaymentIntentInProgress());

    repository
        .getPaymentIntent(packageId: packageId, paymentMethod: paymentMethod)
        .then((value) {
      final data = value['data'];
      dynamic intent = data;
      if (data is Map && data.containsKey('payment_intent')) {
        intent = data['payment_intent'];
      }
      emit(GetPaymentIntentInSuccess(intent));
    }).catchError((e) {
      emit(GetPaymentIntentFailure(e.toString()));
    });
  }
}
