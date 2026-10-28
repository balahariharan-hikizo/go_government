import 'package:image_picker/image_picker.dart';

class ComplaintState {
  final String selectedCategory;
  final XFile? imageFile;
  final bool isSubmitting;
  final bool isSubmitted;

  ComplaintState({
    required this.selectedCategory,
    this.imageFile,
    required this.isSubmitting,
    required this.isSubmitted,
  });

  factory ComplaintState.initial() {
    return ComplaintState(
      selectedCategory: '',
      imageFile: null,
      isSubmitting: false,
      isSubmitted: false,
    );
  }

  ComplaintState copyWith({
    String? selectedCategory,
    XFile? imageFile,
    bool? isSubmitting,
    bool? isSubmitted,
  }) {
    return ComplaintState(
      selectedCategory: selectedCategory ?? this.selectedCategory,
      imageFile: imageFile ?? this.imageFile,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSubmitted: isSubmitted ?? this.isSubmitted,
    );
  }
}
