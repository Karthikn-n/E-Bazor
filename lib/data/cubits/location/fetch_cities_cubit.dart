import 'package:Ebozor/data/model/data_output.dart';
import 'package:Ebozor/data/model/location/cityModel.dart';
import 'package:Ebozor/data/repositories/location/cities_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class FetchCitiesState {}

class FetchCitiesInitial extends FetchCitiesState {}

class FetchCitiesInProgress extends FetchCitiesState {}

class FetchCitiesSuccess extends FetchCitiesState {
  final bool isLoadingMore;
  final bool loadingMoreError;
  final List<CityModel> citiesModel;
  final int page;
  final int total;
  final int? stateId;

  FetchCitiesSuccess(
      {required this.isLoadingMore,
      required this.loadingMoreError,
      required this.citiesModel,
      required this.page,
      required this.total,
      this.stateId});

  FetchCitiesSuccess copyWith(
      {bool? isLoadingMore,
      bool? loadingMoreError,
      List<CityModel>? citiesModel,
      int? page,
      int? total,
      int? stateId}) {
    return FetchCitiesSuccess(
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        loadingMoreError: loadingMoreError ?? this.loadingMoreError,
        citiesModel: citiesModel ?? this.citiesModel,
        page: page ?? this.page,
        total: total ?? this.total,
        stateId: stateId ?? this.stateId);
  }
}

class FetchCitiesFailure extends FetchCitiesState {
  final String errorMessage;

  FetchCitiesFailure(this.errorMessage);
}

class FetchCitiesCubit extends Cubit<FetchCitiesState> {
  FetchCitiesCubit() : super(FetchCitiesInitial());

  final CitiesRepository _citiesRepository = CitiesRepository();
  List<CityModel> _allCities = const [];
  String _query = '';

  Future<void> fetchCities({int? stateId, String? search}) async {
    if (search != null) _query = search;
    final cached = (stateId == null || stateId <= 0)
        ? _citiesRepository.getCachedCities()
        : const <CityModel>[];
    if (cached.isNotEmpty) {
      _allCities = cached;
      emit(FetchCitiesSuccess(
        isLoadingMore: false,
        loadingMoreError: false,
        citiesModel: _filter(_query),
        page: 1,
        total: cached.length,
        stateId: stateId,
      ));
    } else {
      emit(FetchCitiesInProgress());
    }

    try {
      DataOutput<CityModel> result =
          await _citiesRepository.fetchAllCities(stateId: stateId);
      _allCities = result.modelList;
      emit(
        FetchCitiesSuccess(
          isLoadingMore: false,
          loadingMoreError: false,
          citiesModel: _filter(_query),
          page: 1,
          total: result.total,
          stateId: stateId,
        ),
      );
    } catch (e) {
      if (_allCities.isEmpty) {
        emit(FetchCitiesFailure(e.toString()));
      } else {
        emit(FetchCitiesSuccess(
          isLoadingMore: false,
          loadingMoreError: true,
          citiesModel: _filter(_query),
          page: 1,
          total: _allCities.length,
          stateId: stateId,
        ));
      }
    }
  }

  void search(String query) {
    _query = query;
    if (_allCities.isEmpty) return;
    final current = state;
    emit(FetchCitiesSuccess(
      isLoadingMore: false,
      loadingMoreError:
          current is FetchCitiesSuccess && current.loadingMoreError,
      citiesModel: _filter(query),
      page: 1,
      total: _allCities.length,
      stateId: current is FetchCitiesSuccess ? current.stateId : null,
    ));
  }

  List<CityModel> _filter(String? query) {
    final normalized = query?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return List<CityModel>.from(_allCities);
    return _allCities
        .where((city) => (city.name ?? '').toLowerCase().contains(normalized))
        .toList(growable: false);
  }

  Future<void> fetchCitiesMore({required int stateId, String? search}) async {
    try {
      if (state is FetchCitiesSuccess) {
        if ((state as FetchCitiesSuccess).isLoadingMore) {
          return;
        }
        emit((state as FetchCitiesSuccess).copyWith(isLoadingMore: true));

        DataOutput<CityModel> result = await _citiesRepository.fetchCities(
            stateId: stateId,
            page: (state as FetchCitiesSuccess).page + 1,
            search: search);

        FetchCitiesSuccess cities = (state as FetchCitiesSuccess);

        List<CityModel> updatedList = List<CityModel>.from(cities.citiesModel)
          ..addAll(result.modelList);

        emit(
          FetchCitiesSuccess(
            isLoadingMore: false,
            loadingMoreError: false,
            citiesModel: updatedList,
            page: (state as FetchCitiesSuccess).page + 1,
            total: result.total,
            stateId: stateId,
          ),
        );
      }
    } catch (e) {
      emit(
        (state as FetchCitiesSuccess).copyWith(
          isLoadingMore: false,
          loadingMoreError: true,
        ),
      );
    }
  }

  bool hasMoreData() {
    if (state is FetchCitiesSuccess) {
      return (state as FetchCitiesSuccess).citiesModel.length <
          (state as FetchCitiesSuccess).total;
    }
    return false;
  }
}
