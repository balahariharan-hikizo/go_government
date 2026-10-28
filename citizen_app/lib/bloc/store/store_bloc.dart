import 'package:flutter_bloc/flutter_bloc.dart';
import '../../network/store_api_service.dart';
import 'store_event.dart';
import 'store_state.dart';

class StoreBloc extends Bloc<StoreEvent, StoreState> {
  StoreBloc() : super(StoreInitial()) {
    on<LoadApprovedStores>(_onLoadApprovedStores);
    on<RefreshApprovedStores>(_onRefreshApprovedStores);
  }

  Future<void> _onLoadApprovedStores(
    LoadApprovedStores event,
    Emitter<StoreState> emit,
  ) async {
    emit(StoreLoading());
    try {
      final stores = await StoreApiService.fetchApprovedStores(
        category: event.category,
        includeOffline: event.includeOffline,
      );
      emit(StoreLoaded(stores));
    } catch (e) {
      emit(StoreError(e.toString()));
    }
  }

  Future<void> _onRefreshApprovedStores(
    RefreshApprovedStores event,
    Emitter<StoreState> emit,
  ) async {
    try {
      final stores = await StoreApiService.fetchApprovedStores(
        category: event.category,
        includeOffline: event.includeOffline,
      );
      emit(StoreLoaded(stores));
    } catch (e) {
      emit(StoreError(e.toString()));
    }
  }
}
