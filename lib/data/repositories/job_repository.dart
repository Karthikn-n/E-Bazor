import 'dart:developer';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:Ebozor/data/model/job_models.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';

class JobRepository {
  Future<List<PopularJobItem>> fetchPopularJobs({
    int categoryId = 4,
    String? city,
  }) async {
    try {
      final user = HiveUtils.getUserDetails();
      final Map<String, dynamic> params = {
        'category_id': categoryId,
        if (user.id != null) 'user_id': user.id,
        if (city != null && city.isNotEmpty) 'city': city,
      };

      final response = await Api.get(
        url: Api.getPopularJobApi,
        queryParameters: params,
      );

      final List rawData = response['data'] is List ? response['data'] : [];
      final List<PopularJobItem> popularJobs = [];

      for (final section in rawData) {
        if (section is Map<String, dynamic>) {
          final sectionData = section['section_data'] as List?;
          if (sectionData != null) {
            for (final item in sectionData) {
              if (item is Map<String, dynamic>) {
                popularJobs.add(PopularJobItem.fromJson(item));
              }
            }
          }
        }
      }

      return popularJobs;
    } catch (e) {
      log("⚠️ [JOB REPO] fetchPopularJobs error: $e");
      return [];
    }
  }

  Future<List<JobCategoryCount>> fetchJobCategories({
    int parentCategoryId = 356,
  }) async {
    try {
      final response = await Api.get(
        url: Api.getJobCategoryHomeApi,
        queryParameters: {'parent_category_id': parentCategoryId},
      );

      final data = response['data'];
      List list = [];
      if (data is Map && data['category_item_count'] is List) {
        list = data['category_item_count'];
      } else if (data is List) {
        list = data;
      }

      return list
          .map((e) => JobCategoryCount.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      log("⚠️ [JOB REPO] fetchJobCategories error: $e");
      return [];
    }
  }

  Future<List<JobQualificationCount>> fetchJobQualifications({
    int parentCategoryId = 356,
    String? city,
  }) async {
    try {
      final Map<String, dynamic> params = {
        'parent_category_id': parentCategoryId,
        if (city != null && city.isNotEmpty) 'city': city,
      };

      final response = await Api.get(
        url: Api.getJobQualificationCountApi,
        queryParameters: params,
      );

      final data = response['data'];
      List list = [];
      if (data is Map && data['qualification_item_count'] is List) {
        list = data['qualification_item_count'];
      } else if (data is List) {
        list = data;
      }

      return list
          .map((e) =>
              JobQualificationCount.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      log("⚠️ [JOB REPO] fetchJobQualifications error: $e");
      return [];
    }
  }

  Future<List<JobTypeCount>> fetchJobTypes({
    int parentCategoryId = 356,
    String? city,
  }) async {
    try {
      final Map<String, dynamic> params = {
        'parent_category_id': parentCategoryId,
        if (city != null && city.isNotEmpty) 'city': city,
      };

      final response = await Api.get(
        url: Api.getJobTypeCountApi,
        queryParameters: params,
      );

      final data = response['data'];
      List list = [];
      if (data is Map && data['type_item_count'] is List) {
        list = data['type_item_count'];
      } else if (data is List) {
        list = data;
      }

      return list
          .map((e) => JobTypeCount.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      log("⚠️ [JOB REPO] fetchJobTypes error: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> fetchMyJobApplications() async {
    try {
      final user = HiveUtils.getUserDetails();
      final userId = user.id ?? HiveUtils.getUserId();

      final response = await Api.post(
        url: Api.getMyJobApplicationApi,
        parameter: {
          if (userId != null) 'user_id': userId,
        },
      );

      final List rawData = response['data'] is List ? response['data'] : [];
      final List<MyJobApplicationModel> applications = [];

      for (final item in rawData) {
        if (item is Map<String, dynamic>) {
          applications.add(MyJobApplicationModel.fromJson(item));
        }
      }

      return {
        'applications': applications,
        'under_review_count': response['under_review_count'] ?? 0,
        'rejected_count': response['rejected_count'] ?? 0,
      };
    } catch (e) {
      log("⚠️ [JOB REPO] fetchMyJobApplications error: $e");
      return {
        'applications': <MyJobApplicationModel>[],
        'under_review_count': 0,
        'rejected_count': 0,
      };
    }
  }

  Future<JobApplicationInfoModel?> fetchJobApplicationInfo() async {
    try {
      final user = HiveUtils.getUserDetails();
      final userId = user.id ?? HiveUtils.getUserId();

      final response = await Api.post(
        url: Api.getJobApplicationInfoApi,
        parameter: {
          if (userId != null) 'user_id': userId,
        },
      );

      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return JobApplicationInfoModel.fromJson(data);
      } else if (data is List && data.isNotEmpty && data.first is Map<String, dynamic>) {
        return JobApplicationInfoModel.fromJson(data.first);
      }
      return null;
    } catch (e) {
      log("⚠️ [JOB REPO] fetchJobApplicationInfo error: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>> saveJobApplicationInfo(
    Map<String, dynamic> details, {
    File? resumeFile,
  }) async {
    try {
      final user = HiveUtils.getUserDetails();
      final userId = user.id ?? HiveUtils.getUserId();

      final Map<String, dynamic> parameters = {
        if (userId != null) 'user_id': userId,
        ...details,
      };

      if (resumeFile != null && resumeFile.existsSync()) {
        parameters['resume'] = await MultipartFile.fromFile(
          resumeFile.path,
          filename: path.basename(resumeFile.path),
        );
      }

      final response = await Api.post(
        url: Api.addJobApplicationInfoApi,
        parameter: parameters,
      );

      return response;
    } catch (e) {
      log("⚠️ [JOB REPO] saveJobApplicationInfo error: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> fetchUserDetail() async {
    try {
      final user = HiveUtils.getUserDetails();
      final userId = user.id ?? HiveUtils.getUserId();

      final response = await Api.post(
        url: Api.getUserDetailApi,
        parameter: {
          if (userId != null) 'user_id': userId,
        },
      );

      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
      return null;
    } catch (e) {
      log("⚠️ [JOB REPO] fetchUserDetail error: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>> saveUserDetail(
    Map<String, dynamic> details, {
    File? resumeFile,
    File? profileFile,
  }) async {
    try {
      final user = HiveUtils.getUserDetails();
      final userId = user.id ?? HiveUtils.getUserId();

      final Map<String, dynamic> parameters = {
        if (userId != null) 'user_id': userId,
        ...details,
      };

      if (resumeFile != null && resumeFile.existsSync()) {
        parameters['resume'] = await MultipartFile.fromFile(
          resumeFile.path,
          filename: path.basename(resumeFile.path),
        );
      }

      if (profileFile != null && profileFile.existsSync()) {
        parameters['profile'] = await MultipartFile.fromFile(
          profileFile.path,
          filename: path.basename(profileFile.path),
        );
      }

      final response = await Api.post(
        url: Api.addUserDetailApi,
        parameter: parameters,
      );

      return response;
    } catch (e) {
      log("⚠️ [JOB REPO] saveUserDetail error: $e");
      rethrow;
    }
  }
}
