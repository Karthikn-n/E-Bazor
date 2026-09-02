import 'package:Ebozor/data/model/blog_model.dart';
import 'package:Ebozor/data/repositories/blogs_repository.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/responsiveSize.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

class BlogDetails extends StatefulWidget {
  final BlogModel blog;

  const BlogDetails({super.key, required this.blog});

  static Route route(RouteSettings settings) {
    Map? arguments = settings.arguments as Map?;
    return BlurredRouter(
      builder: (context) {
        return BlogDetails(
          blog: arguments?['model'],
        );
      },
    );
  }

  @override
  State<BlogDetails> createState() => _BlogDetailsState();
}

class _BlogDetailsState extends State<BlogDetails> {
  final BlogsRepository _blogsRepository = BlogsRepository();
  List<String> _tags = [];
  bool _isLoadingTags = true;

  @override
  void initState() {
    super.initState();
    _loadBlogTags();
  }

  Future<void> _loadBlogTags() async {
    if (widget.blog.tags != null && widget.blog.tags!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _tags = List<String>.from(widget.blog.tags!);
          _isLoadingTags = false;
        });
      }
      return;
    }

    try {
      final fetchedTags = await _blogsRepository.fetchBlogTags(
        blogId: widget.blog.id,
      );
      if (mounted) {
        setState(() {
          _tags = fetchedTags;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingTags = false);
    }
  }

  String stripHtmlTags(String htmlString) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.primaryColor,
      appBar: UiUtils.buildAppBar(
        context,
        showBackButton: true,
        title: "blogs".translate(context),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.blog.image != null && widget.blog.image!.isNotEmpty) ...[
                ClipRRect(
                  clipBehavior: Clip.antiAlias,
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: context.screenWidth,
                    height: 190.rh(context),
                    child: UiUtils.getImage(
                      widget.blog.image!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(height: 15.rh(context)),
              ],

              // Date & Tags row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (widget.blog.createdAt != null)
                    Text(
                      widget.blog.createdAt.toString().formatDate(),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.color.textColorDark.withValues(alpha: 0.5),
                      ),
                    ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                (widget.blog.title ?? "").firstUpperCase(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.color.textColorDark,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 14),

              // Tags Chips
              if (_isLoadingTags) ...[
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(height: 16),
              ] else if (_tags.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tags.map((tag) {
                    final cleanTag = tag.startsWith('#') ? tag : '#$tag';
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.color.territoryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: context.color.territoryColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        cleanTag,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.color.territoryColor,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Blog Body Html
              HtmlWidget(widget.blog.description ?? ""),
            ],
          ),
        ),
      ),
    );
  }
}
