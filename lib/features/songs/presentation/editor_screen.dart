import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme.dart';
import '../../common/providers/locale_provider.dart';
import '../data/song_repository.dart';

import '../../songs/domain/song_model.dart'; // Add import

class EditorScreen extends ConsumerStatefulWidget {
  final Song? song; // Optional song for editing
  const EditorScreen({super.key, this.song});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _contentController = TextEditingController();
  final _keyController = TextEditingController();
  final _strummingController = TextEditingController();

  PlatformFile? _selectedAudio;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.song != null) {
      _titleController.text = widget.song!.title;
      _artistController.text = widget.song!.artist;
      _contentController.text = widget.song!.content;
      _keyController.text = widget.song!.key;
      if (widget.song!.strummingPattern != null) {
        _strummingController.text =
            widget.song!.strummingPattern!['pattern'] ?? '';
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _contentController.dispose();
    _keyController.dispose();
    _strummingController.dispose();
    super.dispose();
  }

  // ... existing _pickAudio ...

  Future<void> _pickAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav'],
      );

      if (result != null) {
        setState(() {
          _selectedAudio = result.files.first;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _saveSong() async {
    if (!_formKey.currentState!.validate()) return;
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Content cannot be empty')));
      return;
    }

    setState(() => _isUploading = true);

    try {
      if (widget.song != null) {
        // Update existing
        await ref
            .read(songRepositoryProvider)
            .updateSong(
              songId: widget.song!.id,
              title: _titleController.text,
              artist: _artistController.text,
              content: _contentController.text,
              key: _keyController.text,
              strummingPattern: _strummingController.text,
              audioFile: _selectedAudio,
              currentAudioUrl: widget.song!.audioUrl,
            );
        // Refresh detail view if we are coming from it?
        // Actually global refresh is safer but we might need to invalidate specific provider later.
      } else {
        // Create new
        await ref
            .read(songRepositoryProvider)
            .uploadSong(
              title: _titleController.text,
              artist: _artistController.text,
              content: _contentController.text,
              key: _keyController.text,
              strummingPattern: _strummingController.text,
              audioFile: _selectedAudio,
            );
      }

      // Refresh list
      ref.refresh(songsProvider);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('save', ref) + '!')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _insertText(String text) {
    final start = _contentController.selection.baseOffset;
    final end = _contentController.selection.extentOffset;

    if (start < 0) {
      // No selection, append
      _contentController.text += text;
      return;
    }

    final currentText = _contentController.text;
    final newText = currentText.replaceRange(start, end, text);
    _contentController.value = _contentController.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.song == null
              ? context.tr('add_song', ref)
              : context.tr('edit_song', ref),
        ),
        actions: [
          IconButton(
            icon: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            onPressed: _isUploading ? null : _saveSong,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Meta Data Row
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              labelText: context.tr('title', ref),
                              hintText: context.tr('enter_title', ref),
                            ),
                            validator: (v) =>
                                v?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _artistController,
                            decoration: InputDecoration(
                              labelText: context.tr('artist', ref),
                              hintText: context.tr('enter_artist', ref),
                            ),
                            validator: (v) =>
                                v?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _keyController,
                            decoration: InputDecoration(
                              labelText: context.tr('key', ref),
                              hintText: context.tr('enter_key', ref),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _strummingController,
                      decoration: InputDecoration(
                        labelText: context.tr('strumming', ref),
                        hintText: context.tr('strumming_hint', ref),
                        prefixIcon: const Icon(Icons.waves, size: 20),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Audio Picker
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.audio_file_rounded,
                            color: _selectedAudio != null
                                ? AppTheme.secondary
                                : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedAudio?.name ??
                                  context.tr('pick_audio', ref),
                              style: TextStyle(
                                color: _selectedAudio != null
                                    ? Colors.white
                                    : Colors.white54,
                                fontStyle: _selectedAudio != null
                                    ? FontStyle.normal
                                    : FontStyle.italic,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: _pickAudio,
                            child: Text(context.tr('pick_audio', ref)),
                          ),
                          if (_selectedAudio != null)
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: AppTheme.error,
                              ),
                              onPressed: () =>
                                  setState(() => _selectedAudio = null),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Chord Toolbar
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ToolbarButton(
                          label: '[ ]',
                          onTap: () => _insertText('[]'),
                        ),
                        for (final chord in const [
                          'Am',
                          'A',
                          'D',
                          'Dm',
                          'E',
                          'Em',
                          'C',
                          'G',
                          'F',
                          'Cm',
                          'Gm',
                          'Fm',
                          'B',
                          'Bm',
                        ])
                          _ToolbarButton(
                            label: '[$chord]',
                            onTap: () => _insertText('[$chord]'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Main Content Editor
                    TextFormField(
                      controller: _contentController,
                      maxLines: null, // Grows
                      minLines: 15,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: context.tr('lyrics_hint', ref),
                        alignLabelWithHint: true,
                        labelText: context.tr('lyrics_chords', ref),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _ToolbarButton({required this.label, required this.onTap});

  @override
  State<_ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<_ToolbarButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: AppTheme.animFast,
        curve: AppTheme.animCurve,
        transform: Matrix4.identity()..scale(_isPressed ? 0.92 : 1.0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _isPressed
              ? AppTheme.primary.withOpacity(0.2)
              : AppTheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(
            color: AppTheme.primary.withOpacity(_isPressed ? 0.5 : 0.3),
          ),
        ),
        child: Text(
          widget.label,
          style: const TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
