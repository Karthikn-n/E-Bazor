import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/fetch_blogs_cubit.dart';
import 'package:Ebozor/data/model/blog_model.dart';
import 'package:Ebozor/data/repositories/blogs_repository.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_data_found.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_internet.dart';
import 'package:Ebozor/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:Ebozor/ui/screens/widgets/intertitial_ads_screen.dart';
import 'package:Ebozor/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BlogsScreen extends StatefulWidget {
  const BlogsScreen({super.key});

  static Route route(RouteSettings routeSettings) {
    return BlurredRouter(
      builder: (_) => BlocProvider(
        create: (context) => FetchBlogsCubit(),
        child: const BlogsScreen(),
      ),
    );
  }

  @override
  State<BlogsScreen> createState() => _BlogsScreenState();
}

class _BlogsScreenState extends State<BlogsScreen> {
  final ScrollController _pageScrollController = ScrollController();
  final BlogsRepository _blogsRepository = BlogsRepository();

  List<String> _tags = [];
  String _selectedTag = "All";
  bool _isLoadingTags = true;

  @override
  void initState() {
    AdHelper.loadInterstitialAd();
    context.read<FetchBlogsCubit>().fetchBlogs();
    _fetchBlogTags();
    _pageScrollController.addListener(pageScrollListen);
    super.initState();
  }

  Future<void> _fetchBlogTags() async {
    try {
      final tags = await _blogsRepository.fetchBlogTags();
      if (mounted) {
        setState(() {
          _tags = ["All", ...tags];
          _isLoadingTags = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingTags = false);
      }
    }
  }

  void pageScrollListen() {
    if (_pageScrollController.isEndReached()) {
      if (context.read<FetchBlogsCubit>().hasMoreData()) {
        context.read<FetchBlogsCubit>().fetchBlogsMore();
      }
    }
  }

  void _onTagSelected(String tag) {
    if (_selectedTag == tag) return;
    setState(() {
      _selectedTag = tag;
    });
    context.read<FetchBlogsCubit>().fetchBlogs(
          tag: tag == "All" ? null : tag,
        );
  }

  @override
  void dispose() {
    _pageScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AdHelper.showInterstitialAd();
    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: UiUtils.buildAppBar(
        context,
        showBackButton: true,
        title: "blogs".translate(context),
      ),
      body: RefreshIndicator(
        color: context.color.territoryColor,
        onRefresh: () async {
          _fetchBlogTags();
          context.read<FetchBlogsCubit>().fetchBlogs(
                tag: _selectedTag == "All" ? null : _selectedTag,
              );
        },
        child: Column(
          children: [
            // Dynamic Blog Tags Horizontal Filter Bar
            if (_tags.isNotEmpty || _isLoadingTags) _buildTagsFilterBar(context),

            // Blogs List
            Expanded(
              child: BlocBuilder<FetchBlogsCubit, FetchBlogsState>(
                builder: (context, state) {
                  if (state is FetchBlogsInProgress) {
                    return buildBlogsShimmer();
                  }
                  if (state is FetchBlogsFailure) {
                    if (state.errorMessage is ApiException) {
                      if (state.errorMessage.error == "no-internet") {
                        return NoInternet(
                          onRetry: () {
                            context.read<FetchBlogsCubit>().fetchBlogs(
                                  tag: _selectedTag == "All"
                                      ? null
                                      : _selectedTag,
                                );
                          },
                        );
                      }
                    }
                    return const SomethingWentWrong();
                  }
                  if (state is FetchBlogsSuccess) {
                    if (state.blogModel.isEmpty) {
                      return const NoDataFound();
                    }
                    return ListView.separated(
                      controller: _pageScrollController,
                      physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      itemCount: state.blogModel.length +
                          (state.isLoadingMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        if (index == state.blogModel.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: UiUtils.progress(
                                normalProgressColor:
                                    context.color.territoryColor,
                              ),
                            ),
                          );
                        }
                        final blog = state.blogModel[index];
                        return buildBlogCard(context, blog);
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsFilterBar(BuildContext context) {
    if (_isLoadingTags && _tags.isEmpty) {
      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, __) => CustomShimmer(
            width: 70,
            height: 32,
            borderRadius: 20,
          ),
        ),
      );
    }

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        border: Border(
          bottom: BorderSide(
            color: context.color.borderColor.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tag = _tags[index];
          final isSelected = _selectedTag == tag;

          return InkWell(
            onTap: () => _onTagSelected(tag),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? context.color.territoryColor
                    : context.color.backgroundColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? context.color.territoryColor
                      : context.color.borderColor.withValues(alpha: 0.7),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : context.color.textDefaultColor,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildBlogCard(BuildContext context, BlogModel blog) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.pushNamed(
          context,
          Routes.blogDetailsScreenRoute,
          arguments: {
            "model": blog,
          },
        );
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.color.borderColor.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            if (blog.image != null && blog.image!.isNotEmpty)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  width: double.infinity,
                  height: 165,
                  child: UiUtils.getImage(
                    blog.image!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            // Content
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date & Read Time
                  if (blog.createdAt != null) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: context.color.textLightColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          blog.createdAt.toString().formatDate(),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.color.textLightColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],

                  // Title
                  Text(
                    (blog.title ?? "").firstUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: context.color.textDefaultColor,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Description snippet
                  if (blog.description != null &&
                      blog.description!.isNotEmpty) ...[
                    Text(
                      stripHtmlTags(blog.description!).trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.color.textLightColor,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Read More link
                  Row(
                    children: [
                      Text(
                        "Read Article",
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: context.color.territoryColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: context.color.territoryColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String stripHtmlTags(String htmlString) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '');
  }

  Widget buildBlogsShimmer() {
    return ListView.separated(
      itemCount: 4,
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.color.borderColor.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomShimmer(
                width: double.infinity,
                height: 160,
                borderRadius: 16,
              ),
              Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomShimmer(width: 90, height: 12, borderRadius: 4),
                    const SizedBox(height: 8),
                    CustomShimmer(
                        width: double.infinity, height: 16, borderRadius: 4),
                    const SizedBox(height: 6),
                    CustomShimmer(width: 200, height: 14, borderRadius: 4),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
