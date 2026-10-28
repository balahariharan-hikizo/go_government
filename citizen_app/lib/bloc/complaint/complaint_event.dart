import 'package:image_picker/image_picker.dart';

abstract class ComplaintEvent {}

class SelectComplaintCategoryEvent extends ComplaintEvent {
  final String category;
  SelectComplaintCategoryEvent(this.category);
}

class PickComplaintImageEvent extends ComplaintEvent {
  final XFile image;
  PickComplaintImageEvent(this.image);
}

class SubmitComplaintEvent extends ComplaintEvent {
  final String description;
  final String category;
  final String? location;
  final String? imagePath;
  final double? lat;
  final double? lng;

  SubmitComplaintEvent({
    required this.description,
    required this.category,
    this.location,
    this.imagePath,
    this.lat,
    this.lng,
  });
}

class ClearComplaintEvent extends ComplaintEvent {}
