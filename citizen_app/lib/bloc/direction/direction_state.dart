import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';
import '../../network/ola_maps_service.dart';

abstract class DirectionState extends Equatable {
  const DirectionState();

  @override
  List<Object?> get props => [];
}

class DirectionInitial extends DirectionState {}

class DirectionLoading extends DirectionState {}

class DirectionLoaded extends DirectionState {
  final Map<String, dynamic> data;
  final OlaRouteResult? routeResult;
  final String travelMode;
  final LatLng? originCoords;
  final LatLng? destCoords;

  const DirectionLoaded({
    required this.data,
    this.routeResult,
    this.travelMode = 'driving',
    this.originCoords,
    this.destCoords,
  });

  @override
  List<Object?> get props => [data, routeResult, travelMode, originCoords, destCoords];
}

class DirectionError extends DirectionState {
  final String message;
  const DirectionError(this.message);

  @override
  List<Object?> get props => [message];
}
