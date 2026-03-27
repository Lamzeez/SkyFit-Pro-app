import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class ActivityVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool isInteractivityEnabled;

  const ActivityVideoPlayer({
    super.key, 
    required this.videoUrl,
    this.isInteractivityEnabled = true,
  });

  @override
  State<ActivityVideoPlayer> createState() => _ActivityVideoPlayerState();
}

class _ActivityVideoPlayerState extends State<ActivityVideoPlayer> {
  // Regular Video Player fields
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;

  // YouTube IFrame Player fields
  YoutubePlayerController? _youtubeController;
  bool _isYoutube = false;

  @override
  void initState() {
    super.initState();
    _checkAndInitPlayer();
  }

  void _checkAndInitPlayer() {
    String? videoId = YoutubePlayerController.convertUrlToId(widget.videoUrl);
    if (videoId != null) {
      _isYoutube = true;
      _youtubeController = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          mute: true,
          loop: true,
        ),
      );
    } else {
      _isYoutube = false;
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _videoInitialized = true;
              _videoController!.setLooping(true);
              _videoController!.setVolume(0);
              _videoController!.play();
            });
          }
        });
    }
  }

  @override
  void didUpdateWidget(ActivityVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeCurrentPlayer();
      _checkAndInitPlayer();
    }
  }

  void _disposeCurrentPlayer() {
    _videoController?.dispose();
    _videoController = null;
    _videoInitialized = false;
    
    _youtubeController?.close();
    _youtubeController = null;
    _isYoutube = false;
  }

  @override
  void dispose() {
    _disposeCurrentPlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget player;
    if (_isYoutube && _youtubeController != null) {
      player = YoutubePlayer(
        controller: _youtubeController!,
        aspectRatio: 16 / 9,
      );
    } else if (_videoInitialized && _videoController != null) {
      player = AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            VideoPlayer(_videoController!),
            VideoProgressIndicator(_videoController!, allowScrubbing: true),
            Positioned(
              right: 10,
              bottom: 10,
              child: IconButton(
                icon: Icon(
                  _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _videoController!.value.isPlaying 
                        ? _videoController!.pause() 
                        : _videoController!.play();
                  });
                },
              ),
            ),
          ],
        ),
      );
    } else {
      player = const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return IgnorePointer(
      ignoring: !widget.isInteractivityEnabled,
      child: player,
    );
  }
}
