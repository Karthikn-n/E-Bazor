import 'package:Ebozor/data/model/saved_search_model.dart';
import 'package:Ebozor/data/repositories/saved_search_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class SaveSearchState {}

class SaveSearchInitial extends SaveSearchState {}

class SaveSearchProgress extends SaveSearchState {}

class SaveSearchSuccess extends SaveSearchState {
  final SavedSearchModel savedSearch;

  SaveSearchSuccess(this.savedSearch);
}

class SaveSearchFailure extends SaveSearchState {
  final dynamic errorMessage;

  SaveSearchFailure(this.errorMessage);
}

class SaveSearchCubit extends Cubit<SaveSearchState> {
  final SavedSearchRepository _repository = SavedSearchRepository();

  SaveSearchCubit() : super(SaveSearchInitial());

  Future<void> saveSearch({
    required String title,
    int? categoryId,
    int? parentCategoryId,
    String? categorySlug,
    String? searchUrl,
    String? apiSearchUrl,
    String? location,
    bool? subscribeEmail,
    bool? notification,
  }) async {
    try {
      emit(SaveSearchProgress());
      final result = await _repository.createSavedSearch(
        title: title,
        categoryId: categoryId,
        parentCategoryId: parentCategoryId,
        categorySlug: categorySlug,
        searchUrl: searchUrl,
        apiSearchUrl: apiSearchUrl,
        location: location,
        subscribeEmail: subscribeEmail,
        notification: notification,
      );
      emit(SaveSearchSuccess(result));
    } catch (e) {
      emit(SaveSearchFailure(e));
    }
  }

  void reset() {
    emit(SaveSearchInitial());
  }
}
