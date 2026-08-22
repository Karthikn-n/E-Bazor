import 'package:Ebozor/data/model/blog_model.dart';
import 'package:Ebozor/data/model/data_output.dart';
import 'package:Ebozor/data/repositories/blogs_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class FetchBlogsState {}

class FetchBlogsInitial extends FetchBlogsState {}

class FetchBlogsInProgress extends FetchBlogsState {}

class FetchBlogsSuccess extends FetchBlogsState {
  final bool isLoadingMore;
  final bool loadingMoreError;
  final List<BlogModel> blogModel;
  final int page;
  final int total;
  final String? activeTag;

  FetchBlogsSuccess({
    required this.isLoadingMore,
    required this.loadingMoreError,
    required this.blogModel,
    required this.page,
    required this.total,
    this.activeTag,
  });

  FetchBlogsSuccess copyWith({
    bool? isLoadingMore,
    bool? loadingMoreError,
    List<BlogModel>? blogModel,
    int? page,
    int? total,
    String? activeTag,
  }) {
    return FetchBlogsSuccess(
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadingMoreError: loadingMoreError ?? this.loadingMoreError,
      blogModel: blogModel ?? this.blogModel,
      page: page ?? this.page,
      total: total ?? this.total,
      activeTag: activeTag ?? this.activeTag,
    );
  }
}

class FetchBlogsFailure extends FetchBlogsState {
  final dynamic errorMessage;

  FetchBlogsFailure(this.errorMessage);
}

class FetchBlogsCubit extends Cubit<FetchBlogsState> {
  FetchBlogsCubit() : super(FetchBlogsInitial());

  final BlogsRepository _blogRepository = BlogsRepository();
  String? _currentTag;

  Future<void> fetchBlogs({String? tag, String? categoryId}) async {
    try {
      _currentTag = tag;
      emit(FetchBlogsInProgress());

      DataOutput<BlogModel> result = await _blogRepository.fetchBlogs(
        page: 1,
        tag: tag,
        categoryId: categoryId,
      );

      emit(
        FetchBlogsSuccess(
          isLoadingMore: false,
          loadingMoreError: false,
          blogModel: result.modelList,
          page: 1,
          total: result.total,
          activeTag: tag,
        ),
      );
    } catch (e) {
      emit(FetchBlogsFailure(e));
    }
  }

  Future<void> fetchBlogsMore({String? categoryId}) async {
    try {
      if (state is FetchBlogsSuccess) {
        if ((state as FetchBlogsSuccess).isLoadingMore) {
          return;
        }

        emit((state as FetchBlogsSuccess).copyWith(isLoadingMore: true));

        DataOutput<BlogModel> result = await _blogRepository.fetchBlogs(
          page: (state as FetchBlogsSuccess).page + 1,
          tag: _currentTag,
          categoryId: categoryId,
        );

        FetchBlogsSuccess blogModelState = (state as FetchBlogsSuccess);
        blogModelState.blogModel.addAll(result.modelList);
        emit(FetchBlogsSuccess(
          isLoadingMore: false,
          loadingMoreError: false,
          blogModel: blogModelState.blogModel,
          page: (state as FetchBlogsSuccess).page + 1,
          total: result.total,
          activeTag: _currentTag,
        ));
      }
    } catch (e) {
      emit((state as FetchBlogsSuccess)
          .copyWith(isLoadingMore: false, loadingMoreError: true));
    }
  }

  bool hasMoreData() {
    if (state is FetchBlogsSuccess) {
      return (state as FetchBlogsSuccess).blogModel.length <
          (state as FetchBlogsSuccess).total;
    }
    return false;
  }
}
