import '../../screen/profile/address_book_screen.dart';

abstract class AddressEvent {}

class LoadAddressesEvent extends AddressEvent {}

class AddAddressEvent extends AddressEvent {
  final AddressModel address;
  AddAddressEvent(this.address);
}

class UpdateAddressEvent extends AddressEvent {
  final int index;
  final AddressModel address;
  UpdateAddressEvent(this.index, this.address);
}

class DeleteAddressEvent extends AddressEvent {
  final AddressModel address;
  DeleteAddressEvent(this.address);
}

class SelectActiveAddressEvent extends AddressEvent {
  final AddressModel address;
  SelectActiveAddressEvent(this.address);
}
