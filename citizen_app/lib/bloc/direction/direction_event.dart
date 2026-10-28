import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

abstract class DirectionEvent extends Equatable {
  const DirectionEvent();

  @override
  List<Object?> get props => [];
}

class FetchDirections extends DirectionEvent {
  final String origin;
  final String destination;
  final String travelMode; // 'driving' or 'walking'
  final LatLng? originCoords;
  final LatLng? destCoords;

  const FetchDirections({
    required this.origin,
    required this.destination,
    this.travelMode = 'driving',
    this.originCoords,
    this.destCoords,
  });

  @override
  List<Object?> get props => [origin, destination, travelMode, originCoords, destCoords];
}
