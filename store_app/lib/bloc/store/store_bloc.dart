import 'package:flutter_bloc/flutter_bloc.dart';
import '../../hive/hive_service.dart';
import '../../model/store_model.dart';
import '../../network/store_api_service.dart';
import 'store_event.dart';
import 'store_state.dart';

class StoreBloc extends Bloc<StoreEvent, StoreState> {
  static final StoreBloc instance = StoreBloc._internal();

  factory StoreBloc() => instance;

  StoreBloc._internal() : super(StoreInitial()) {
    on<FetchMyStoreEvent>((event, emit) async {
      emit(StoreLoading());

      final res = await StoreApiService.getMyStore(event.identifier);

      if (res != null && res['success'] == true && res['store'] != null) {
        final store = StoreModel.fromJson(res['store'] as Map<String, dynamic>);
        await HiveService.setStoreId(store.storeId);
        await HiveService.setStoreStatus(store.status);
        await HiveService.setCachedStoreData(res['store'] as Map<String, dynamic>);

        emit(StoreLoaded(store));
      } else if (res != null && res['notFound'] == true) {
        emit(StoreNotFound(event.identifier));
      } else {
        emit(StoreError(res?['error'] ?? 'Could not retrieve store details'));
      }
    });

    on<RegisterStoreEvent>((event, emit) async {
      emit(StoreSubmitting());

      final res = await StoreApiService.registerStore(event.store);

      if (res != null && res['success'] == true && res['store'] != null) {
        final store = StoreModel.fromJson(res['store'] as Map<String, dynamic>);
        await HiveService.setStoreId(store.storeId);
        await HiveService.setStoreStatus(store.status);
        await HiveService.setCachedStoreData(res['store'] as Map<String, dynamic>);

        emit(StoreSubmitSuccess(store));
      } else {
        emit(StoreError(res?['error'] ?? res?['message'] ?? 'Store registration failed'));
      }
    });

    on<ToggleStoreOnlineEvent>((event, emit) async {
      final res = await StoreApiService.updateOnlineStatus(event.storeId, event.isOnline);
      if (res != null && res['success'] == true && res['store'] != null) {
        final updated = StoreModel.fromJson(res['store'] as Map<String, dynamic>);
        emit(StoreLoaded(updated));
      }
    });

    on<RefreshStoreStatusEvent>((event, emit) async {
      final res = await StoreApiService.getMyStore(event.identifier);
      if (res != null && res['success'] == true && res['store'] != null) {
        final store = StoreModel.fromJson(res['store'] as Map<String, dynamic>);
        await HiveService.setStoreStatus(store.status);
        await HiveService.setCachedStoreData(res['store'] as Map<String, dynamic>);
        emit(StoreLoaded(store));
      }
    });

    on<UpdateStoreProfileEvent>((event, emit) async {
      final res = await StoreApiService.updateStoreProfile(event.storeId, event.updates);
      if (res != null && res['success'] == true && res['store'] != null) {
        final store = StoreModel.fromJson(res['store'] as Map<String, dynamic>);
        await HiveService.setCachedStoreData(res['store'] as Map<String, dynamic>);
        emit(StoreLoaded(store));
      }
    });

    on<ResetStoreEvent>((event, emit) {
      emit(StoreInitial());
    });
  }
}
