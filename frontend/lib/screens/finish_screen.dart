import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/job_provider.dart';
import 'package:path/path.dart' as p;

class FinishScreen extends StatefulWidget {
  const FinishScreen({super.key});

  @override
  State<FinishScreen> createState() => _FinishScreenState();
}

class _FinishScreenState extends State<FinishScreen> {
  VideoPlayerController? originalVideoController;
  VideoPlayerController? processedVideoController;

  AudioPlayer? originalAudioPlayer;
  AudioPlayer? processedAudioPlayer;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<JobProvider>(context, listen: false);

    // Оригінальний файл
    if (provider.originalFilePath != null) {
      _initPlayer(provider.originalFilePath!, isOriginal: true);
    }

    // Оброблений файл
    if (provider.processedFilePath != null) {
      _initPlayer(provider.processedFilePath!, isOriginal: false);
    }
  }

  Future<void> _initPlayer(String filePath, {required bool isOriginal}) async {
    final ext = p.extension(filePath).toLowerCase();
    if (ext == '.mp4' || ext == '.webm') {
      final controller = VideoPlayerController.file(File(filePath));
      await controller.initialize();
      setState(() {
        if (isOriginal) {
          originalVideoController = controller;
        } else {
          processedVideoController = controller;
        }
      });
    } else if (ext == '.mp3' || ext == '.wav') {
      final player = AudioPlayer();

      await player.setSource(DeviceFileSource(filePath));

      setState(() {
        if (isOriginal) {
          originalAudioPlayer = player;
        } else {
          processedAudioPlayer = player;
        }
      });
    }
  }

  @override
  void dispose() {
    originalVideoController?.dispose();
    processedVideoController?.dispose();
    originalAudioPlayer?.dispose();
    processedAudioPlayer?.dispose();
    super.dispose();
  }

  String formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  Widget _buildPlayer(
    String label,
    VideoPlayerController? video,
    AudioPlayer? audio,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          if (video != null && video.value.isInitialized)
            AspectRatio(
              aspectRatio: video.value.aspectRatio,
              child: VideoPlayer(video),
            )
          else if (audio != null)
            Column(
              children: [
                _AudioSlider(player: audio),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.play_arrow),
                      onPressed: () async {
                        await audio.seek(Duration.zero);
                        await audio.resume();
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.pause),
                      onPressed: () => audio.pause(),
                    ),
                  ],
                ),
              ],
            )
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.center,
          //   children: [
          //     IconButton(
          //       icon: Icon(Icons.play_arrow),
          //       onPressed: () async {
          //         await audio.seek(Duration.zero); // повертаємо на початок
          //         await audio.resume();
          //         // await audio.play(audio.source!);
          //       },
          //     ),
          //     IconButton(
          //       icon: Icon(Icons.pause),
          //       onPressed: () async {
          //         await audio.pause();
          //       },
          //     ),
          //   ],
          // )
          else
            Text('No file to play'),
          SizedBox(height: 8),
          if (video != null && video.value.isInitialized)
            ElevatedButton(
              onPressed: () {
                if (video.value.isPlaying) {
                  video.pause();
                } else {
                  video.play();
                }
                setState(() {});
              },
              child: Text(video.value.isPlaying ? 'Pause' : 'Play'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Finished')),
      body: Row(
        children: [
          _buildPlayer(
            'Original',
            originalVideoController,
            originalAudioPlayer,
          ),
          _buildPlayer(
            'Processed',
            processedVideoController,
            processedAudioPlayer,
          ),
        ],
      ),
    );
  }
}

class _AudioSlider extends StatefulWidget {
  final AudioPlayer player;
  const _AudioSlider({required this.player});

  @override
  State<_AudioSlider> createState() => _AudioSliderState();
}

class _AudioSliderState extends State<_AudioSlider> {
  Duration _position = Duration.zero;
  Duration _duration = Duration(
    seconds: 1,
  ); // фікс для уникнення divide by zero

  @override
  void initState() {
    super.initState();

    widget.player.onPositionChanged.listen((pos) {
      setState(() => _position = pos);
    });

    widget.player.onDurationChanged.listen((dur) {
      setState(() => _duration = dur);
    });
  }

  String format(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(d.inMinutes)}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Slider(
          value: _position.inMilliseconds.toDouble().clamp(
            0,
            _duration.inMilliseconds.toDouble(),
          ),
          max: _duration.inMilliseconds.toDouble(),
          onChanged: null, // без логіки
        ),
        Text("${format(_position)} / ${format(_duration)}"),
      ],
    );
  }
}
