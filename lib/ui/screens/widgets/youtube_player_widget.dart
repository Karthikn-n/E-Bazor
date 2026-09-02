import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class YoutubePlayerWidget extends StatefulWidget {
  final VoidCallback onLandscape;
  final VoidCallback onPortrate;
  final String videoUrl;

  const YoutubePlayerWidget({
    super.key,
    required this.videoUrl,
    required this.onLandscape,
    required this.onPortrate,
  });

  @override
  State<YoutubePlayerWidget> createState() => _YoutubePlayerWidgetState();
}

class _YoutubePlayerWidgetState extends State<YoutubePlayerWidget> {
  YoutubePlayerController? _controller;

  String? getVideoId() {
    final fromController =
        YoutubePlayerController.convertUrlToId(widget.videoUrl);
    if (fromController != null && fromController.isNotEmpty) {
      return fromController;
    }
    final regExp = RegExp(
      r'(?:https?:\/\/)?(?:www\.|m\.)?(?:youtube\.com\/(?:watch\?v=|embed\/|shorts\/|v\/)|youtu\.be\/)([\w-]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(widget.videoUrl);
    return match?.group(1);
  }

  @override
  void initState() {
    super.initState();
    final videoId = getVideoId();
    if (videoId != null && videoId.isNotEmpty) {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: false,
        params: const YoutubePlayerParams(
          showFullscreenButton: true,
          showControls: true,
          mute: false,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) return const SizedBox.shrink();

    return SizedBox(
      child: YoutubePlayer(
        controller: _controller!,
        aspectRatio: 16 / 9,
      ),
    );
  }
}
