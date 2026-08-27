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

class CarAppointmentModel {
  final int? id;
  final int? userId;
  final int? inspectionId;
  final String appointmentNumber;
  final String serviceType;
  final String status;
  final String carTitle;
  final String? carImage;
  final String? carMake;
  final String? carModel;
  final String? carYear;
  final String? carTrim;
  final String appointmentDate;
  final String? appointmentTime;
  final String? location;
  final String? address;
  final String? userName;
  final String? userPhone;
  final String? phoneNo;
  final String? userEmail;
  final String? notes;
  final double? amount;
  final String? paymentStatus;
  final String? inspectionStatus;
  final String? inspectionPrice;
  final String? createdAt;
  final String? updatedAt;

  const CarAppointmentModel({
    this.id,
    this.userId,
    this.inspectionId,
    this.appointmentNumber = '',
    required this.serviceType,
    required this.status,
    required this.carTitle,
    this.carImage,
    this.carMake,
    this.carModel,
    this.carYear,
    this.carTrim,
    required this.appointmentDate,
    this.appointmentTime,
    this.location,
    this.address,
    this.userName,
    this.userPhone,
    this.phoneNo,
    this.userEmail,
    this.notes,
    this.amount,
    this.paymentStatus,
    this.inspectionStatus,
    this.inspectionPrice,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPast {
    final s = status.toLowerCase();
    if (s == 'completed' ||
        s == 'cancelled' ||
        s == 'past' ||
        s == 'rejected' ||
        s == 'expired') {
      return true;
    }
    if (appointmentDate.isNotEmpty) {
      final date = DateTime.tryParse(appointmentDate);
      if (date != null && date.isBefore(DateTime.now())) {
        return true;
      }
    }
    return false;
  }

  factory CarAppointmentModel.fromJson(Map<String, dynamic> json) {
    final user =
        json['user'] is Map ? json['user'] as Map<String, dynamic> : null;
    final inspection = json['inspection'] is Map
        ? json['inspection'] as Map<String, dynamic>
        : null;

    final make = json['car_make'] ?? json['make'] ?? json['car_make_name'];
    final model = json['car_model'] ?? json['model'] ?? json['car_model_name'];
    final year = json['car_year'] ?? json['year'];
    final trim = json['car_trim'] ?? json['trim'];
    final title = json['car_name'] ??
        json['car_title'] ??
        json['title'] ??
        [if (year != null) year, if (make != null) make, if (model != null) model]
            .join(' ')
            .trim();

    final phone = (json['phone_no'] ??
            json['phone'] ??
            json['user_phone'] ??
            json['user_number'] ??
            user?['mobile'] ??
            json['contact'])
        ?.toString();

    final inspPrice =
        inspection?['price']?.toString() ?? json['price']?.toString();
    final rawAmount = json['amount'] ?? inspPrice;

    return CarAppointmentModel(
      id: int.tryParse(json['id']?.toString() ?? ''),
      userId: int.tryParse(json['user_id']?.toString() ?? ''),
      inspectionId: int.tryParse(
          (json['inspection_id'] ?? inspection?['id'])?.toString() ?? ''),
      appointmentNumber: (json['appointment_number'] ??
              json['reference_number'] ??
              (json['id'] != null ? '#APT-${json['id']}' : ''))
          .toString(),
      serviceType: (json['service_type'] ??
              json['type'] ??
              json['service_name'] ??
              'Car Appointment')
          .toString(),
      status: (json['status'] ?? 'pending').toString(),
      carTitle: title.isNotEmpty ? title : 'Car Appointment',
      carImage: (json['car_image'] ?? json['image'])?.toString(),
      carMake: make?.toString(),
      carModel: model?.toString(),
      carYear: year?.toString(),
      carTrim: trim?.toString(),
      appointmentDate: (json['appointment_date'] ??
              json['date'] ??
              json['scheduled_at'] ??
              json['created_at'] ??
              '')
          .toString(),
      appointmentTime: (json['appointment_time'] ?? json['time'])?.toString(),
      location: (json['location'] ??
              json['hub_location'] ??
              json['branch_name'] ??
              json['city'])
          ?.toString(),
      address: json['address']?.toString(),
      userName: (json['user_name'] ?? user?['name'] ?? json['name'])?.toString(),
      userPhone: phone,
      phoneNo: phone,
      userEmail: (json['user_email'] ?? user?['email'] ?? json['email'])?.toString(),
      notes: json['notes']?.toString(),
      amount: double.tryParse(rawAmount?.toString() ?? ''),
      paymentStatus: (inspection?['payment_status'] ?? json['payment_status'])
          ?.toString(),
      inspectionStatus:
          (inspection?['status'] ?? json['inspection_status'])?.toString(),
      inspectionPrice: inspPrice,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }
}
