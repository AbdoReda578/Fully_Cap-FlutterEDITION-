class BarcodeMedicationModel {
  BarcodeMedicationModel({
    required this.medName,
    required this.dose,
    required this.time,
    required this.description,
  });

  final String medName;
  final String dose;
  final String time;
  final String description;

  factory BarcodeMedicationModel.fromJson(Map<String, dynamic> json) {
    return BarcodeMedicationModel(
      medName: (json['med_name'] ?? '').toString(),
      dose: (json['dose'] ?? '').toString(),
      time: (json['time'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
    );
  }
}
