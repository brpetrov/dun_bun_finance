class Pot {
  int id;
  String name;
  int percentage;
  DateTime? createdAt;

  Pot({
    required this.id,
    required this.name,
    required this.percentage,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'percentage': percentage,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  static Pot fromJson(Map<String, dynamic> map) {
    return Pot(
      id: map['id'],
      name: map['name'],
      percentage: map['percentage'],
      createdAt:
          map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }
}
