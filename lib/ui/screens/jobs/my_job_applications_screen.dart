import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/data/model/job_models.dart';
import 'package:Ebozor/data/repositories/job_repository.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ui_utils.dart';

class MyJobApplicationsScreen extends StatefulWidget {
  const MyJobApplicationsScreen({super.key});

  static Route route(RouteSettings settings) {
    return CupertinoPageRoute(
      builder: (context) => const MyJobApplicationsScreen(),
    );
  }

  @override
  State<MyJobApplicationsScreen> createState() =>
      _MyJobApplicationsScreenState();
}

class _MyJobApplicationsScreenState extends State<MyJobApplicationsScreen> {
  final JobRepository _jobRepository = JobRepository();

  bool _isLoading = true;
  List<MyJobApplicationModel> _applications = [];
  int _underReviewCount = 0;
  int _rejectedCount = 0;
  String _selectedFilter = "All";

  final List<String> _filters = [
    "All",
    "Under Review",
    "Shortlisted",
    "Rejected",
  ];

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() => _isLoading = true);
    final result = await _jobRepository.fetchMyJobApplications();
    if (mounted) {
      setState(() {
        _applications = result['applications'] as List<MyJobApplicationModel>;
        _underReviewCount = result['under_review_count'] as int;
        _rejectedCount = result['rejected_count'] as int;
        _isLoading = false;
      });
    }
  }

  List<MyJobApplicationModel> get _filteredApplications {
    if (_selectedFilter == "All") {
      return _applications;
    }
    return _applications.where((app) {
      final status = (app.applicationStatus ?? "").toLowerCase();
      if (_selectedFilter == "Under Review") {
        return status.contains("review") || status.contains("pending");
      } else if (_selectedFilter == "Shortlisted") {
        return status.contains("shortlist") || status.contains("accept");
      } else if (_selectedFilter == "Rejected") {
        return status.contains("reject");
      }
      return true;
    }).toList();
  }

  void _onApplicationTapped(MyJobApplicationModel app) {
    if (app.itemDetails != null && app.itemDetails!.id != null) {
      Navigator.pushNamed(
        context,
        Routes.adDetailsScreen,
        arguments: {
          'model': ItemModel(
            id: app.itemDetails!.id,
            name: app.itemDetails!.name,
            slug: app.itemDetails!.slug,
            image: app.itemDetails!.image,
          ),
        },
      );
    } else {
      _showApplicationStatusBottomSheet(app);
    }
  }

  void _showApplicationStatusBottomSheet(MyJobApplicationModel app) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final status = app.applicationStatus ?? "Under Review";
        final isReview = status.toLowerCase().contains("review");
        final isRejected = status.toLowerCase().contains("reject");

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.color.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Application Details",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isReview
                            ? Colors.blue.withValues(alpha: 0.12)
                            : isRejected
                                ? Colors.red.withValues(alpha: 0.12)
                                : Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isReview
                              ? Colors.blue.shade700
                              : isRejected
                                  ? Colors.red
                                  : Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  "Job Title",
                  app.itemDetails?.name ?? app.jobCategory ?? "Position",
                ),
                _buildInfoRow(
                  "Company",
                  app.currentCompany ?? "Not Specified",
                ),
                _buildInfoRow(
                  "Applicant Name",
                  app.fullName ?? "Candidate",
                ),
                _buildInfoRow(
                  "Experience",
                  app.totalExperience ?? "N/A",
                ),
                _buildInfoRow(
                  "Notice Period",
                  app.noticePeriod ?? "N/A",
                ),
                if (app.createdAt != null)
                  _buildInfoRow(
                    "Applied Date",
                    _formatDate(app.createdAt!),
                  ),
                const SizedBox(height: 20),
                if (app.resume != null && app.resume!.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.description_outlined),
                      label: const Text("View Submitted Resume"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.color.territoryColor,
                        side: BorderSide(color: context.color.territoryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        final uri = Uri.parse(app.resume!);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              color: context.color.textLightColor,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: context.color.textDefaultColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredApplications;

    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: UiUtils.buildAppBar(
        context,
        title: "My Job Applications",
        showBackButton: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadApplications,
        color: context.color.territoryColor,
        child: Column(
          children: [
            // Filter Pills Horizontal Bar
            _buildFilterPillsBar(),

            // Main Application List / Empty state / Loader
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? _buildEmptyView()
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _buildApplicationCard(filtered[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPillsBar() {
    return Container(
      color: context.color.secondaryColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: _filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            int count = 0;
            if (filter == "All") {
              count = _applications.length;
            } else if (filter == "Under Review") {
              count = _underReviewCount;
            } else if (filter == "Rejected") {
              count = _rejectedCount;
            }

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedFilter = filter;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.color.territoryColor
                        : context.color.backgroundColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? context.color.territoryColor
                          : context.color.borderColor,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        filter,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : context.color.textDefaultColor,
                        ),
                      ),
                      if (count > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.25)
                                : context.color.territoryColor
                                    .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "$count",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : context.color.territoryColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildApplicationCard(MyJobApplicationModel app) {
    final status = app.applicationStatus ?? "Under Review";
    final isReview = status.toLowerCase().contains("review");
    final isRejected = status.toLowerCase().contains("reject");

    final jobTitle = app.itemDetails?.name ??
        app.jobCategory ??
        app.currentPosition ??
        "Job Application";
    final company = app.currentCompany ?? app.industry ?? "Confidential";

    return Material(
      color: context.color.secondaryColor,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: () => _onApplicationTapped(app),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: context.color.borderColor.withValues(alpha: 0.6),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Title + Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                          context.color.territoryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.work_outline_rounded,
                      color: context.color.territoryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          jobTitle,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: context.color.textDefaultColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          company,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.color.textLightColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isReview
                          ? Colors.blue.withValues(alpha: 0.12)
                          : isRejected
                              ? Colors.red.withValues(alpha: 0.12)
                              : Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isReview
                            ? Colors.blue.shade700
                            : isRejected
                                ? Colors.red
                                : Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Chips: Experience, Education, Notice period
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (app.totalExperience != null &&
                      app.totalExperience!.isNotEmpty)
                    _buildChip(Icons.timeline_rounded, app.totalExperience!),
                  if (app.educationLevel != null &&
                      app.educationLevel!.isNotEmpty &&
                      app.educationLevel != "N/A")
                    _buildChip(Icons.school_outlined, app.educationLevel!),
                  if (app.noticePeriod != null &&
                      app.noticePeriod!.isNotEmpty)
                    _buildChip(Icons.schedule_rounded, app.noticePeriod!),
                  if (app.currentlyLocated != null &&
                      app.currentlyLocated!.isNotEmpty)
                    _buildChip(
                        Icons.location_on_outlined, app.currentlyLocated!),
                ],
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: context.color.borderColor.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 10),

              // Bottom Date and Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    app.createdAt != null
                        ? "Applied ${_formatDate(app.createdAt!)}"
                        : "Applied Recently",
                    style: TextStyle(
                      fontSize: 12,
                      color: context.color.textLightColor,
                    ),
                  ),
                  Row(
                    children: [
                      if (app.resume != null && app.resume!.isNotEmpty) ...[
                        InkWell(
                          onTap: () async {
                            final uri = Uri.parse(app.resume!);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                          child: Row(
                            children: [
                              Icon(
                                Icons.picture_as_pdf_outlined,
                                size: 14,
                                color: context.color.territoryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "Resume",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: context.color.territoryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 13,
                        color: context.color.textLightColor,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.color.backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: context.color.textLightColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              color: context.color.textColorDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: context.color.territoryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.work_history_outlined,
                size: 40,
                color: context.color.territoryColor,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              "No Job Applications Found",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.color.textColorDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You haven't submitted any job applications yet or no applications match the selected status.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: context.color.textLightColor,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.color.territoryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                Navigator.pushNamed(context, Routes.jobHomeScreen);
              },
              child: const Text(
                "Explore Jobs",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
