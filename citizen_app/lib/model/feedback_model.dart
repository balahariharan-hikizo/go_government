class FeedbackModel {
  final String id;
  final String category;
  final double rating;
  final String comment;
  final String date;

  FeedbackModel({
    required this.id,
    required this.category,
    required this.rating,
    required this.comment,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'rating': rating,
      'comment': comment,
      'date': date,
    };
  }

  factory FeedbackModel.fromMap(Map<String, dynamic> map) {
    return FeedbackModel(
      id: map['id']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      comment: map['comment']?.toString() ?? '',
      date: map['date']?.toString() ?? '',
    );
  }
}
