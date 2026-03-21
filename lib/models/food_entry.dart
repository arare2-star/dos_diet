class FoodEntry {
  final String id;
  final String name;
  final int calories;
  final String type; // breakfast, lunch, dinner, snack
  final DateTime dateTime;

  FoodEntry({
    required this.id,
    required this.name,
    required this.calories,
    required this.type,
    required this.dateTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'type': type,
      'dateTime': dateTime.toIso8601String(),
    };
  }

  factory FoodEntry.fromMap(Map<String, dynamic> map) {
    return FoodEntry(
      id: map['id'] as String,
      name: map['name'] as String,
      calories: map['calories'] as int,
      type: map['type'] as String,
      dateTime: DateTime.parse(map['dateTime'] as String),
    );
  }
}
