import 'package:Ebozor/data/repositories/item_inquiry_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class ItemInquiryState {}

class ItemInquiryInitial extends ItemInquiryState {}

class ItemInquiryInProgress extends ItemInquiryState {}

class ItemInquirySuccess extends ItemInquiryState {
  final String message;
  ItemInquirySuccess(this.message);
}

class ItemInquiryFailure extends ItemInquiryState {
  final dynamic errorMessage;
  ItemInquiryFailure(this.errorMessage);
}

class ItemInquiryCubit extends Cubit<ItemInquiryState> {
  final ItemInquiryRepository _repository = ItemInquiryRepository();

  ItemInquiryCubit() : super(ItemInquiryInitial());

  Future<void> sendInquiry({
    required int itemId,
    required String name,
    required String email,
    required String message,
    String? phone,
    String? listingUrl,
    String? referenceCode,
  }) async {
    emit(ItemInquiryInProgress());
    try {
      final response = await _repository.sendItemInquiry(
        itemId: itemId,
        name: name,
        email: email,
        message: message,
        phone: phone,
        listingUrl: listingUrl,
        referenceCode: referenceCode,
      );
      emit(ItemInquirySuccess(
          response['message']?.toString() ?? "Inquiry sent successfully"));
    } catch (e) {
      emit(ItemInquiryFailure(e.toString()));
    }
  }
}
