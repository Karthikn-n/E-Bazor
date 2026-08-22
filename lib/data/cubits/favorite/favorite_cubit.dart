

import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/data/repositories/favourites_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class FavoriteState {}

class FavoriteInitial extends FavoriteState {}

class FavoriteFetchInProgress extends FavoriteState {}

class FavoriteFetchSuccess extends FavoriteState {
  final List<ItemModel> favorite;
  final bool isLoadingMore;
  final int totalFavoriteCount;
  final bool hasMoreFetchError;
  final bool hasMore;
  final int page;

  FavoriteFetchSuccess(
      {required this.favorite,
      required this.isLoadingMore,
      required this.totalFavoriteCount,
      required this.hasMoreFetchError,
      required this.page,
      required this.hasMore});

  FavoriteFetchSuccess copyWith({
    List<ItemModel>? favorite,
    bool? isLoadingMore,
    int? totalFavoriteCount,
    bool? hasMoreFetchError,
    bool? hasMore,
    int? page,
  }) {
    return FavoriteFetchSuccess(
      favorite: favorite ?? this.favorite,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      hasMoreFetchError: hasMoreFetchError ?? this.hasMoreFetchError,
      totalFavoriteCount: totalFavoriteCount ?? this.totalFavoriteCount,
    );
  }
}

class FavoriteFetchFailure extends FavoriteState {
  final String errorMessage;

  FavoriteFetchFailure(this.errorMessage);
}

class FavoriteCubit extends Cubit<FavoriteState>{
  final FavoriteRepository favoriteRepository;
  int? currentListingId;
  String? currentSearch;
  int? currentCategoryId;
  final Map<int, Set<int>> _listingIdsByItem = {};
  final Set<int> _itemsWithLoadedListings = {};

  FavoriteCubit(this.favoriteRepository) : super(FavoriteInitial());

  void getFavorite({int? favouritelistingId, String? search, int? categoryId}) async {
    currentListingId = favouritelistingId;
    currentSearch = search;
    currentCategoryId = categoryId;

    try {
      emit(FavoriteFetchInProgress());
      final result = await favoriteRepository.fetchFavorites(
        page: 1,
        favouritelistingId: currentListingId,
        search: currentSearch,
        categoryId: currentCategoryId,
      );

      emit(FavoriteFetchSuccess(
          favorite: result.modelList,
          totalFavoriteCount: result.total,
          hasMoreFetchError: false,
          page: 1,
          isLoadingMore: false,
          hasMore: (result.modelList.length < result.total)));
    } catch (e) {
      if (e.toString() == "No Data Found") {
        //incase of 0 Favorite length - make it success for fresh users
        emit(FavoriteFetchSuccess(
            favorite: [],
            isLoadingMore: false,
            totalFavoriteCount: 0,
            page: 1,
            hasMoreFetchError: false,
            hasMore: false));
      } else {
        emit(FavoriteFetchFailure(e.toString()));
      }
    }
  }

  bool hasMoreFavorite() {
    return (state is FavoriteFetchSuccess)
        ? (state as FavoriteFetchSuccess).hasMore
        : false;
  }

  void getMoreFavorite() async {
    if (state is FavoriteFetchSuccess) {
      try {
        if ((state as FavoriteFetchSuccess).isLoadingMore) {
          return;
        }
        emit((state as FavoriteFetchSuccess).copyWith(isLoadingMore: true));
        final result = await favoriteRepository.fetchFavorites(
          page: (state as FavoriteFetchSuccess).page + 1,
          favouritelistingId: currentListingId,
          search: currentSearch,
          categoryId: currentCategoryId,
        );
        List<ItemModel> updatedResults =
            (state as FavoriteFetchSuccess).favorite;
        updatedResults.addAll(result.modelList);
        emit(FavoriteFetchSuccess(
            isLoadingMore: false,
            favorite: updatedResults,
            totalFavoriteCount: result.total,
            hasMoreFetchError: false,
            page: (state as FavoriteFetchSuccess).page + 1,
            hasMore: updatedResults.length < result.total));
      } catch (e) {
        emit(FavoriteFetchSuccess(
            isLoadingMore: false,
            favorite: (state as FavoriteFetchSuccess).favorite,
            hasMoreFetchError: (e.toString() == "No Data Found") ? false : true,
            page: (state as FavoriteFetchSuccess).page + 1,
            totalFavoriteCount:
                (state as FavoriteFetchSuccess).totalFavoriteCount,
            hasMore: (state as FavoriteFetchSuccess).hasMore));
      }
    }
  }

