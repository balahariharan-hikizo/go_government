class ComplaintModel {
  final String id;
  final String category;
  final String title;
  final String description;
  final String location;
  final String? imagePath;
  final String status;
  final String date;

  ComplaintModel({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.location,
    this.imagePath,
    this.status = 'Pending',
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'title': title,
      'description': description,
      'location': location,
      'imagePath': imagePath,
      'status': status,
      'date': date,
    };
  }

  factory ComplaintModel.fromMap(Map<String, dynamic> map) {
    return ComplaintModel(
      id: map['id']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      location: map['location']?.toString() ?? '',
      imagePath: map['imagePath']?.toString(),
      status: map['status']?.toString() ?? 'Pending',
      date: map['date']?.toString() ?? '',
    );
  }
}
