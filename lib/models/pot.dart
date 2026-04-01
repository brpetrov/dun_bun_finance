class Pot {
  String id = '';
  String name = "";
  int percentage = 0;
  DateTime? createdAt;

  Pot({
    required this.id,
    required this.name,
    required this.percentage,
    this.createdAt,
  });
}
