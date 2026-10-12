import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LocationChangeState {
  final String? city;
  final String? state;
  final String? country;
  final String? area;
  final int? areaId;
  final double? latitude;
  final double? longitude;

  const LocationChangeState({
    this.city,
    this.state,
    this.country,
    this.area,
    this.areaId,
    this.latitude,
    this.longitude,
  });

  String get displayName {
    if (city != null && city!.trim().isNotEmpty) {
      return city!.trim();
    }
    if (state != null && state!.trim().isNotEmpty) {
      return state!.trim();
    }
    if (country != null && country!.trim().isNotEmpty) {
      return country!.trim();
    }
    return 'Dushanbe';
  }

  LocationChangeState copyWith({
    String? city,
    String? state,
    String? country,
    String? area,
    int? areaId,
    double? latitude,
    double? longitude,
  }) {
    return LocationChangeState(
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      area: area ?? this.area,
      areaId: areaId ?? this.areaId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

class LocationChangeCubit extends Cubit<LocationChangeState> {
  LocationChangeCubit()
      : super(LocationChangeState(
          city: HiveUtils.getCityName()?.toString(),
          state: HiveUtils.getStateName()?.toString(),
          country: HiveUtils.getCountryName()?.toString(),
          area: HiveUtils.getAreaName()?.toString(),
          areaId: HiveUtils.getAreaId() is int
              ? HiveUtils.getAreaId() as int
              : null,
          latitude: HiveUtils.getLatitude() is num
              ? (HiveUtils.getLatitude() as num).toDouble()
              : HiveUtils.getSelectedCityLatitude(),
          longitude: HiveUtils.getLongitude() is num
              ? (HiveUtils.getLongitude() as num).toDouble()
              : HiveUtils.getSelectedCityLongitude(),
        ));

  Future<void> changeLocation({
    String? city,
    String? state,
    String? country,
    String? area,
    int? areaId,
    double? latitude,
    double? longitude,
  }) async {
    await HiveUtils.setLocation(
      city: city,
      state: state,
      country: country,
      area: area,
      areaId: areaId,
      latitude: latitude,
      longitude: longitude,
    );
    emit(LocationChangeState(
      city: city,
      state: state,
      country: country,
      area: area,
      areaId: areaId,
      latitude: latitude,
      longitude: longitude,
    ));
  }

  Future<void> setLocation({
    String? city,
    String? state,
    String? country,
    String? area,
    int? areaId,
    double? latitude,
    double? longitude,
  }) =>
      changeLocation(
        city: city,
        state: state,
        country: country,
        area: area,
        areaId: areaId,
        latitude: latitude,
        longitude: longitude,
      );

  Future<void> selectCity(
    String city, {
    double? latitude,
    double? longitude,
    String? countryCode,
  }) async {
    await HiveUtils.setSelectedCity(
      city,
      latitude: latitude,
      longitude: longitude,
      countryCode: countryCode,
    );
    emit(LocationChangeState(
      city: city.trim(),
      latitude: latitude,
      longitude: longitude,
    ));
  }

  Future<void> clearLocation() async {
    HiveUtils.clearLocation();
    emit(const LocationChangeState());
  }
}
