import 'package:Ebozor/data/model/favorite_listing_model.dart';
import 'package:Ebozor/data/repositories/favourites_repository.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class FavoriteListingsState {}

class FavoriteListingsInitial extends FavoriteListingsState {}

class FavoriteListingsFetchInProgress extends FavoriteListingsState {}

class FavoriteListingsFetchSuccess extends FavoriteListingsState {
  final List<FavoriteListingModel> listings;

  FavoriteListingsFetchSuccess({required this.listings});

  FavoriteListingModel? get defaultListing {
    try {
      return listings.firstWhere((element) => element.isDefault);
    } catch (_) {
      return null;
    }
  }

  List<FavoriteListingModel> get customListings {
    return listings.where((element) => !element.isDefault).toList();
  }
}

class FavoriteListingsFetchFailure extends FavoriteListingsState {
  final String errorMessage;

  FavoriteListingsFetchFailure(this.errorMessage);
}

class FavoriteListingsCubit extends Cubit<FavoriteListingsState> {
  final FavoriteRepository favoriteRepository;

  FavoriteListingsCubit(this.favoriteRepository) : super(FavoriteListingsInitial());

  List<FavoriteListingModel> get currentListings {
    if (state is FavoriteListingsFetchSuccess) {
      return (state as FavoriteListingsFetchSuccess).listings;
    }
    return [];
  }

  Future<void> fetchListings() async {
    final userId = HiveUtils.getUserId();
    if (userId == null) {
      emit(FavoriteListingsFetchSuccess(listings: []));
      return;
    }

    try {
      emit(FavoriteListingsFetchInProgress());
      final listings = await favoriteRepository.fetchFavoriteListings(userId: userId);
      emit(FavoriteListingsFetchSuccess(listings: listings));
    } catch (e) {
      emit(FavoriteListingsFetchFailure(e.toString()));
    }
  }

  Future<bool> createListing(String name) async {
    final userId = HiveUtils.getUserId();
    if (userId == null) return false;

    try {
      final response = await favoriteRepository.createFavoriteListing(
        listingName: name,
        userId: userId,
      );
      if (response['error'] == false) {
        await fetchListings();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> renameListing(int listingId, String newName) async {
    try {
      final response = await favoriteRepository.renameFavoriteListing(
        listingId: listingId,
        listingName: newName,
      );
      if (response['error'] == false) {
        if (state is FavoriteListingsFetchSuccess) {
          final current = (state as FavoriteListingsFetchSuccess).listings;
          final updated = current.map((item) {
            if (item.favouritelistingId == listingId) {
              return item.copyWith(title: newName);
            }
            return item;
          }).toList();
          emit(FavoriteListingsFetchSuccess(listings: updated));
        } else {
          await fetchListings();
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteListing(int listingId) async {
    try {
      final response = await favoriteRepository.deleteFavoriteListing(
        listingId: listingId,
      );
      if (response['error'] == false) {
        if (state is FavoriteListingsFetchSuccess) {
          final current = (state as FavoriteListingsFetchSuccess).listings;
          final updated = current.where((item) => item.favouritelistingId != listingId).toList();
          emit(FavoriteListingsFetchSuccess(listings: updated));
        } else {
          await fetchListings();
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void updateListCount(int? listingId, int delta) {
    if (state is FavoriteListingsFetchSuccess) {
      final current = (state as FavoriteListingsFetchSuccess).listings;
      final updated = current.map((item) {
        if (item.favouritelistingId == listingId) {
          final newCount = (item.count + delta).clamp(0, 999999);
          return item.copyWith(count: newCount);
        }
        return item;
      }).toList();
      emit(FavoriteListingsFetchSuccess(listings: updated));
    }
  }
}
