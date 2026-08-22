import 'package:Ebozor/data/model/user_device_model.dart';
import 'package:Ebozor/data/repositories/user_devices_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class UserDevicesState {}

class UserDevicesInitial extends UserDevicesState {}

class UserDevicesFetchInProgress extends UserDevicesState {}

class UserDevicesFetchSuccess extends UserDevicesState {
  final List<UserDeviceModel> devices;
  UserDevicesFetchSuccess(this.devices);
}

class UserDevicesFetchFailure extends UserDevicesState {
  final dynamic errorMessage;
  UserDevicesFetchFailure(this.errorMessage);
}

class UserDevicesCubit extends Cubit<UserDevicesState> {
  final UserDevicesRepository _repository = UserDevicesRepository();

  UserDevicesCubit() : super(UserDevicesInitial());

  Future<void> fetchDevices() async {
    emit(UserDevicesFetchInProgress());
    try {
      final devices = await _repository.getDevices();
      emit(UserDevicesFetchSuccess(devices));
    } catch (e) {
      emit(UserDevicesFetchFailure(e.toString()));
    }
  }

  Future<bool> logoutDevice(int deviceId) async {
    try {
      await _repository.logoutDevice(deviceId);
      await fetchDevices();
      return true;
    } catch (e) {
      return false;
    }
  }
}
