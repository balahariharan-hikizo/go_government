import 'package:flutter_bloc/flutter_bloc.dart';
import '../../hive/hive_service.dart';
import '../../model/address_model.dart';
import '../../network/api_service.dart';
import 'address_event.dart';
import 'address_state.dart';

class AddressBloc extends Bloc<AddressEvent, AddressState> {
  AddressBloc() : super(AddressState.initial()) {
    // 1. LOAD ADDRESSES (Strictly per-user from Backend API, no shared Hive cache)
    on<LoadAddressesEvent>((event, emit) async {
      // Clear legacy Hive addresses so previous account data never leaks
      HiveService.clearAddresses();

      final userId = HiveService.citizenId;
      if (userId.isEmpty) {
        emit(AddressState(addresses: [], selectedAddress: null));
        return;
      }

      // Fetch user's own addresses from backend
      final serverAddresses = await AddressApiService.fetchAddresses(userId);

      AddressModel? selected;
      if (serverAddresses.isNotEmpty) {
        selected = serverAddresses.firstWhere(
          (a) => a.isDefault,
          orElse: () => serverAddresses.first,
        );
      }

      emit(AddressState(
        addresses: serverAddresses,
        selectedAddress: selected,
      ));
    });

    // 2. ADD ADDRESS
    on<AddAddressEvent>((event, emit) async {
      final userId = HiveService.citizenId;
      final serverAddress = await AddressApiService.addAddress(event.address, userId: userId);
      final addedAddress = serverAddress ?? event.address;

      final updatedList = List<AddressModel>.from(state.addresses)..add(addedAddress);
      final newSelected = addedAddress.isDefault || state.selectedAddress == null
          ? addedAddress
          : state.selectedAddress;

      emit(AddressState(
        addresses: updatedList,
        selectedAddress: newSelected,
      ));
    });

    // 3. UPDATE ADDRESS
    on<UpdateAddressEvent>((event, emit) async {
      final updatedList = List<AddressModel>.from(state.addresses);
      if (event.index >= 0 && event.index < updatedList.length) {
        final oldAddr = updatedList[event.index];
        final updatedAddr = event.address;
        updatedAddr.id ??= oldAddr.id;

        updatedList[event.index] = updatedAddr;

        AddressModel? newSelected = state.selectedAddress;
        if (newSelected != null &&
            (newSelected.id == oldAddr.id || newSelected.description.trim() == oldAddr.description.trim())) {
          newSelected = updatedAddr;
        }

        emit(AddressState(
          addresses: updatedList,
          selectedAddress: newSelected,
        ));

        if (updatedAddr.id != null && updatedAddr.id!.isNotEmpty) {
          await AddressApiService.updateAddress(updatedAddr.id!, updatedAddr);
        }
      }
    });

    // 4. DELETE ADDRESS (Soft delete on backend)
    on<DeleteAddressEvent>((event, emit) async {
      final addressToDelete = event.address;
      final addressId = addressToDelete.id;

      final updatedList = List<AddressModel>.from(state.addresses)
        ..removeWhere((a) =>
            (addressId != null && a.id == addressId) ||
            a.description.trim() == addressToDelete.description.trim());

      AddressModel? newSelected = state.selectedAddress;
      if (newSelected != null &&
          ((addressId != null && newSelected.id == addressId) ||
              newSelected.description.trim() == addressToDelete.description.trim() ||
              !updatedList.any((a) => a.description.trim() == newSelected!.description.trim()))) {
        newSelected = updatedList.isNotEmpty ? updatedList.first : null;
      }

      emit(AddressState(
        addresses: updatedList,
        selectedAddress: newSelected,
      ));

      if (addressId != null && addressId.isNotEmpty) {
        await AddressApiService.deleteAddress(addressId);
      }
    });

    // 5. SELECT ACTIVE ADDRESS
    on<SelectActiveAddressEvent>((event, emit) {
      emit(state.copyWith(selectedAddress: event.address));
    });

    add(LoadAddressesEvent());
  }
}