  void addFavoriteitem(ItemModel model) {
    if (state is FavoriteFetchSuccess) {
      if (isItemFavorite(model.id!)) return;
      List<ItemModel> favoriteList = [];

      model.totalLikes = (model.totalLikes ?? 0) + 1;

      favoriteList.insert(0, model);
      favoriteList.addAll((state as FavoriteFetchSuccess).favorite);

      emit(FavoriteFetchSuccess(
          isLoadingMore: false,
          favorite: List.from(favoriteList),
          hasMoreFetchError: true,
          page: (state as FavoriteFetchSuccess).page,
          totalFavoriteCount:
              (state as FavoriteFetchSuccess).totalFavoriteCount,
          hasMore: (state as FavoriteFetchSuccess).hasMore));
    }
  }

  void removeFavoriteItem(ItemModel model) {
    final itemId = model.id;
    if (itemId != null) {
      _listingIdsByItem.remove(itemId);
      _itemsWithLoadedListings.remove(itemId);
    }
    if (state is FavoriteFetchSuccess) {
      final favorite = (state as FavoriteFetchSuccess).favorite;

      // Find the index of the item to be removed
      int indexToRemove = favorite.indexWhere((element) => element.id == model.id);
      if (indexToRemove != -1) {
        // Decrement totalLikes of the item being removed
        ItemModel removedItem = favorite[indexToRemove];
        removedItem.totalLikes = (removedItem.totalLikes ?? 0) - 1;
        favorite.removeAt(indexToRemove);

        emit(FavoriteFetchSuccess(
          isLoadingMore: false,
          favorite: List.from(favorite),
          hasMoreFetchError: true,
          page: (state as FavoriteFetchSuccess).page,
          totalFavoriteCount: (state as FavoriteFetchSuccess).totalFavoriteCount,
          hasMore: (state as FavoriteFetchSuccess).hasMore,
        ));

      }
    }
  }




  bool isItemFavorite(int itemId) {
    if (state is FavoriteFetchSuccess) {
      final favorite = (state as FavoriteFetchSuccess).favorite;
      return (favorite.isNotEmpty)
          ? (favorite.indexWhere((element) => (element.id == itemId)) != -1)
          : false;
    }
    return false;
  }

  bool hasLoadedFavoriteListings(int itemId) =>
      _itemsWithLoadedListings.contains(itemId);

  Set<int> favoriteListingIds(int itemId) =>
      Set<int>.from(_listingIdsByItem[itemId] ?? const <int>{});

  void setFavoriteListingIds(int itemId, Iterable<int> listingIds) {
    _listingIdsByItem[itemId] = listingIds.toSet();
    _itemsWithLoadedListings.add(itemId);
  }

  void setFavoriteListingMembership(
    int itemId,
    int listingId, {
    required bool isAdded,
  }) {
    final listingIds = _listingIdsByItem.putIfAbsent(itemId, () => <int>{});
    isAdded ? listingIds.add(listingId) : listingIds.remove(listingId);
    _itemsWithLoadedListings.add(itemId);
  }

  void resetState() {
    _listingIdsByItem.clear();
    _itemsWithLoadedListings.clear();
    emit(FavoriteFetchInProgress());
  }




}
