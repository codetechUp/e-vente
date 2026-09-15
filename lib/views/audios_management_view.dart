import 'dart:typed_data';
import 'dart:io' as io;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/audio_model.dart';
import '../services/audios_service.dart';
import '../services/storage_service.dart';
import '../utils/constants/app_colors.dart';
import '../widgets/app_button.dart';

class AudiosManagementView extends StatefulWidget {
  const AudiosManagementView({super.key});

  @override
  State<AudiosManagementView> createState() => _AudiosManagementViewState();
}

class _AudiosManagementViewState extends State<AudiosManagementView> {
  final _audiosService = AudiosService();
  final _storageService = StorageService();
  late Future<List<AudioModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AudioModel>> _load() => _audiosService.getAll();

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _deleteAudio(AudioModel audio) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Voulez-vous vraiment supprimer l\'audio "${audio.title}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: AppColors.mutedText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _audiosService.deleteById(audio.id!);
        _refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audio supprimé avec succès.'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de la suppression : $e'), backgroundColor: AppColors.danger),
          );
        }
      }
    }
  }

  void _openCreateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CreateAudioDialog(
        storageService: _storageService,
        audiosService: _audiosService,
        onSuccess: () {
          _refresh();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Audios de diffusion',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 28),
            onPressed: _openCreateDialog,
          ),
        ],
      ),
      body: FutureBuilder<List<AudioModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = snapshot.data;
          if (list == null || list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.volumeX, size: 64, color: AppColors.mutedText),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucun audio de diffusion.',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ajoutez des annonces audio pour les clients.',
                    style: TextStyle(color: AppColors.mutedText),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _openCreateDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter une annonce'),
                  ),
                ],
              ),
            );
          }

          final now = DateTime.now();

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final audio = list[index];
              final isExpired = audio.expiresAt != null && audio.expiresAt!.isBefore(now);
              final format = DateFormat('dd/MM/yyyy HH:mm');

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: (isExpired ? Colors.grey : AppColors.brandGreen).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          image: audio.imageUrl != null && audio.imageUrl!.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(audio.imageUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: audio.imageUrl == null || audio.imageUrl!.isEmpty
                            ? Icon(
                                isExpired ? LucideIcons.volumeX : LucideIcons.volume2,
                                color: isExpired ? Colors.grey : AppColors.brandGreenDark,
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              audio.title,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              audio.expiresAt != null 
                                  ? 'Expire le : ${format.format(audio.expiresAt!.toLocal())}'
                                  : 'Pas de date d\'expiration',
                              style: TextStyle(
                                color: isExpired ? AppColors.danger : AppColors.mutedText,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.trash2, color: AppColors.danger),
                        onPressed: () => _deleteAudio(audio),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateDialog,
        backgroundColor: AppColors.brandGreen,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CreateAudioDialog extends StatefulWidget {
  final StorageService storageService;
  final AudiosService audiosService;
  final VoidCallback onSuccess;

  const _CreateAudioDialog({
    required this.storageService,
    required this.audiosService,
    required this.onSuccess,
  });

  @override
  State<_CreateAudioDialog> createState() => _CreateAudioDialogState();
}

class _CreateAudioDialogState extends State<_CreateAudioDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  
  String? _pickedFileName;
  Uint8List? _pickedFileBytes;
  DateTime? _selectedDateTime;
  XFile? _pickedImage;
  bool _uploading = false;

  int _selectedTab = 0; // 0 for File Picker, 1 for Voice Recording

  // Recording variables
  final _recorder = AudioRecorder();
  final _previewPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _hasRecorded = false;
  bool _isPlayingPreview = false;
  String? _recordedPath;
  int _recordDurationSeconds = 0;
  Timer? _recordTimer;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  Duration _previewPosition = Duration.zero;
  Duration _previewDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _playerStateSubscription = _previewPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlayingPreview = state == PlayerState.playing;
        });
      }
    });
    _previewPlayer.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() {
          _previewPosition = pos;
        });
      }
    });
    _previewPlayer.onDurationChanged.listen((dur) {
      if (mounted) {
        setState(() {
          _previewDuration = dur;
        });
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _recorder.dispose();
    _playerStateSubscription?.cancel();
    _previewPlayer.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) return;
      setState(() {
        _pickedImage = file;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de sélection de l\'image : $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _pickedFileName = file.name;
          _pickedFileBytes = file.bytes;
          if (_titleController.text.isEmpty) {
            final idx = file.name.lastIndexOf('.');
            _titleController.text = idx != -1 ? file.name.substring(0, idx) : file.name;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de sélection : $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        String path = '';
        if (!kIsWeb) {
          final tempDir = await getTemporaryDirectory();
          path = '${tempDir.path}/recorded_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        }

        if (_isPlayingPreview) {
          await _previewPlayer.stop();
        }

        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            sampleRate: 44100,
            bitRate: 128000,
          ),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _hasRecorded = false;
          _recordedPath = null;
          _recordDurationSeconds = 0;
        });

        _recordTimer?.cancel();
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _recordDurationSeconds++;
            });
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission microphone refusée.'), backgroundColor: AppColors.danger),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur d\'enregistrement : $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordTimer?.cancel();
      final path = await _recorder.stop();
      if (path != null) {
        Uint8List bytes;
        if (kIsWeb) {
          final response = await http.get(Uri.parse(path));
          bytes = response.bodyBytes;
        } else {
          bytes = await io.File(path).readAsBytes();
        }

        setState(() {
          _isRecording = false;
          _hasRecorded = true;
          _recordedPath = path;
          _pickedFileBytes = bytes;
          _pickedFileName = 'vocal_${DateTime.now().millisecondsSinceEpoch}.m4a';
          if (_titleController.text.isEmpty) {
            _titleController.text = 'Annonce vocale ${DateFormat('HH:mm').format(DateTime.now())}';
          }
        });
      } else {
        setState(() {
          _isRecording = false;
        });
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de fin d\'enregistrement : $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _togglePreview() async {
    if (_recordedPath == null) return;
    try {
      if (_isPlayingPreview) {
        await _previewPlayer.pause();
      } else {
        Source source;
        if (kIsWeb) {
          source = UrlSource(_recordedPath!);
        } else {
          source = DeviceFileSource(_recordedPath!);
        }
        await _previewPlayer.play(source);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de lecture de l\'aperçu : $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  void _resetRecording() {
    setState(() {
      _isRecording = false;
      _hasRecorded = false;
      _recordedPath = null;
      _pickedFileBytes = null;
      _pickedFileName = null;
      _recordDurationSeconds = 0;
      _previewPosition = Duration.zero;
      _previewDuration = Duration.zero;
    });
    _previewPlayer.stop();
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 12, minute: 0),
      );

      if (time != null) {
        setState(() {
          _selectedDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedFileBytes == null || _pickedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner ou enregistrer un fichier audio.'), backgroundColor: AppColors.danger),
      );
      return;
    }

    setState(() => _uploading = true);

    try {
      final audioUrl = await widget.storageService.uploadAudioFile(
        fileName: _pickedFileName!,
        bytes: _pickedFileBytes!,
      );

      String? imageUrl;
      if (_pickedImage != null) {
        imageUrl = await widget.storageService.uploadProductImage(file: _pickedImage!);
      }

      final audioModel = AudioModel(
        title: _titleController.text.trim(),
        audioUrl: audioUrl,
        expiresAt: _selectedDateTime,
        imageUrl: imageUrl,
      );

      await widget.audiosService.create(audioModel);
      
      widget.onSuccess();
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio diffusé avec succès !'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de publication : $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd/MM/yyyy HH:mm');

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(
        children: [
          Icon(LucideIcons.volume2, color: AppColors.brandGreen),
          SizedBox(width: 10),
          Text(
            'Nouvelle diffusion',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
        ],
      ),
      content: _uploading
          ? SizedBox(
              height: 200,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 24),
                  Text(
                    'Envoi de l\'audio en cours...',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.mutedText),
                  ),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tab Selector
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (!_isRecording) {
                                  setState(() {
                                    _selectedTab = 0;
                                    _resetRecording();
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: _selectedTab == 0
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                                      : null,
                                ),
                                child: Text(
                                  'Fichier audio',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _selectedTab == 0 ? AppColors.brandGreenDark : AppColors.mutedText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedTab = 1;
                                  _pickedFileBytes = null;
                                  _pickedFileName = null;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: _selectedTab == 1
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                                      : null,
                                ),
                                child: Text(
                                  'Enregistrer',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _selectedTab == 1 ? AppColors.brandGreenDark : AppColors.mutedText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tab Body
                    if (_selectedTab == 0) ...[
                      // Audio Picker Box
                      InkWell(
                        onTap: _pickAudioFile,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _pickedFileName != null ? AppColors.brandGreen : AppColors.border,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                _pickedFileName != null ? LucideIcons.checkCircle : LucideIcons.music,
                                size: 40,
                                color: _pickedFileName != null ? AppColors.brandGreen : AppColors.mutedText,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _pickedFileName ?? 'Sélectionner un fichier audio (MP3, M4A, WAV)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _pickedFileName != null ? AppColors.text : AppColors.mutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // Recording UI
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _hasRecorded ? AppColors.brandGreen : AppColors.border,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            if (_isRecording) ...[
                              // Pulsing recording indicator and chronometer
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.8, end: 1.2),
                                duration: const Duration(milliseconds: 600),
                                builder: (context, scale, child) {
                                  return Transform.scale(
                                    scale: scale,
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: const BoxDecoration(
                                        color: AppColors.danger,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _formatDuration(_recordDurationSeconds),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Enregistrement en cours...',
                                style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                              ),
                              const SizedBox(height: 16),
                              // Stop recording button
                              GestureDetector(
                                onTap: _stopRecording,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: const BoxDecoration(
                                    color: AppColors.danger,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.stop, color: Colors.white, size: 28),
                                ),
                              ),
                            ] else if (!_hasRecorded) ...[
                              // Circular mic button to start recording
                              GestureDetector(
                                onTap: _startRecording,
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: AppColors.brandGreen.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(LucideIcons.mic, color: AppColors.brandGreen, size: 36),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Appuyez pour enregistrer un vocal',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.mutedText),
                              ),
                            ] else ...[
                              // Preview section (play, pause, slider, reset)
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      _isPlayingPreview ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                      color: AppColors.brandGreen,
                                      size: 36,
                                    ),
                                    onPressed: _togglePreview,
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SliderTheme(
                                          data: SliderTheme.of(context).copyWith(
                                            trackHeight: 3,
                                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                          ),
                                          child: Slider(
                                            min: 0,
                                            max: _previewDuration.inMilliseconds.toDouble() > 0
                                                ? _previewDuration.inMilliseconds.toDouble()
                                                : 1.0,
                                            value: _previewPosition.inMilliseconds.toDouble().clamp(
                                              0.0,
                                              _previewDuration.inMilliseconds.toDouble() > 0
                                                  ? _previewDuration.inMilliseconds.toDouble()
                                                  : 1.0,
                                            ),
                                            activeColor: AppColors.brandGreen,
                                            inactiveColor: Colors.grey.shade300,
                                            onChanged: (val) {
                                              _previewPlayer.seek(Duration(milliseconds: val.toInt()));
                                            },
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '${_previewPosition.inMinutes}:${(_previewPosition.inSeconds % 60).toString().padLeft(2, '0')}',
                                                style: const TextStyle(fontSize: 10, color: AppColors.mutedText),
                                              ),
                                              Text(
                                                '${_previewDuration.inMinutes}:${(_previewDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                                                style: const TextStyle(fontSize: 10, color: AppColors.mutedText),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              OutlinedButton.icon(
                                onPressed: _resetRecording,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Recommencer'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                  side: const BorderSide(color: AppColors.danger),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Title
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Titre de l\'annonce',
                        hintText: 'Ex: Promo de la semaine',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                    ),
                    const SizedBox(height: 16),

                    // Promotion Image (Optional)
                    const Text(
                      'Image de promotion (Optionnelle)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mutedText),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickedImage == null ? _pickImage : null,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _pickedImage != null ? AppColors.brandGreen : AppColors.border,
                            width: 1.5,
                          ),
                        ),
                        child: _pickedImage == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(LucideIcons.image, color: AppColors.mutedText, size: 32),
                                  SizedBox(height: 8),
                                  Text(
                                    'Ajouter une image',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.mutedText),
                                  ),
                                ],
                              )
                            : Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: FutureBuilder<Uint8List>(
                                        future: _pickedImage!.readAsBytes(),
                                        builder: (context, snapshot) {
                                          if (snapshot.hasData) {
                                            return Image.memory(
                                              snapshot.data!,
                                              fit: BoxFit.cover,
                                            );
                                          }
                                          return const Center(child: CircularProgressIndicator());
                                        },
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _pickedImage = null;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Expiration Date Time Selector
                    InkWell(
                      onTap: _selectDateTime,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.calendar, color: AppColors.mutedText, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Date d\'expiration',
                                    style: TextStyle(fontSize: 10, color: AppColors.mutedText, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _selectedDateTime != null
                                        ? format.format(_selectedDateTime!)
                                        : 'Aucune (Visible indéfiniment)',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.text),
                                  ),
                                ],
                              ),
                            ),
                            if (_selectedDateTime != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _selectedDateTime = null;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      actions: _uploading || _isRecording
          ? []
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler', style: TextStyle(color: AppColors.mutedText, fontWeight: FontWeight.bold)),
              ),
              AppButton(
                label: 'Diffuser',
                onPressed: _save,
              ),
            ],
    );
  }
}
