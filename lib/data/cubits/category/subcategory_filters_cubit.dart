import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/data/repositories/category_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class FilterState {}

class FilterInitial extends FilterState {}

class FilterLoading extends FilterState {}

class FilterLoaded extends FilterState {
  final FilterCategory data;

  FilterLoaded(this.data);
}

class FilterError extends FilterState {
  final String message;

  FilterError(this.message);
}

class FilterCubit extends Cubit<FilterState> {
  final FilterRepository repository;
  int _requestId = 0;

  FilterCubit(this.repository) : super(FilterInitial());

  Future<void> fetchFilters(String slug) async {
    final requestId = ++_requestId;
    try {
      if (isClosed) return;
      emit(FilterLoading());

      final data = await repository.getFilters(slug);

      if (isClosed || requestId != _requestId) return;
      emit(FilterLoaded(data));
    } catch (e) {
      if (isClosed || requestId != _requestId) return;
      emit(FilterError(e.toString()));
    }
  }
}
