import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(BandPlayerApp());

class BandPlayerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Band Playlist',
      theme: ThemeData.dark(),
      home: PlaylistScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class PlaylistScreen extends StatefulWidget {
  @override
  _PlaylistScreenState createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  final AudioPlayer _player = AudioPlayer();
  final List<String> _playlist = [];
  int _currentIndex = -1;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _pickAudioFiles() async {
    // Request correct permission based on Android version
    final permission = await _getStoragePermission();

    if (!permission.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Storage permission is required.')),
      );
      return;
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        _playlist.addAll(result.paths.whereType<String>());
      });
    }
  }

  Future<PermissionStatus> _getStoragePermission() async {
    if (await Permission.audio.isGranted) return PermissionStatus.granted;

    // Try audio permission for Android 13+
    if (await Permission.audio.request().isGranted) {
      return PermissionStatus.granted;
    }

    // Fallback to storage for older Android
    return await Permission.storage.request();
  }

  Future<void> _playTrack(int index) async {
    if (index < 0 || index >= _playlist.length) return;

    try {
      await _player.setFilePath(_playlist[index]);
      await _player.play();

      setState(() {
        _currentIndex = index;
      });

      // Auto-play next track
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _playNext();
        }
      });
    } catch (e) {
      print('Playback error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot play this file.')),
      );
    }
  }

  void _playNext() {
    if (_currentIndex + 1 < _playlist.length) {
      _playTrack(_currentIndex + 1);
    }
  }

  void _playPrevious() {
    if (_currentIndex - 1 >= 0) {
      _playTrack(_currentIndex - 1);
    }
  }

  Widget _buildTrackItem(String path, int index) {
    final fileName = path.split('/').last;
    final isCurrent = index == _currentIndex;

    return ListTile(
      title: Text(
        fileName,
        style: TextStyle(
          color: isCurrent ? Colors.greenAccent : Colors.white,
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () => _playTrack(index),
    );
  }

  Widget _buildControls() {
    final isPlaying = _player.playing;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.skip_previous, size: 32),
          onPressed: _playPrevious,
        ),
        IconButton(
          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, size: 40),
          onPressed: () {
            if (_player.playing) {
              _player.pause();
            } else if (_currentIndex >= 0) {
              _player.play();
            } else if (_playlist.isNotEmpty) {
              _playTrack(0);
            }
          },
        ),
        IconButton(
          icon: Icon(Icons.skip_next, size: 32),
          onPressed: _playNext,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Band Playlist Player'),
        actions: [
          IconButton(
            icon: Icon(Icons.library_music),
            onPressed: _pickAudioFiles,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _playlist.isEmpty
                ? Center(child: Text("No tracks selected."))
                : ListView.builder(
                    itemCount: _playlist.length,
                    itemBuilder: (context, index) =>
                        _buildTrackItem(_playlist[index], index),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _buildControls(),
          ),
        ],
      ),
    );
  }
}
