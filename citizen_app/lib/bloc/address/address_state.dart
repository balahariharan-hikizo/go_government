import '../../hive/hive_service.dart';
import '../../model/address_model.dart';

class AddressState {
  final List<AddressModel> addresses;
  final AddressModel? selectedAddress;

  AddressState({
    required this.addresses,
    this.selectedAddress,
  });

  factory AddressState.initial() {
    final stored = HiveService.getSavedAddresses();
    if (stored.isNotEmpty) {
      final list = stored.map((m) => AddressModel.fromMap(m)).toList();
      final selectedIdx = HiveService.getSelectedAddressIndex();
      final validIdx = (selectedIdx >= 0 && selectedIdx < list.length) ? selectedIdx : 0;
      return AddressState(
        addresses: list,
        selectedAddress: list.isNotEmpty ? list[validIdx] : null,
      );
    }

    return AddressState(
      addresses: [],
      selectedAddress: null,
    );
  }

  AddressState copyWith({
    List<AddressModel>? addresses,
    AddressModel? selectedAddress,
  }) {
    return AddressState(
      addresses: addresses ?? this.addresses,
      selectedAddress: selectedAddress ?? this.selectedAddress,
    );
  }
}
