class PopularJobItem {
  final int id;
  final String name;
  final String slug;
  final double price;
  final String city;
  final String state;
  final String country;
  final String? image;
  final int categoryId;
  final String? categoryName;
  final String? companyName;
  final String? employmentType;
  final String? monthlySalary;
  final String? workExperience;
  final String? educationLevel;
  final String? jobRole;
  final String? industry;
  final List<String> allCategoryIds;

  PopularJobItem({
    required this.id,
    required this.name,
    required this.slug,
    required this.price,
    required this.city,
    required this.state,
    required this.country,
    this.image,
    required this.categoryId,
    this.categoryName,
    this.companyName,
    this.employmentType,
    this.monthlySalary,
    this.workExperience,
    this.educationLevel,
    this.jobRole,
    this.industry,
    this.allCategoryIds = const [],
  });

  factory PopularJobItem.fromJson(Map<String, dynamic> json) {
    String? companyName;
    String? employmentType;
    String? monthlySalary;
    String? workExperience;
    String? educationLevel;
    String? jobRole;
    String? industry;

    final customValues = json['item_custom_field_values'] as List?;
    if (customValues != null) {
      for (final cf in customValues) {
        if (cf is Map<String, dynamic>) {
          final cfDef = cf['custom_field'] as Map<String, dynamic>?;
          final cfName = (cfDef?['name'] ?? '').toString().toLowerCase().trim();
          final valList = cf['value'];
          String? valStr;
          if (valList is List && valList.isNotEmpty) {
            valStr = valList.first.toString();
          } else if (valList != null) {
            valStr = valList.toString();
          }

          if (cfName.contains('company name')) {
            companyName = valStr;
          } else if (cfName.contains('employment type')) {
            employmentType = valStr;
          } else if (cfName.contains('monthly salary')) {
            monthlySalary = valStr;
          } else if (cfName.contains('work experience') || cfName.contains('experience')) {
            workExperience = valStr;
          } else if (cfName.contains('education')) {
            educationLevel = valStr;
          } else if (cfName.contains('job role')) {
            jobRole = valStr;
          } else if (cfName.contains('industry')) {
            industry = valStr;
          }
        }
      }
    }

    final allCatIdsStr = (json['all_category_ids'] ?? '').toString();
    final allCatIds = allCatIdsStr.split(',').where((e) => e.trim().isNotEmpty).toList();

    return PopularJobItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0,
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      country: json['country'] ?? '',
      image: json['image'],
      categoryId: json['category_id'] ?? 4,
      categoryName: json['category_name'] ?? json['category']?['name'],
      companyName: companyName ?? 'Confidential',
      employmentType: employmentType ?? 'Full Time',
      monthlySalary: monthlySalary,
      workExperience: workExperience,
      educationLevel: educationLevel,
      jobRole: jobRole,
      industry: industry,
      allCategoryIds: allCatIds,
    );
  }
}

class JobCategoryCount {
  final int categoryId;
  final String name;
  final String slug;
  final int count;
  final String? image;

  JobCategoryCount({
    required this.categoryId,
    required this.name,
    required this.slug,
    required this.count,
    this.image,
  });

  factory JobCategoryCount.fromJson(Map<String, dynamic> json) {
    return JobCategoryCount(
      categoryId: json['category_id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      count: json['count'] ?? 0,
      image: json['image'],
    );
  }
}

class JobTypeCount {
  final String name;
  final String slug;
  final int count;

  JobTypeCount({
    required this.name,
    required this.slug,
    required this.count,
  });

  factory JobTypeCount.fromJson(Map<String, dynamic> json) {
    return JobTypeCount(
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      count: json['count'] ?? 0,
    );
  }
}

class JobQualificationCount {
  final String name;
  final String slug;
  final int count;

  JobQualificationCount({
    required this.name,
    required this.slug,
    required this.count,
  });

  factory JobQualificationCount.fromJson(Map<String, dynamic> json) {
    return JobQualificationCount(
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      count: json['count'] ?? 0,
    );
  }
}

class JobApplicationItemDetails {
  final int? id;
  final String? name;
  final String? slug;
  final String? image;
  final List<String> images;
  final String? createdAt;

  JobApplicationItemDetails({
    this.id,
    this.name,
    this.slug,
    this.image,
    this.images = const [],
    this.createdAt,
  });

