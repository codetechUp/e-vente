import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/audio_model.dart';
import '../utils/constants/app_colors.dart';

class AudioBroadcastPlayer extends StatefulWidget {
  final List<AudioModel> audios;

  const AudioBroadcastPlayer({super.key, required this.audios});

  @override
  State<AudioBroadcastPlayer> createState() => _AudioBroadcastPlayerState();
}

class _AudioBroadcastPlayerState extends State<AudioBroadcastPlayer> with SingleTickerProviderStateMixin {
  late AudioPlayer _audioPlayer;
  late AnimationController _waveAnimationController;

  AudioModel? _selectedAudio;
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _completeSubscription;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _waveAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    if (widget.audios.isNotEmpty) {
      _selectedAudio = widget.audios.first;
    }

    _initPlayerStreams();
  }

  void _initPlayerStreams() {
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });

    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    _stateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _playerState = state;
          if (state == PlayerState.playing) {
            _waveAnimationController.repeat();
          } else {
            _waveAnimationController.stop();
          }
        });
      }
    });

    _completeSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _playerState = PlayerState.completed;
          _position = Duration.zero;
          _waveAnimationController.stop();
        });
      }
    });
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _stateSubscription?.cancel();
    _completeSubscription?.cancel();
    
    _audioPlayer.dispose();
    _waveAnimationController.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    if (_selectedAudio == null || _selectedAudio!.audioUrl.isEmpty) return;
    
    try {
      if (_playerState == PlayerState.paused) {
        await _audioPlayer.resume();
      } else {
        await _audioPlayer.play(UrlSource(_selectedAudio!.audioUrl));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de lire cet audio : $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _pause() async {
    await _audioPlayer.pause();
  }

  Future<void> _seek(double value) async {
    final position = Duration(milliseconds: value.toInt());
    await _audioPlayer.seek(position);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.audios.isEmpty || _selectedAudio == null) {
      return const SizedBox.shrink();
    }

    final isPlaying = _playerState == PlayerState.playing;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Megaphone icon + Dropdown if multiple audios
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.brandGreen.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: AnimatedBuilder(
                  animation: _waveAnimationController,
                  builder: (context, child) {
                    final scale = isPlaying ? 1.0 + (_waveAnimationController.value * 0.15) : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: const Icon(
                        LucideIcons.megaphone,
                        color: AppColors.brandGreen,
                        size: 20,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: widget.audios.length == 1
                    ? Text(
                        _selectedAudio!.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<AudioModel>(
                          value: _selectedAudio,
                          dropdownColor: const Color(0xFF1E293B),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                          isExpanded: true,
                          selectedItemBuilder: (BuildContext context) {
                            return widget.audios.map<Widget>((AudioModel audio) {
                              return Container(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  audio.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              );
                            }).toList();
                          },
                          items: widget.audios.map((AudioModel audio) {
                            return DropdownMenuItem<AudioModel>(
                              value: audio,
                              child: Text(
                                audio.title,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            );
                          }).toList(),
                          onChanged: (AudioModel? newAudio) async {
                            if (newAudio != null && newAudio != _selectedAudio) {
                              await _audioPlayer.stop();
                              setState(() {
                                _selectedAudio = newAudio;
                                _position = Duration.zero;
                                _duration = Duration.zero;
                              });
                            }
                          },
                        ),
                      ),
              ),
              if (_selectedAudio!.expiresAt != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Direct',
                    style: TextStyle(
                      color: AppColors.brandGreen,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_selectedAudio!.imageUrl != null && _selectedAudio!.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 21 / 9,
                child: Image.network(
                  _selectedAudio!.imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.white.withValues(alpha: 0.05),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.brandGreen,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.white.withValues(alpha: 0.05),
                    child: const Center(
                      child: Icon(
                        LucideIcons.imageOff,
                        color: Colors.white38,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Player controls & progress slider
          Row(
            children: [
              // Play/Pause button
              GestureDetector(
                onTap: isPlaying ? _pause : _play,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.brandGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              
              // Progress Bar
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.brandGreen,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: AppColors.brandGreen,
                    overlayColor: AppColors.brandGreen.withValues(alpha: 0.2),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    min: 0.0,
                    max: _duration.inMilliseconds > 0 
                        ? _duration.inMilliseconds.toDouble() 
                        : 100.0,
                    value: _position.inMilliseconds.toDouble().clamp(
                          0.0,
                          _duration.inMilliseconds > 0 
                              ? _duration.inMilliseconds.toDouble() 
                              : 100.0,
                        ),
                    onChanged: (value) {
                      _seek(value);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Duration text
              Text(
                '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
