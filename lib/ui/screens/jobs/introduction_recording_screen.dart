import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';

enum RecordingType { audio, video }

class IntroductionRecordingScreen extends StatefulWidget {
  final RecordingType type;

  const IntroductionRecordingScreen({
    super.key,
    required this.type,
  });

  static Route route(RecordingType type) {
    return CupertinoPageRoute(
      builder: (context) => IntroductionRecordingScreen(type: type),
    );
  }

  @override
  State<IntroductionRecordingScreen> createState() =>
      _IntroductionRecordingScreenState();
}

class _IntroductionRecordingScreenState
    extends State<IntroductionRecordingScreen> {
  // Audio Recording & Playback
  final AudioRecorder _audioRecorder = AudioRecorder();
  AudioPlayer? _audioPlayer;

  // Video Controller
  VideoPlayerController? _videoPlayerController;

  // States
  bool _isRecording = false;
  bool _isPaused = false;
  bool _hasRecorded = false;
  bool _isPlaying = false;
  bool _isVideoPlaying = false;
  int _recordSeconds = 0;
  int _playProgressSeconds = 0;
  Timer? _timer;
  String? _recordedFilePath;

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Permission Handling
  // ---------------------------------------------------------------------------
  Future<bool> _requestAudioPermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        _showPermissionDialog("Microphone");
      }
      return false;
    } else {
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          "Microphone permission is required to record audio",
          type: MessageType.warning,
        );
      }
      return false;
    }
  }

  Future<bool> _requestVideoPermission() async {
    final micStatus = await Permission.microphone.request();
    final camStatus = await Permission.camera.request();

    if (micStatus.isGranted && camStatus.isGranted) {
      return true;
    } else if (micStatus.isPermanentlyDenied || camStatus.isPermanentlyDenied) {
      if (mounted) {
        _showPermissionDialog("Camera and Microphone");
      }
      return false;
    } else {
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          "Camera and Microphone permissions are required to record video",
          type: MessageType.warning,
        );
      }
      return false;
    }
  }

  void _showPermissionDialog(String feature) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.color.secondaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Permission Required",
          style: TextStyle(
            color: context.color.textDefaultColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "Please grant $feature permission in app settings to record your introduction.",
          style: TextStyle(color: context.color.textDefaultColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.color.territoryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Audio & Video Recording Actions
  // ---------------------------------------------------------------------------
  Future<void> _startRecording() async {
    if (widget.type == RecordingType.video) {
      final hasPerm = await _requestVideoPermission();
      if (!hasPerm) return;

      try {
        final picker = ImagePicker();
        final pickedVideo = await picker.pickVideo(
          source: ImageSource.camera,
          maxDuration: const Duration(minutes: 2),
          preferredCameraDevice: CameraDevice.front,
        );

        if (pickedVideo != null && pickedVideo.path.isNotEmpty) {
          _recordedFilePath = pickedVideo.path;
          _videoPlayerController?.dispose();
          _videoPlayerController =
              VideoPlayerController.file(File(_recordedFilePath!));

          await _videoPlayerController!.initialize();
          _videoPlayerController!.addListener(() {
            if (mounted) {
              setState(() {
                _isVideoPlaying = _videoPlayerController!.value.isPlaying;
              });
            }
          });

          setState(() {
            _hasRecorded = true;
            _recordSeconds =
                _videoPlayerController!.value.duration.inSeconds;
          });
        }
      } catch (e) {
        debugPrint("Video recording error: $e");
        if (mounted) {
          HelperUtils.showSnackBarMessage(
            context,
            "Could not record video: $e",
            type: MessageType.error,
          );
        }
      }
      return;
    }

    // Audio Recording
    final hasPerm = await _requestAudioPermission();
    if (!hasPerm) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath =
          "${dir.path}/audio_intro_${DateTime.now().millisecondsSinceEpoch}.m4a";

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      setState(() {
        _isRecording = true;
        _isPaused = false;
        _hasRecorded = false;
        _recordSeconds = 0;
        _recordedFilePath = filePath;
      });

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!_isPaused) {
          setState(() {
            _recordSeconds++;
          });
        }
      });
    } catch (e) {
      debugPrint("Audio recording error: $e");
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          "Failed to start recording: $e",
          type: MessageType.error,
        );
      }
    }
  }

  Future<void> _pauseRecording() async {
    try {
      await _audioRecorder.pause();
      setState(() {
        _isPaused = true;
      });
    } catch (e) {
      debugPrint("Pause error: $e");
    }
  }

  Future<void> _resumeRecording() async {
    try {
      await _audioRecorder.resume();
      setState(() {
        _isPaused = false;
      });
    } catch (e) {
      debugPrint("Resume error: $e");
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        _recordedFilePath = path;
      }
      setState(() {
        _isRecording = false;
        _isPaused = false;
        _hasRecorded = true;
      });
      _initAudioPlayer();
    } catch (e) {
      debugPrint("Stop recording error: $e");
    }
  }

  void _initAudioPlayer() {
    if (_recordedFilePath == null) return;
    _audioPlayer?.dispose();
    _audioPlayer = AudioPlayer();

    _audioPlayer!.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _playProgressSeconds = 0;
        });
      }
    });

    _audioPlayer!.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() {
          _playProgressSeconds = pos.inSeconds;
        });
      }
    });
  }

  Future<void> _toggleAudioPlayback() async {
    if (_recordedFilePath == null) return;
    if (_audioPlayer == null) {
      _initAudioPlayer();
    }

    if (_isPlaying) {
      await _audioPlayer!.pause();
      setState(() => _isPlaying = false);
    } else {
      await _audioPlayer!.play(DeviceFileSource(_recordedFilePath!));
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _toggleVideoPlayback() async {
    if (_videoPlayerController == null ||
        !_videoPlayerController!.value.isInitialized) {
      return;
    }

    if (_videoPlayerController!.value.isPlaying) {
      await _videoPlayerController!.pause();
    } else {
      await _videoPlayerController!.play();
    }
    setState(() {});
  }

  void _resetRecording() {
    _timer?.cancel();
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _audioPlayer = null;
    _videoPlayerController?.pause();
    _videoPlayerController?.dispose();
    _videoPlayerController = null;

    if (_recordedFilePath != null) {
      try {
        final f = File(_recordedFilePath!);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }

    setState(() {
      _isRecording = false;
      _isPaused = false;
      _hasRecorded = false;
      _isPlaying = false;
      _isVideoPlaying = false;
      _recordSeconds = 0;
      _playProgressSeconds = 0;
      _recordedFilePath = null;
    });
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVideo = widget.type == RecordingType.video;

    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: UiUtils.buildAppBar(
        context,
        title: "My Job Profile",
        showBackButton: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Introductions
                    Text(
                      "Introductions",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark
                          ? context.color.borderColor.withValues(alpha: 0.3)
                          : const Color(0xFFE5E7EB),
                    ),
                    const SizedBox(height: 18),

                    // Instructions Title
                    Text(
                      "Please keep in mind the following instructions:",
                      style: TextStyle(
                        fontSize: 14.5,
                        color: isDark
                            ? context.color.textDefaultColor
                            : const Color(0xFF374151),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Instructions List (Matching Mockups)
                    if (isVideo) ...[
                      _buildInstructionItem(
                          1, "Please be in a noise free environment."),
                      const SizedBox(height: 8),
                      _buildInstructionItem(
                          2, "Appear presentable and professional."),
                      const SizedBox(height: 8),
                      _buildInstructionItem(
                          3, "Look into the camera when talking."),
                      const SizedBox(height: 8),
                      _buildInstructionItem(
                          4, "Speak clearly and make sure you can be heard."),
                    ] else ...[
                      _buildInstructionItem(
                          1, "Please be in a noise free environment."),
                      const SizedBox(height: 8),
                      _buildInstructionItem(
                          2, "Speak clearly and make sure you can be heard."),
                    ],

                    const SizedBox(height: 28),

                    // Recording / Preview Container
                    Container(
                      width: double.infinity,
                      height: isVideo && _hasRecorded ? 300 : 260,
                      decoration: BoxDecoration(
                        color: isDark
                            ? context.color.secondaryColor
                            : const Color(0xFFF1F3F5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isRecording
                              ? const Color(0xFFEF4444)
                              : (isDark
                                  ? context.color.borderColor
                                      .withValues(alpha: 0.4)
                                  : const Color(0xFFE5E7EB)),
                          width: _isRecording ? 2 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 1. Initial Empty State
                            if (!_isRecording && !_hasRecorded) ...[
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isVideo
                                        ? Icons.videocam_outlined
                                        : Icons.mic_none_rounded,
                                    size: 48,
                                    color: context.color.textLightColor
                                        .withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    isVideo
                                        ? "Tap Record to start video introduction"
                                        : "Tap Record to start voice introduction",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: context.color.textLightColor,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildRecordButton(),
                                ],
                              ),
                            ]
                            // 2. Audio Live Recording State
                            else if (_isRecording) ...[
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444)
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFEF4444),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatDuration(_recordSeconds),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFEF4444),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      // Pause / Resume button
                                      IconButton.filled(
                                        iconSize: 26,
                                        style: IconButton.styleFrom(
                                          backgroundColor: isDark
                                              ? context.color.backgroundColor
                                              : Colors.white,
                                          foregroundColor:
                                              context.color.textDefaultColor,
                                          padding: const EdgeInsets.all(12),
                                        ),
                                        icon: Icon(_isPaused
                                            ? Icons.play_arrow_rounded
                                            : Icons.pause_rounded),
                                        onPressed: _isPaused
                                            ? _resumeRecording
                                            : _pauseRecording,
                                      ),
                                      const SizedBox(width: 20),
                                      // Stop button
                                      IconButton.filled(
                                        iconSize: 26,
                                        style: IconButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFFEF4444),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.all(12),
                                        ),
                                        icon: const Icon(Icons.stop_rounded),
                                        onPressed: _stopRecording,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ]
                            // 3. Recorded Preview State (Audio or Video)
                            else if (_hasRecorded) ...[
                              if (isVideo &&
                                  _videoPlayerController != null &&
                                  _videoPlayerController!.value.isInitialized)
                                ...[
                                  // Video Player View
                                  SizedBox.expand(
                                    child: FittedBox(
                                      fit: BoxFit.cover,
                                      child: SizedBox(
                                        width: _videoPlayerController!
                                            .value.size.width,
                                        height: _videoPlayerController!
                                            .value.size.height,
                                        child: VideoPlayer(
                                            _videoPlayerController!),
                                      ),
                                    ),
                                  ),
                                  // Play / Pause Overlay
                                  Container(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          IconButton.filled(
                                            iconSize: 36,
                                            style: IconButton.styleFrom(
                                              backgroundColor: Colors.white
                                                  .withValues(alpha: 0.8),
                                              foregroundColor:
                                                  const Color(0xFF2563EB),
                                              padding: const EdgeInsets.all(14),
                                            ),
                                            icon: Icon(_isVideoPlaying
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded),
                                            onPressed: _toggleVideoPlayback,
                                          ),
                                          const SizedBox(height: 12),
                                          TextButton.icon(
                                            style: TextButton.styleFrom(
                                              backgroundColor: Colors.black
                                                  .withValues(alpha: 0.6),
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 6),
                                            ),
                                            onPressed: _resetRecording,
                                            icon: const Icon(
                                                Icons.replay_rounded,
                                                size: 16),
                                            label: const Text(
                                              "Retry Video",
                                              style: TextStyle(fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ]
                              else ...[
                                // Audio Player Preview
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: context.color.territoryColor
                                            .withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: Icon(
                                          _isPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          size: 38,
                                          color: context.color.territoryColor,
                                        ),
                                        onPressed: _toggleAudioPlayback,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      "Audio Introduction Recorded (${_formatDuration(_playProgressSeconds > 0 ? _playProgressSeconds : _recordSeconds)})",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: context.color.textDefaultColor,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    TextButton.icon(
                                      onPressed: _resetRecording,
                                      icon: const Icon(Icons.replay_rounded,
                                          size: 18),
                                      label: const Text("Retry Recording"),
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            const Color(0xFFEF4444),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Actions: Cancel & Save (Matching Mockup)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: context.color.secondaryColor,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? context.color.borderColor.withValues(alpha: 0.3)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Cancel Button
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isDark
                                ? context.color.borderColor
                                : const Color(0xFFD1D5DB),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          foregroundColor: context.color.textDefaultColor,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Save Button
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _hasRecorded
                              ? context.color.territoryColor
                              : (isDark
                                  ? const Color(0xFF374151)
                                  : const Color(0xFFE5E7EB)),
                          foregroundColor: _hasRecorded
                              ? Colors.white
                              : (isDark
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFF9CA3AF)),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _hasRecorded
                            ? () {
                                Navigator.pop(context, {
                                  'type': widget.type == RecordingType.video
                                      ? 'video'
                                      : 'audio',
                                  'filePath': _recordedFilePath,
                                  'duration': _recordSeconds,
                                });
                              }
                            : null,
                        child: const Text(
                          "Save",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem(int index, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$index. ",
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            color: isDark
                ? context.color.textDefaultColor
                : const Color(0xFF374151),
            height: 1.4,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14.5,
              color: isDark
                  ? context.color.textDefaultColor
                  : const Color(0xFF374151),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordButton() {
    return InkWell(
      onTap: _startRecording,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE50914), // Red button matching mockup
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE50914).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Text(
          "Record",
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
