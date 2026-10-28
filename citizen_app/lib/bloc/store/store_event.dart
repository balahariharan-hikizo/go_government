import 'package:equatable/equatable.dart';

abstract class StoreEvent extends Equatable {
  const StoreEvent();

  @override
  List<Object?> get props => [];
}

class LoadApprovedStores extends StoreEvent {
  final String? category;
  final bool includeOffline;

  const LoadApprovedStores({
    this.category,
    this.includeOffline = false,
  });

  @override
  List<Object?> get props => [category, includeOffline];
}

class RefreshApprovedStores extends StoreEvent {
  final String? category;
  final bool includeOffline;

  const RefreshApprovedStores({
    this.category,
    this.includeOffline = false,
  });

  @override
  List<Object?> get props => [category, includeOffline];
}
