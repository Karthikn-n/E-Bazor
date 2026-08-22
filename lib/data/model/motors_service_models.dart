enum MotorsServiceType { inspection, finance, evaluation }

class MotorsServicePaymentDraft {
  final MotorsServiceType type;
  final Map<String, dynamic> servicePayload;
  final String email;
  final InspectionPackageModel? initialPackage;

  const MotorsServicePaymentDraft({
    required this.type,
    required this.servicePayload,
    required this.email,
    this.initialPackage,
  });
}

class InspectionPackageModel {
  final int? id;
  final String name;
  final double price;
  final String points;
  final List<String> features;

  const InspectionPackageModel({
    this.id,
    required this.name,
    required this.price,
    required this.points,
    required this.features,
  });

  factory InspectionPackageModel.fromJson(Map<String, dynamic> json) {
    final rawFeatures =
        json['features'] ?? json['package_features'] ?? json['description'];
    final features = rawFeatures is List
        ? rawFeatures.map((value) => value.toString()).toList()
        : rawFeatures is String
            ? rawFeatures
                .split(RegExp(r'\r?\n|,'))
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty)
                .toList()
            : <String>[];
    final rawPrice = json['final_price'] ?? json['price'];
    return InspectionPackageModel(
      id: int.tryParse(json['id']?.toString() ?? ''),
      name: json['name']?.toString() ?? 'Inspection',
      price: double.tryParse(rawPrice?.toString() ?? '') ?? 0,
      points: (json['points'] ??
              json['inspection_points'] ??
              json['item_limit'] ??
              '')
          .toString(),
      features: features,
    );
  }
}

class CarInspectionRecord {
  final int? id;
  final int? packageId;
  final String status;
  final String packageName;
  final String appointmentDate;
  final String updatedAt;
  final String userNumber;
  final String sellerNumber;
  final String email;
  final String paymentType;
  final String paymentStatus;
  final String inspectionReport;
  final double? price;

  const CarInspectionRecord({
    this.id,
    this.packageId,
    required this.status,
    required this.packageName,
    required this.appointmentDate,
    this.updatedAt = '',
    this.userNumber = '',
    required this.sellerNumber,
    this.email = '',
    this.paymentType = '',
    this.paymentStatus = '',
    this.inspectionReport = '',
    this.price,
  });

  bool get hasInspectionReport => inspectionReport.trim().isNotEmpty;

  factory CarInspectionRecord.fromJson(Map<String, dynamic> json) {
    final package = json['package'];
    return CarInspectionRecord(
      id: int.tryParse(json['id']?.toString() ?? ''),
      packageId: int.tryParse(json['package_id']?.toString() ?? ''),
      status:
          (json['status'] ?? json['payment_status'] ?? 'Pending').toString(),
      packageName: (json['package_name'] ??
              (package is Map ? package['name'] : null) ??
              (json['package_id'] == null
                  ? 'Car Inspection'
                  : 'Package #${json['package_id']}'))
          .toString(),
      appointmentDate: (json['appointment_date'] ??
              json['scheduled_at'] ??
              json['created_at'] ??
              '')
          .toString(),
      updatedAt: (json['updated_at'] ?? '').toString(),
      userNumber: (json['user_number'] ?? '').toString(),
      sellerNumber: (json['seller_number'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      paymentType: (json['payment_type'] ?? '').toString(),
      paymentStatus: (json['payment_status'] ?? '').toString(),
      inspectionReport: (json['inspection_report'] ?? '').toString(),
      price: double.tryParse(json['price']?.toString() ?? ''),
    );
  }
}

class MotorsServiceFaq {
  final String question;
  final String answer;

  const MotorsServiceFaq(this.question, {this.answer = ''});
}

class MotorsServiceReview {
  final String name;
  final String title;
  final String review;

  const MotorsServiceReview({
    required this.name,
    required this.title,
    required this.review,
  });
}
