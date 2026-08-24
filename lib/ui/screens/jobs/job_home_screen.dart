import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/data/model/job_models.dart';
import 'package:Ebozor/data/repositories/job_repository.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class JobHomeScreen extends StatefulWidget {
  final CategoryModel? category;

  const JobHomeScreen({super.key, this.category});

  @override
  State<JobHomeScreen> createState() => _JobHomeScreenState();

  static Route route(RouteSettings routeSettings) {
    Map? args = routeSettings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => JobHomeScreen(
        category: args?['category'],
      ),
    );
  }
}

class _JobHomeScreenState extends State<JobHomeScreen> {
  final JobRepository _jobRepository = JobRepository();
  final TextEditingController _searchController = TextEditingController();

  List<PopularJobItem> _popularJobs = [];
  List<JobCategoryCount> _jobCategories = [];
  List<JobQualificationCount> _jobQualifications = [];
  List<JobTypeCount> _jobTypes = [];

  bool _isLoading = true;
  String _userCity = "Dubai";

  @override
  void initState() {
    super.initState();
    final city = HiveUtils.getCityName();
    if (city != null && city.isNotEmpty) {
      _userCity = city;
    }
    _loadAllJobData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllJobData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _jobRepository.fetchPopularJobs(categoryId: 4, city: _userCity),
        _jobRepository.fetchJobCategories(parentCategoryId: 356),
        _jobRepository.fetchJobQualifications(
            parentCategoryId: 356, city: _userCity),
        _jobRepository.fetchJobTypes(parentCategoryId: 356, city: _userCity),
      ]);

      if (mounted) {
        setState(() {
          _popularJobs = results[0] as List<PopularJobItem>;
          _jobCategories = results[1] as List<JobCategoryCount>;
          _jobQualifications = results[2] as List<JobQualificationCount>;
          _jobTypes = results[3] as List<JobTypeCount>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: Scaffold(
        backgroundColor: context.color.backgroundColor,
        appBar: AppBar(
          backgroundColor: context.color.secondaryColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: context.color.textDefaultColor,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: Text(
            Constant.appName.isNotEmpty ? Constant.appName : "Ebozor",
            style: TextStyle(
              color: context.color.textDefaultColor,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: -0.5,
            ),
          ),
        ),
        body: RefreshIndicator(
          color: const Color(0xFFD31027),
          onRefresh: _loadAllJobData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Hero Headline (Always visible)
                _buildHeroHeadline(context),
                const SizedBox(height: 18),

                // 2. Search Input Bar (Always visible)
                _buildSearchBar(context),
                const SizedBox(height: 26),

                // 3. Popular Jobs Section (Data or Local Shimmer)
                if (_isLoading) ...[
                  _buildPopularJobsShimmer(context),
                  const SizedBox(height: 28),
                ] else if (_popularJobs.isNotEmpty) ...[
                  _buildPopularJobsSection(context),
                  const SizedBox(height: 28),
                ],

                // 4. Jobs By Category Section (Data or Local Shimmer)
                if (_isLoading) ...[
                  _buildJobsByCategoryShimmer(context),
                  const SizedBox(height: 28),
                ] else if (_jobCategories.isNotEmpty) ...[
                  _buildJobsByCategorySection(context),
                  const SizedBox(height: 28),
                ],

                // 5. Jobs By Qualification (Data or Local Shimmer)
                if (_isLoading) ...[
                  _buildQualificationsShimmer(context),
                  const SizedBox(height: 28),
                ] else if (_jobQualifications.isNotEmpty) ...[
                  _buildQualificationsSection(context),
                  const SizedBox(height: 28),
                ],

                // 6. Jobs By Type (Data or Local Shimmer)
                if (_isLoading) ...[
                  _buildJobTypesShimmer(context),
                  const SizedBox(height: 28),
                ] else if (_jobTypes.isNotEmpty) ...[
                  _buildJobTypesSection(context),
                  const SizedBox(height: 28),
                ],

                // 7. Upload CV Banner (Always visible)
                _buildUploadCvBanner(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 1. Hero Headline
  Widget _buildHeroHeadline(BuildContext context) {
    final appName = Constant.appName.isNotEmpty ? Constant.appName : "Ebozor";

    return RichText(
      text: TextSpan(
        text: "Job hunting ",
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: context.color.textDefaultColor,
          height: 1.25,
        ),
        children: [
          const TextSpan(
            text: "made\neasy ",
            style: TextStyle(
              color: Color(0xFFD31027),
              fontWeight: FontWeight.w900,
            ),
          ),
          TextSpan(
            text: "with $appName",
            style: TextStyle(
              color: context.color.textDefaultColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // 2. Search Bar
  Widget _buildSearchBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.pushNamed(context, Routes.jobSearchScreen);
      },
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2433) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                "What are you looking for?",
                style: TextStyle(
                  color: context.color.textLightColor.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFD31027),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.search_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. Popular Jobs Section
  Widget _buildPopularJobsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Popular Jobs",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.color.textDefaultColor,
          ),
        ),
        const SizedBox(height: 14),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _popularJobs.length > 3 ? 3 : _popularJobs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final job = _popularJobs[index];
            return _buildPopularJobCard(context, job);
          },
        ),
      ],
    );
  }

  Widget _buildPopularJobCard(BuildContext context, PopularJobItem job) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.pushNamed(
            context,
            Routes.adDetailsScreen,
            arguments: {
              'model': ItemModel(
                id: job.id,
                name: job.name,
                slug: job.slug,
                price: job.price,
                city: job.city,
                state: job.state,
                country: job.country,
                image: job.image,
                categoryId: job.categoryId,
                allCategoryIds: job.allCategoryIds.join(','),
              ),
            },
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2433) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Title + Company
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : const Color(0xFFF4F5F7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.business_center_outlined,
                      color: context.color.textLightColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.name,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: context.color.textDefaultColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          job.companyName ?? "Confidential",
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1E88E5),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Metadata Rows
              if (job.employmentType != null &&
                  job.employmentType!.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color: context.color.textLightColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      job.employmentType!,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],

              if (job.monthlySalary != null &&
                  job.monthlySalary!.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      size: 16,
                      color: context.color.textLightColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "AED ${job.monthlySalary} per month",
                      style: TextStyle(
                        fontSize: 13,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],

              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: context.color.textLightColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    job.city.isNotEmpty ? job.city : "Dubai",
                    style: TextStyle(
                      fontSize: 13,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 4. Jobs By Category Section
  Widget _buildJobsByCategorySection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultCategoryImages = {
      'accounting':
          'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?auto=format&fit=crop&w=400&q=80',
      'driver':
          'https://images.unsplash.com/photo-1580674684081-7617fbf3d745?auto=format&fit=crop&w=400&q=80',
      'cleaner':
          'https://images.unsplash.com/photo-1581578731548-c64695cc6952?auto=format&fit=crop&w=400&q=80',
      'handyman':
          'https://images.unsplash.com/photo-1504307651254-35680f356dfd?auto=format&fit=crop&w=400&q=80',
      'sales':
          'https://images.unsplash.com/photo-1560250097-0b93528c311a?auto=format&fit=crop&w=400&q=80',
      'automobile':
          'https://images.unsplash.com/photo-1486006920555-c77dce18193b?auto=format&fit=crop&w=400&q=80',
      'beauty':
          'https://images.unsplash.com/photo-1560066984-138dadb4c035?auto=format&fit=crop&w=400&q=80',
      'construction':
          'https://images.unsplash.com/photo-1541888946425-d0fbb180c5f7?auto=format&fit=crop&w=400&q=80',
      'design':
          'https://images.unsplash.com/photo-1581291518857-4e27b48ff24e?auto=format&fit=crop&w=400&q=80',
    };

    String getCategoryImage(String name, String slug) {
      final key = (name + slug).toLowerCase();
      for (final entry in defaultCategoryImages.entries) {
        if (key.contains(entry.key)) return entry.value;
      }
      return 'https://images.unsplash.com/photo-1521737711867-e3b97375f902?auto=format&fit=crop&w=400&q=80';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Jobs By Category",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.color.textDefaultColor,
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  Routes.subCategoryScreen,
                  arguments: {
                    "categoryList": <CategoryModel>[],
                    "catName": "Find Jobs",
                    "categorySlug": "find-jobs",
                    "catId": 356,
                    "categoryIds": ["4", "356"],
                  },
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFD31027),
                    width: 1.2,
                  ),
                ),
                child: const Text(
                  "View All",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD31027),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 2x2 Grid of Categories
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _jobCategories.length > 4 ? 4 : _jobCategories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.88,
          ),
          itemBuilder: (context, index) {
            final category = _jobCategories[index];
            final imgUrl =
                (category.image != null && category.image!.isNotEmpty)
                    ? category.image!
                    : getCategoryImage(category.name, category.slug);

            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    Routes.itemsList,
                    arguments: {
                      'catID': category.categoryId.toString(),
                      'catName': category.name,
                      'categorySlug': category.slug,
                      'categoryIds': [
                        '4',
                        '356',
                        category.categoryId.toString()
                      ],
                    },
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2433) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Image
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          topRight: Radius.circular(14),
                        ),
                        child: SizedBox(
                          height: 110,
                          width: double.infinity,
                          child: Image.network(
                            imgUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: isDark
                                  ? Colors.white12
                                  : Colors.grey.shade200,
                              child: const Icon(Icons.work_outline,
                                  size: 36, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.name,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: context.color.textDefaultColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${category.count > 0 ? category.count : '10+'} Jobs",
                              style: TextStyle(
                                fontSize: 12,
                                color: context.color.textLightColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // 5. Qualifications Section
  Widget _buildQualificationsSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    IconData getQualificationIcon(String name) {
      final lower = name.toLowerCase();
      if (lower.contains("bachelor")) return Icons.account_balance_outlined;
      if (lower.contains("master")) return Icons.school_outlined;
      if (lower.contains("phd") || lower.contains("doctor"))
        return Icons.emoji_objects_outlined;
      return Icons.menu_book_outlined;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Jobs By Qualification in $_userCity",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.color.textDefaultColor,
          ),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount:
              _jobQualifications.length > 4 ? 4 : _jobQualifications.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.55,
          ),
          itemBuilder: (context, index) {
            final qual = _jobQualifications[index];
            final icon = getQualificationIcon(qual.name);

            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    Routes.itemsList,
                    arguments: {
                      'catID': '356',
                      'catName': qual.name,
                      'categorySlug': 'find-jobs',
                      'categoryIds': ['4', '356'],
                      'search': qual.name,
                    },
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2433) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: const Color(0xFF1E88E5), size: 24),
                      const SizedBox(height: 6),
                      Text(
                        qual.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: context.color.textDefaultColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${qual.count > 0 ? qual.count : '80+'} Jobs",
                        style: TextStyle(
                          fontSize: 11.5,
                          color: context.color.textLightColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // 6. Jobs By Type Section
  Widget _buildJobTypesSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    IconData getJobTypeIcon(String name) {
      final lower = name.toLowerCase();
      if (lower.contains("part")) return Icons.history_toggle_off_rounded;
      if (lower.contains("contract")) return Icons.assignment_outlined;
      if (lower.contains("remote")) return Icons.home_work_outlined;
      return Icons.access_time_rounded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Jobs By Type in $_userCity",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.color.textDefaultColor,
          ),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _jobTypes.length > 4 ? 4 : _jobTypes.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.55,
          ),
          itemBuilder: (context, index) {
            final type = _jobTypes[index];
            final icon = getJobTypeIcon(type.name);

            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    Routes.itemsList,
                    arguments: {
                      'catID': '356',
                      'catName': type.name,
                      'categorySlug': 'find-jobs',
                      'categoryIds': ['4', '356'],
                      'search': type.name,
                    },
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2433) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: const Color(0xFF1E88E5), size: 24),
                      const SizedBox(height: 6),
                      Text(
                        type.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: context.color.textDefaultColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${type.count > 0 ? type.count : '100+'} Jobs",
                        style: TextStyle(
                          fontSize: 11.5,
                          color: context.color.textLightColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // 7. Bottom Upload CV Banner
  Widget _buildUploadCvBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2434) : const Color(0xFFF3F6FD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE1E8F8),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: Color(0xFF1E88E5),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Upload your CV to boost your chances of getting hired faster!",
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.color.textDefaultColor,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFD31027), width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pushNamed(context, Routes.completeProfile);
            },
            child: const Text(
              "Upload CV",
              style: TextStyle(
                color: Color(0xFFD31027),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Section Shimmers
  Widget _buildPopularJobsShimmer(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildShimmerBox(context, width: 140, height: 20, radius: 4),
        const SizedBox(height: 14),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 2,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _buildShimmerBox(
              context,
              width: double.infinity,
              height: 120,
              radius: 14,
            );
          },
        ),
      ],
    );
  }

  Widget _buildJobsByCategoryShimmer(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildShimmerBox(context, width: 160, height: 20, radius: 4),
            _buildShimmerBox(context, width: 70, height: 24, radius: 12),
          ],
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.88,
          ),
          itemBuilder: (context, index) {
            return _buildShimmerBox(
              context,
              width: double.infinity,
              height: double.infinity,
              radius: 14,
            );
          },
        ),
      ],
    );
  }

  Widget _buildQualificationsShimmer(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildShimmerBox(context, width: 180, height: 20, radius: 4),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.55,
          ),
          itemBuilder: (context, index) {
            return _buildShimmerBox(
              context,
              width: double.infinity,
              height: double.infinity,
              radius: 12,
            );
          },
        ),
      ],
    );
  }

  Widget _buildJobTypesShimmer(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildShimmerBox(context, width: 160, height: 20, radius: 4),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.55,
          ),
          itemBuilder: (context, index) {
            return _buildShimmerBox(
              context,
              width: double.infinity,
              height: double.infinity,
              radius: 12,
            );
          },
        ),
      ],
    );
  }

  Widget _buildShimmerBox(
    BuildContext context, {
    required double width,
    required double height,
    required double radius,
  }) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.shimmerBaseColor,
      highlightColor: Theme.of(context).colorScheme.shimmerHighlightColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
