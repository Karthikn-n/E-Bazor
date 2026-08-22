import 'dart:async';
import 'dart:developer';

import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/data/model/item_filter_model.dart';
import 'package:Ebozor/data/repositories/category_repository.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_keys.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class JobSearchScreen extends StatefulWidget {
  final String? initialQuery;

  const JobSearchScreen({super.key, this.initialQuery});

  static Route route(RouteSettings settings) {
    Map? args = settings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => JobSearchScreen(
        initialQuery: args?['query'] ?? args?['search'],
      ),
    );
  }

  @override
  State<JobSearchScreen> createState() => _JobSearchScreenState();
}

class _JobSearchScreenState extends State<JobSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  bool _isLoading = false;
  List<ItemModel> _jobResults = [];
  List<String> _recentSearches = [];

  static const String _recentJobsKey = "job_recent_searches";

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _searchController.text = widget.initialQuery!.trim();
      _onQueryChanged(widget.initialQuery!.trim());
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _loadRecentSearches() {
    try {
      if (Hive.isBoxOpen(HiveKeys.historyBox)) {
        final raw = Hive.box(HiveKeys.historyBox).get(_recentJobsKey);
        if (raw is List) {
          _recentSearches = raw.map((e) => e.toString()).toList();
        }
      }
    } catch (e) {
      log("Error loading recent job searches: $e");
    }
    setState(() {});
  }

  void _saveRecentSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    _recentSearches
        .removeWhere((e) => e.trim().toLowerCase() == trimmed.toLowerCase());
    _recentSearches.insert(0, trimmed);
    if (_recentSearches.length > 15) {
      _recentSearches = _recentSearches.sublist(0, 15);
    }

    try {
      if (Hive.isBoxOpen(HiveKeys.historyBox)) {
        Hive.box(HiveKeys.historyBox).put(_recentJobsKey, _recentSearches);
      }
    } catch (e) {
      log("Error saving recent job search: $e");
    }
    setState(() {});
  }

  void _clearRecentSearches() {
    _recentSearches.clear();
    try {
      if (Hive.isBoxOpen(HiveKeys.historyBox)) {
        Hive.box(HiveKeys.historyBox).delete(_recentJobsKey);
      }
    } catch (e) {
      log("Error clearing recent job searches: $e");
    }
    setState(() {});
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _isLoading = false;
        _jobResults = [];
      });
      return;
    }

    setState(() => _isLoading = true);

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchSearchResults(trimmed);
    });
  }

  Future<void> _fetchSearchResults(String query) async {
    /*
    // 1. Call Search Job Suggestion API
    try {
      final suggestionRes = await Api.get(
        queryParameters: {'text': query},
      );
      log("🔍 [JOB SEARCH SUGGESTION API RES]: $suggestionRes");
      if (mounted && suggestionRes['data'] != null) {
        if (suggestionRes['data'] is List) {
          _suggestions = suggestionRes['data'] as List;
        }
      }
    } catch (e) {
      log("⚠️ [JOB SEARCH SUGGESTION ERROR]: $e");
    }

    */
    // Search jobs only through get-item.
    try {
      final itemRes = await Api.get(
        url: Api.getItemApi,
        queryParameters: {
          'search': query,
          'page': 1,
          'category_id': 4,
          'city': HiveUtils.getCityName() ?? 'Dubai',
        },
      );
      log("📦 [JOB GET-ITEM SEARCH RES]: $itemRes");

      if (mounted) {
        List<ItemModel> parsedItems = [];
        if (itemRes['data'] != null && itemRes['data']['data'] is List) {
          parsedItems = (itemRes['data']['data'] as List)
              .whereType<Map<String, dynamic>>()
              .map((json) => ItemModel.fromJson(json))
              .toList();
        }

        setState(() {
          _jobResults = parsedItems;
          _isLoading = false;
        });
      }
    } catch (e) {
      log("⚠️ [JOB GET-ITEM SEARCH ERROR]: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _submitSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    _saveRecentSearch(trimmed);
    FocusScope.of(context).unfocus();
    _fetchSearchResults(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final isQueryEmpty = _searchController.text.trim().isEmpty;

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
          leadingWidth: 44,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: context.color.textDefaultColor,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          titleSpacing: 0,
          title: Container(
            height: 44,
            margin: const EdgeInsets.only(right: 16),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onQueryChanged,
              onSubmitted: _submitSearch,
              style: TextStyle(
                color: context.color.textDefaultColor,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: "What are you looking for?",
                hintStyle: TextStyle(
                  color: context.color.textLightColor.withValues(alpha: 0.8),
                  fontSize: 15,
                  fontWeight: FontWeight.normal,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: context.color.textLightColor,
                          size: 20,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _onQueryChanged("");
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
        body: isQueryEmpty
            ? _buildRecentSearchesView()
            : _buildGetItemJobResultsView(),
      ),
    );
  }

  // 1. Recent Searches View (matching screenshot)
  Widget _buildRecentSearchesView() {
    if (_recentSearches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.search_rounded,
                size: 48,
                color: context.color.textLightColor.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              Text(
                "Search jobs by title, company, or skills",
                style: TextStyle(
                  color: context.color.textLightColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Recent Searches",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.color.textLightColor,
                ),
              ),
              GestureDetector(
                onTap: _clearRecentSearches,
                child: Text(
                  "Clear",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: _recentSearches.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: context.color.borderColor.withValues(alpha: 0.4),
            ),
            itemBuilder: (context, index) {
              final query = _recentSearches[index];
              return InkWell(
                onTap: () {
                  _searchController.text = query;
                  _submitSearch(query);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 20,
                        color: context.color.textLightColor,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            text: "$query in ",
                            style: TextStyle(
                              fontSize: 15,
                              color: context.color.textDefaultColor,
                              fontWeight: FontWeight.normal,
                            ),
                            children: const [
                              TextSpan(
                                text: "Jobs",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openJobSuggestion(ItemModel item) async {
    final query = _searchController.text.trim();
    final leafCategoryId = item.category?.id ?? item.categoryId ?? 4;
    final categorySlug = item.category?.slug?.trim() ?? '';
    final categoryName = item.category?.name ?? 'Jobs';

    FilterCategory? configuration;
    if (categorySlug.isNotEmpty) {
      try {
        configuration = await FilterRepository().getFilters(categorySlug);
      } catch (_) {
        configuration = null;
      }
    }
    if (!mounted) return;

    final leafCategory = CategoryModel(
      id: leafCategoryId,
      name: categoryName,
      slug: categorySlug,
      children: [],
      subcategoriesCount: 0,
    );
    final jobsCategory = CategoryModel(
      id: 4,
      name: 'Jobs',
      slug: 'jobs',
      children: [leafCategory],
      subcategoriesCount: 1,
    );
    final appliedFilter = ItemFilterModel(
      categoryId: leafCategoryId.toString(),
      categorySlug: categorySlug.isEmpty ? null : categorySlug,
      city: HiveUtils.getCityName(),
      state: HiveUtils.getStateName(),
      country: HiveUtils.getCountryName(),
      areaId: HiveUtils.getAreaId(),
    );
    _saveRecentSearch(query);
    Navigator.pushNamed(
      context,
      Routes.itemsList,
      arguments: {
        'catID': '4',
        'catName': 'Jobs',
        'categoryIds': ['4', leafCategoryId.toString()],
        'selectedCategoryChain': [jobsCategory, leafCategory],
        'appliedFilter': appliedFilter,
        'filterConfiguration': configuration,
        'search': query,
      },
    );
  }

  Widget _buildGetItemJobResultsView() {
    if (_isLoading) return Center(child: UiUtils.progress());
    if (_jobResults.isEmpty) {
      return Center(
        child: Text(
          'No matching jobs found',
          style: TextStyle(color: context.color.textLightColor, fontSize: 14),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Matching Jobs',
            style: TextStyle(
              color: context.color.textDefaultColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: _jobResults.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: context.color.borderColor.withValues(alpha: 0.45),
            ),
            itemBuilder: (context, index) {
              final item = _jobResults[index];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openJobSuggestion(item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: context.color.territoryColor
                                .withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.work_outline_rounded,
                            color: context.color.territoryColor,
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.color.textDefaultColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.category?.name ?? 'Jobs',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.color.textLightColor,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: context.color.textLightColor,
                          size: 25,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /* Legacy mixed suggestion/result UI retained temporarily for comparison.
  Widget _buildSearchResultsView() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final query = _searchController.text.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Search for '$query' in Jobs" banner tile
          InkWell(
            onTap: () => _submitSearch(query),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFDBEAFE),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        text: "Search for ",
                        style: const TextStyle(
                          color: Color(0xFF1E40AF),
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: "'$query'",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E40AF),
                            ),
                          ),
                          const TextSpan(
                            text: " in Jobs",
                            style: TextStyle(
                              color: Color(0xFF1E40AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Color(0xFF2563EB),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Suggestions list if available
          if (_suggestions.isNotEmpty) ...[
            Text(
              "Suggestions",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: context.color.textLightColor,
              ),
            ),
            const SizedBox(height: 8),
            ..._suggestions.map((s) {
              final suggestionText = s is Map
                  ? (s['name'] ?? s['title'] ?? s.toString())
                  : s.toString();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.trending_up_rounded,
                  color: context.color.textLightColor,
                  size: 20,
                ),
                title: Text(
                  suggestionText,
                  style: TextStyle(
                    color: context.color.textDefaultColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  _searchController.text = suggestionText;
                  _submitSearch(suggestionText);
                },
              );
            }),
            const SizedBox(height: 16),
          ],

          // Job Results
          if (_jobResults.isNotEmpty) ...[
            Text(
              "Matching Jobs (${_jobResults.length})",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: context.color.textDefaultColor,
              ),
            ),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _jobResults.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = _jobResults[index];
                return _buildJobResultCard(item);
              },
            ),
          ] else if (!_isLoading && query.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.work_off_outlined,
                      size: 44,
                      color:
                          context.color.textLightColor.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "No direct job matches found for '$query'",
                      style: TextStyle(
                        color: context.color.textLightColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD31027),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => _submitSearch(query),
                      child: Text("Search all listings for '$query'"),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  */
  Widget _buildJobResultCard(ItemModel item) {
    return Container(
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _saveRecentSearch(_searchController.text.trim());
          Navigator.pushNamed(
            context,
            Routes.adDetailsScreen,
            arguments: {'model': item},
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo / Image
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFFD31027).withValues(alpha: 0.08),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: item.image != null && item.image!.trim().isNotEmpty
                      ? UiUtils.getImage(item.image!, fit: BoxFit.cover)
                      : const Icon(
                          Icons.work_outline_rounded,
                          color: Color(0xFFD31027),
                          size: 24,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name ?? "",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (item.category?.name != null)
                      Text(
                        item.category!.name!,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.color.textLightColor,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (item.price != null && item.price! > 0) ...[
                          Text(
                            "${Constant.currencySymbol} ${item.price!.toInt()} / month",
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (item.city != null && item.city!.isNotEmpty) ...[
                          Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: context.color.textLightColor,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            item.city!,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: context.color.textLightColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
