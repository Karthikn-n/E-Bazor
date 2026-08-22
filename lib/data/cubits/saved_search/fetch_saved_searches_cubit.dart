import 'package:Ebozor/data/model/saved_search_model.dart';
import 'package:Ebozor/data/repositories/saved_search_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class FetchSavedSearchesState {}

class FetchSavedSearchesInitial extends FetchSavedSearchesState {}

class FetchSavedSearchesInProgress extends FetchSavedSearchesState {}

class FetchSavedSearchesSuccess extends FetchSavedSearchesState {
  final List<SavedSearchModel> savedSearches;
  final List<SavedSearchParentCategory> parentCategories;
  final int? selectedParentCategoryId;
  final int total;
  final int page;
  final bool isLoadingMore;
  final bool hasMore;

  FetchSavedSearchesSuccess({
    required this.savedSearches,
    this.parentCategories = const [],
    this.selectedParentCategoryId,
    required this.total,
    required this.page,
    required this.isLoadingMore,
    required this.hasMore,
  });

  List<SavedSearchModel> get filteredSearches {
    if (selectedParentCategoryId == null) return savedSearches;
    return savedSearches
        .where((s) => s.parentCategoryId == selectedParentCategoryId)
        .toList();
  }

  FetchSavedSearchesSuccess copyWith({
    List<SavedSearchModel>? savedSearches,
    List<SavedSearchParentCategory>? parentCategories,
    int? selectedParentCategoryId,
    bool clearSelectedCategory = false,
    int? total,
    int? page,
    bool? isLoadingMore,
    bool? hasMore,
  }) {
    return FetchSavedSearchesSuccess(
      savedSearches: savedSearches ?? this.savedSearches,
      parentCategories: parentCategories ?? this.parentCategories,
      selectedParentCategoryId: clearSelectedCategory
          ? null
          : (selectedParentCategoryId ?? this.selectedParentCategoryId),
      total: total ?? this.total,
      page: page ?? this.page,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class FetchSavedSearchesFailure extends FetchSavedSearchesState {
  final dynamic errorMessage;

  FetchSavedSearchesFailure(this.errorMessage);
}

class FetchSavedSearchesCubit extends Cubit<FetchSavedSearchesState> {
  final SavedSearchRepository _repository = SavedSearchRepository();

  FetchSavedSearchesCubit() : super(FetchSavedSearchesInitial());

  Future<void> fetchSavedSearches() async {
    try {
      emit(FetchSavedSearchesInProgress());
      SavedSearchResult result = await _repository.fetchSavedSearches(page: 1);

      emit(FetchSavedSearchesSuccess(
        savedSearches: result.output.modelList,
        parentCategories: result.parentCategories,
        total: result.output.total,
        page: 1,
        isLoadingMore: false,
        hasMore: result.output.modelList.length < result.output.total,
      ));
    } catch (e) {
      emit(FetchSavedSearchesFailure(e));
    }
  }

  void selectParentCategory(int? parentCategoryId) {
    if (state is FetchSavedSearchesSuccess) {
      final currentState = state as FetchSavedSearchesSuccess;
      emit(currentState.copyWith(
        selectedParentCategoryId: parentCategoryId,
        clearSelectedCategory: parentCategoryId == null,
      ));
    }
  }

  bool hasMoreData() {
    if (state is FetchSavedSearchesSuccess) {
      return (state as FetchSavedSearchesSuccess).hasMore;
    }
    return false;
  }

  Future<void> fetchMoreSavedSearches() async {
    if (state is! FetchSavedSearchesSuccess) return;
    final currentState = state as FetchSavedSearchesSuccess;
    if (currentState.isLoadingMore || !currentState.hasMore) return;

    try {
      emit(currentState.copyWith(isLoadingMore: true));
      final nextPage = currentState.page + 1;
      SavedSearchResult result =
          await _repository.fetchSavedSearches(page: nextPage);

      final updatedList = List<SavedSearchModel>.from(currentState.savedSearches)
        ..addAll(result.output.modelList);

      emit(FetchSavedSearchesSuccess(
        savedSearches: updatedList,
        parentCategories: result.parentCategories.isNotEmpty
            ? result.parentCategories
            : currentState.parentCategories,
        selectedParentCategoryId: currentState.selectedParentCategoryId,
        total: result.output.total,
        page: nextPage,
        isLoadingMore: false,
        hasMore: updatedList.length < result.output.total,
      ));
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  void addSavedSearch(SavedSearchModel model) {
    if (state is FetchSavedSearchesSuccess) {
      final currentState = state as FetchSavedSearchesSuccess;
      final updatedList = [
        model,
        ...currentState.savedSearches.where((s) => s.id != model.id)
      ];
      emit(currentState.copyWith(
        savedSearches: updatedList,
        total: currentState.total + 1,
      ));
    } else {
      emit(FetchSavedSearchesSuccess(
        savedSearches: [model],
        total: 1,
        page: 1,
        isLoadingMore: false,
        hasMore: false,
      ));
    }
  }

  SavedSearchModel? findSavedSearch({
    String? query,
    int? categoryId,
    String? apiSearchUrl,
  }) {
    if (state is! FetchSavedSearchesSuccess) return null;
    final list = (state as FetchSavedSearchesSuccess).savedSearches;

    String normalize(String u) {
      return u
          .replaceAll('http://13.233.244.104/api/', '')
          .replaceAll('api/', '')
          .replaceAll('get-item?', '')
          .replaceAll('get-item', '')
          .trim()
          .toLowerCase();
    }

    for (var item in list) {
      // 1. Match by URL parameters
      if (apiSearchUrl != null && apiSearchUrl.isNotEmpty) {
        final normTarget = normalize(apiSearchUrl);
        final normItem = normalize(item.apiSearchUrl ?? item.searchUrl ?? '');
        if (normTarget.isNotEmpty && normItem.isNotEmpty) {
          if (normTarget == normItem) return item;
        }
      }

      // 2. Match by query keyword
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final itemUrl =
            (item.apiSearchUrl ?? item.searchUrl ?? '').toLowerCase();
        if (itemUrl.contains('search=$q') ||
            itemUrl.contains('search=${Uri.encodeComponent(q)}')) {
          return item;
        }
        if (item.title != null && item.title!.toLowerCase().contains(q)) {
          return item;
        }
      }

      // 3. Match by category if no query
      if (categoryId != null &&
          categoryId > 0 &&
          (query == null || query.trim().isEmpty)) {
        if (item.categoryId == categoryId) {
          return item;
        }
      }
    }
    return null;
  }

  Future<bool> deleteSavedSearch(int id) async {
    try {
      await _repository.deleteSavedSearch(id: id);
      if (state is FetchSavedSearchesSuccess) {
        final currentState = state as FetchSavedSearchesSuccess;
        final updatedList = currentState.savedSearches
            .where((element) => element.id != id)
            .toList();
        emit(currentState.copyWith(
          savedSearches: updatedList,
          total: currentState.total > 0 ? currentState.total - 1 : 0,
        ));
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> editSavedSearch({required int id, required String title}) async {
    try {
      await _repository.editSavedSearch(id: id, title: title);
      if (state is FetchSavedSearchesSuccess) {
        final currentState = state as FetchSavedSearchesSuccess;
        final updatedList = currentState.savedSearches.map((element) {
          if (element.id == id) {
            return element.copyWith(title: title);
          }
          return element;
        }).toList();
        emit(currentState.copyWith(savedSearches: updatedList));
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
