import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../config/theme.dart';

class AudioPlayerBar extends StatefulWidget {
  final String audioUrl;

  const AudioPlayerBar({super.key, required this.audioUrl});

  @override
  State<AudioPlayerBar> createState() => _AudioPlayerBarState();
}

class _AudioPlayerBarState extends State<AudioPlayerBar> {
  late final AudioPlayer _player;
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      await _player.setUrl(widget.audioUrl);
      if (mounted) setState(() => _isInit = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading audio: $e')));
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: AppTheme.surface,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Slider Row
          StreamBuilder<Duration>(
            stream: _player.positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final duration = _player.duration ?? Duration.zero;

              return Row(
                children: [
                  Text(
                    _formatDuration(position),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14,
                        ),
                        trackHeight: 2,
                        activeTrackColor: AppTheme.primary,
                        inactiveTrackColor: Colors.white10,
                        thumbColor: AppTheme.primary,
                      ),
                      child: Slider(
                        value: position.inSeconds.toDouble().clamp(
                          0,
                          duration.inSeconds.toDouble(),
                        ),
                        max: duration.inSeconds.toDouble(),
                        onChanged: (value) {
                          _player.seek(Duration(seconds: value.toInt()));
                        },
                      ),
                    ),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              );
            },
          ),

          // Controls Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10),
                onPressed: () {
                  final pos = _player.position - const Duration(seconds: 10);
                  _player.seek(pos < Duration.zero ? Duration.zero : pos);
                },
              ),
              const SizedBox(width: 16),
              StreamBuilder<PlayerState>(
                stream: _player.playerStateStream,
                builder: (context, snapshot) {
                  final state = snapshot.data;
                  final playing = state?.playing ?? false;
                  final processingState = state?.processingState;

                  if (processingState == ProcessingState.loading ||
                      processingState == ProcessingState.buffering) {
                    return const SizedBox(
                      width: 48,
                      height: 48,
                      child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      iconSize: 32,
                      color: AppTheme.onPrimary,
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                      onPressed: () {
                        if (playing) {
                          _player.pause();
                        } else {
                          _player.play();
                        }
                      },
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.forward_10),
                onPressed: () {
                  final pos = _player.position + const Duration(seconds: 10);
                  final dur = _player.duration;
                  if (dur != null && pos > dur) {
                    _player.seek(dur);
                  } else {
                    _player.seek(pos);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
