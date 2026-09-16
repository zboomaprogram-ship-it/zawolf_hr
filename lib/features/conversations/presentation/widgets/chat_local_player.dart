import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/chat_media_gateway.dart';

class ChatLocalPlayer extends StatefulWidget {
  const ChatLocalPlayer({
    super.key,
    required this.file,
    required this.gateway,
    this.video = false,
    this.isMine = false,
    this.isVoice = false,
  });
  final ChatDraftFile file;
  final ChatMediaGateway gateway;
  final bool video;
  final bool isMine;
  final bool isVoice;
  @override
  State<ChatLocalPlayer> createState() => _ChatLocalPlayerState();
}

class _ChatLocalPlayerState extends State<ChatLocalPlayer> {
  VideoPlayerController? _video;
  AudioPlayer? _audio;
  String? _url;
  late final Future<void> _ready = _initialize();
  Future<void> _initialize() async {
    final url = await widget.gateway.localMediaUrl(widget.file);
    if (!mounted) {
      await widget.gateway.release(url);
      return;
    }
    _url = url;
    if (widget.video) {
      _video = VideoPlayerController.networkUrl(Uri.parse(url));
      await _video!.initialize();
    } else {
      _audio = AudioPlayer();
      await _audio!.setSource(
        url.startsWith('file:')
            ? DeviceFileSource(Uri.parse(url).toFilePath())
            : UrlSource(url, mimeType: widget.file.mimeType),
      );
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    _audio?.dispose();
    if (_url != null) widget.gateway.release(_url!);
    super.dispose();
  }

  double _speed = 1.0;

  void _cycleSpeed() {
    setState(() {
      if (_speed == 1.0) {
        _speed = 1.5;
      } else if (_speed == 1.5) {
        _speed = 2.0;
      } else {
        _speed = 1.0;
      }
    });
    _audio?.setPlaybackRate(_speed);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _ready,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Text(
          'لا يمكن تشغيل هذا النوع هنا. يمكنك حفظه أو مشاركته.',
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
      if (widget.video && _video != null) {
        return ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: _video!,
          builder:
              (context, value, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio:
                        value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
                    child: VideoPlayer(_video!),
                  ),
                  VideoProgressIndicator(_video!, allowScrubbing: true),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: value.isPlaying ? 'إيقاف مؤقت' : 'تشغيل',
                        onPressed:
                            () =>
                                value.isPlaying
                                    ? _video!.pause()
                                    : _video!.play(),
                        icon: Icon(
                          value.isPlaying ? Icons.pause : Icons.play_arrow,
                        ),
                      ),
                      IconButton(
                        tooltip: 'ملء الشاشة',
                        onPressed: () {
                          _video!.pause();
                          showDialog<void>(
                            context: context,
                            builder:
                                (_) => Dialog.fullscreen(
                                  child: Scaffold(
                                    appBar: AppBar(
                                      title: Text(widget.file.fileName),
                                    ),
                                    body: Center(
                                      child: ChatLocalPlayer(
                                        file: widget.file,
                                        gateway: widget.gateway,
                                        video: true,
                                      ),
                                    ),
                                  ),
                                ),
                          );
                        },
                        icon: const Icon(Icons.fullscreen),
                      ),
                    ],
                  ),
                ],
              ),
        );
      }
      if (_audio == null) return const SizedBox.shrink();

      final darkControls = widget.isMine;
      final primaryColor = darkControls ? const Color(0xFF0F172A) : Colors.white;
      final secondaryColor =
          darkControls ? const Color(0xFF334155) : const Color(0xFFA8B3BD);
      final playBtnBg =
          darkControls ? const Color(0xFF166C8C) : const Color(0xFF45F0FF);
      final playBtnIcon = darkControls ? Colors.white : const Color(0xFF050607);
      final trackActive =
          darkControls ? const Color(0xFF0F172A) : const Color(0xFF45F0FF);
      final trackInactive =
          darkControls
              ? Colors.black.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.2);

      return StreamBuilder<PlayerState>(
        stream: _audio!.onPlayerStateChanged,
        initialData: _audio!.state,
        builder: (context, stateSnap) {
          final isPlaying = stateSnap.data == PlayerState.playing;
          return StreamBuilder<Duration>(
            stream: _audio!.onDurationChanged,
            builder: (context, durSnap) {
              final totalDuration = durSnap.data ?? Duration.zero;
              return StreamBuilder<Duration>(
                stream: _audio!.onPositionChanged,
                builder: (context, posSnap) {
                  final position = posSnap.data ?? Duration.zero;
                  final maxMs =
                      (totalDuration.inMilliseconds > 0
                              ? totalDuration.inMilliseconds
                              : 1)
                          .toDouble();
                  final currentMs = position.inMilliseconds
                      .toDouble()
                      .clamp(0.0, maxMs);
                  final timeLabel =
                      isPlaying || position > Duration.zero
                          ? _formatDuration(position)
                          : (totalDuration > Duration.zero
                              ? _formatDuration(totalDuration)
                              : '0:00');

                  return Container(
                    constraints: const BoxConstraints(minWidth: 200),
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            GestureDetector(
                              onTap:
                                  () =>
                                      isPlaying
                                          ? _audio!.pause()
                                          : _audio!.resume(),
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: playBtnBg,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: playBtnIcon,
                                  size: 24,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color:
                                    darkControls
                                        ? const Color(0xFF45F0FF)
                                        : const Color(0xFF1A2027),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.mic,
                                size: 10,
                                color:
                                    darkControls
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFF45F0FF),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3.0,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 5.5,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 10,
                                  ),
                                  activeTrackColor: trackActive,
                                  inactiveTrackColor: trackInactive,
                                  thumbColor: trackActive,
                                ),
                                child: Slider(
                                  value: currentMs,
                                  max: maxMs,
                                  onChanged:
                                      (v) => _audio!.seek(
                                        Duration(milliseconds: v.round()),
                                      ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      timeLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: secondaryColor,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: _cycleSpeed,
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              darkControls
                                                  ? Colors.black.withValues(
                                                    alpha: 0.1,
                                                  )
                                                  : Colors.white.withValues(
                                                    alpha: 0.15,
                                                  ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          _speed == 1.0
                                              ? '1x'
                                              : _speed == 1.5
                                              ? '1.5x'
                                              : '2x',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: primaryColor,
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
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      );
    },
  );
}
