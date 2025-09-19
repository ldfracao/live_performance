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

  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();

    _player.positionStream.listen((pos) {
      setState(() {
        _currentPosition = pos;
      });
    });

    _player.durationStream.listen((dur) {
      if (dur != null) {
        setState(() {
          _totalDuration = dur;
        });
      }
    });

_player.playerStateStream.listen((state) async {
  if (state.processingState == ProcessingState.completed) {
    final nextIndex = _currentIndex + 1;

    if (nextIndex < _playlist.length) {
      try {
        await _player.setFilePath(_playlist[nextIndex]);
	_player.pause();
        setState(() {
          _currentIndex = nextIndex;
          _currentPosition = Duration.zero;
          _totalDuration = _player.duration ?? Duration.zero;
        });

        // Do NOT call _player.play(); it will stay paused.
      } catch (e) {
        print('Error loading next track: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot load next track.')),
        );
      }
    }
  }
});
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<PermissionStatus> _getStoragePermission() async {
    if (await Permission.audio.request().isGranted) {
      return PermissionStatus.granted;
    }
    return await Permission.storage.request();
  }

  Future<void> _pickAudioFiles() async {
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

  Future<void> _playTrack(int index) async {
    if (index < 0 || index >= _playlist.length) return;

    try {
      await _player.setFilePath(_playlist[index]);
      await _player.play();

      setState(() {
        _currentIndex = index;
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

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;

      final item = _playlist.removeAt(oldIndex);
      _playlist.insert(newIndex, item);

      if (_currentIndex == oldIndex) {
        _currentIndex = newIndex;
      } else if (_currentIndex > oldIndex && _currentIndex < newIndex) {
        _currentIndex--;
      } else if (_currentIndex < oldIndex && _currentIndex >= newIndex) {
        _currentIndex++;
      }
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  Widget _buildControls() {
    final isPlaying = _player.playing;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Slider(
          min: 0,
          max: _totalDuration.inMilliseconds.toDouble(),
          value: _currentPosition.inMilliseconds.clamp(0, _totalDuration.inMilliseconds).toDouble(),
          onChanged: (value) {
            final newPosition = Duration(milliseconds: value.round());
            _player.seek(newPosition);
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(_currentPosition), style: TextStyle(fontSize: 12)),
              Text(_formatDuration(_totalDuration), style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.replay_10, size: 28),
              onPressed: () {
                final rewindTo = _currentPosition - Duration(seconds: 10);
                _player.seek(rewindTo > Duration.zero ? rewindTo : Duration.zero);
              },
            ),
            IconButton(
              icon: Icon(Icons.skip_previous, size: 32),
              onPressed: _playPrevious,
            ),
            IconButton(
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, size: 40),
              onPressed: () {
                if (isPlaying) {
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
            IconButton(
              icon: Icon(Icons.forward_10, size: 28),
              onPressed: () {
                final forwardTo = _currentPosition + Duration(seconds: 10);
                if (_totalDuration != Duration.zero && forwardTo < _totalDuration) {
                  _player.seek(forwardTo);
                } else {
                  _player.seek(_totalDuration);
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Live Performance'),
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
                : Scrollbar(
                    child: ReorderableListView.builder(
                      itemCount: _playlist.length,
                      onReorder: _onReorder,
                      buildDefaultDragHandles: false,
                      itemBuilder: (context, index) {
                        final path = _playlist[index];
                        final fileName = path.split('/').last;
                        final isCurrent = index == _currentIndex;

                        return Dismissible(
                          key: ValueKey(path),
                          direction: DismissDirection.horizontal,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerLeft,
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Icon(Icons.delete, color: Colors.white),
                          ),
                          secondaryBackground: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (direction) {
                            setState(() {
                              _playlist.removeAt(index);
                              if (_currentIndex == index) {
                                _player.stop();
                                _currentIndex = -1;
                              } else if (_currentIndex > index) {
                                _currentIndex--;
                              }
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Track removed from playlist')),
                            );
                          },
                          child: ReorderableDelayedDragStartListener(
                            index: index,
                            child: ListTile(
                              title: Text(
                                fileName,
                                style: TextStyle(
                                  color: isCurrent ? Colors.greenAccent : Colors.white,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              onTap: () => _playTrack(index),
                              trailing: Icon(Icons.drag_handle),
                            ),
                          ),
                        );
                      },
                    ),
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
