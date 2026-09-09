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
  });
  final ChatDraftFile file;
  final ChatMediaGateway gateway;
  final bool video;
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
        return const Center(child: CircularProgressIndicator());
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
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreamBuilder<PlayerState>(
            stream: _audio!.onPlayerStateChanged,
            initialData: _audio!.state,
            builder:
                (_, state) => IconButton(
                  tooltip:
                      state.data == PlayerState.playing
                          ? 'إيقاف مؤقت'
                          : 'تشغيل',
                  icon: Icon(
                    state.data == PlayerState.playing
                        ? Icons.pause_circle
                        : Icons.play_circle,
                  ),
                  onPressed:
                      () =>
                          state.data == PlayerState.playing
                              ? _audio!.pause()
                              : _audio!.resume(),
                ),
          ),
          StreamBuilder<Duration>(
            stream: _audio!.onDurationChanged,
            builder:
                (_, duration) => StreamBuilder<Duration>(
                  stream: _audio!.onPositionChanged,
                  builder: (_, position) {
                    final max =
                        (duration.data?.inMilliseconds ?? 1)
                            .clamp(1, 100000000)
                            .toDouble();
                    return Slider(
                      value: (position.data?.inMilliseconds ?? 0)
                          .toDouble()
                          .clamp(0, max),
                      max: max,
                      onChanged:
                          (v) =>
                              _audio!.seek(Duration(milliseconds: v.round())),
                    );
                  },
                ),
          ),
        ],
      );
    },
  );
}
