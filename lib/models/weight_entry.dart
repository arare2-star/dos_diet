class WeightEntry {
  final String id;
  final double weight; // kg
  final DateTime dateTime;

  WeightEntry({
    required this.id,
    required this.weight,
    required this.dateTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'weight': weight,
      'dateTime': dateTime.toIso8601String(),
    };
  }

  factory WeightEntry.fromMap(Map<String, dynamic> map) {
    return WeightEntry(
      id: map['id'] as String,
      weight: (map['weight'] as num).toDouble(),
      dateTime: DateTime.parse(map['dateTime'] as String),
    );
  }
}