  factory JobApplicationItemDetails.fromJson(Map<String, dynamic> json) {
    final imgs = json['images'];
    List<String> imgList = [];
    if (imgs is List) {
      imgList = imgs.map((e) => e.toString()).toList();
    }
    return JobApplicationItemDetails(
      id: json['id'],
      name: json['name'],
      slug: json['slug'],
      image: json['image'],
      images: imgList,
      createdAt: json['created_at'],
    );
  }
}

class MyJobApplicationModel {
  final int id;
  final int? itemId;
  final int? userId;
  final String? fullName;
  final String? emailId;
  final String? nationality;
  final String? phoneNo;
  final String? gender;
  final String? visaStatus;
  final String? educationLevel;
  final String? totalExperience;
  final String? currentlyLocated;
  final String? jobStatus;
  final String? jobCategory;
  final String? currentCompany;
  final String? currentPosition;
  final String? industry;
  final String? noticePeriod;
  final String? resume;
  final int? status;
  final String? createdAt;
  final String? updatedAt;
  final String? applicationStatus;
  final int? applicantCount;
  final JobApplicationItemDetails? itemDetails;

  MyJobApplicationModel({
    required this.id,
    this.itemId,
    this.userId,
    this.fullName,
    this.emailId,
    this.nationality,
    this.phoneNo,
    this.gender,
    this.visaStatus,
    this.educationLevel,
    this.totalExperience,
    this.currentlyLocated,
    this.jobStatus,
    this.jobCategory,
    this.currentCompany,
    this.currentPosition,
    this.industry,
    this.noticePeriod,
    this.resume,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.applicationStatus,
    this.applicantCount,
    this.itemDetails,
  });

  factory MyJobApplicationModel.fromJson(Map<String, dynamic> json) {
    return MyJobApplicationModel(
      id: json['id'] ?? 0,
      itemId: json['item_id'],
      userId: json['user_id'],
      fullName: json['full_name'],
      emailId: json['email_id'],
      nationality: json['nationality'],
      phoneNo: json['phone_no'],
      gender: json['gender'],
      visaStatus: json['visa_status'],
      educationLevel: json['education_level'],
      totalExperience: json['total_experience'],
      currentlyLocated: json['currentlt_locate'] ?? json['currently_located'],
      jobStatus: json['job_status'],
      jobCategory: json['job_category'],
      currentCompany: json['current_company'],
      currentPosition: json['current_position'],
      industry: json['industry'],
      noticePeriod: json['notice_period'],
      resume: json['resume'],
      status: json['status'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      applicationStatus: json['application_status'] ?? 'Under Review',
      applicantCount: json['applicant_count'],
      itemDetails: json['item_details'] != null &&
              json['item_details'] is Map<String, dynamic>
          ? JobApplicationItemDetails.fromJson(
              Map<String, dynamic>.from(json['item_details']))
          : null,
    );
  }
}

class JobApplicationInfoModel {
  final int? id;
  final int? userId;
  final String? fullName;
  final String? emailId;
  final String? nationality;
  final String? phoneNo;
  final String? gender;
  final String? visaStatus;
  final String? educationLevel;
  final String? totalExperience;
  final String? currentlyLocated;
  final String? jobStatus;
  final String? jobCategory;
  final String? currentCompany;
  final String? currentPosition;
  final String? industry;
  final String? noticePeriod;
  final String? resume;

  JobApplicationInfoModel({
    this.id,
    this.userId,
    this.fullName,
    this.emailId,
    this.nationality,
    this.phoneNo,
    this.gender,
    this.visaStatus,
    this.educationLevel,
    this.totalExperience,
    this.currentlyLocated,
    this.jobStatus,
    this.jobCategory,
    this.currentCompany,
    this.currentPosition,
    this.industry,
    this.noticePeriod,
    this.resume,
  });

  factory JobApplicationInfoModel.fromJson(Map<String, dynamic> json) {
    return JobApplicationInfoModel(
      id: json['id'],
      userId: json['user_id'],
      fullName: json['full_name'],
      emailId: json['email_id'],
      nationality: json['nationality'],
      phoneNo: json['phone_no'],
      gender: json['gender'],
      visaStatus: json['visa_status'],
      educationLevel: json['education_level'],
      totalExperience: json['total_experience'],
      currentlyLocated: json['currentlt_locate'] ?? json['currently_located'],
      jobStatus: json['job_status'],
      jobCategory: json['job_category'],
      currentCompany: json['current_company'],
      currentPosition: json['current_position'],
      industry: json['industry'],
      noticePeriod: json['notice_period'],
      resume: json['resume'],
    );
  }
}
