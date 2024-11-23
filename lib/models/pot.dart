class Pot {
  int id = 0; // Default to 0
  String name = ""; // Default to empty string
  int percentage = 0; // Default to 0
  DateTime? createdAt;

  // Constructor
  Pot({
    required this.id,
    required this.name,
    required this.percentage,
    this.createdAt,
  });

  // Factory method to create a Pot from a JSON map
  Pot.fromJson(Map<String, dynamic> map) {
    id = map['id'];
    name = map['name'];
    percentage = map['percentage'].toDouble(); // Ensures percentage is a double
    createdAt = DateTime.parse(map['created_at']);
  }

  // Method to convert a Pot to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'percentage': percentage,
      'created_at': createdAt?.toIso8601String(), // Use ISO8601 string format
    };
  }
}
