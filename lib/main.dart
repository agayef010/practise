import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyMusicApp());
}

class MyMusicApp extends StatefulWidget {
  @override
  _MyMusicAppState createState() => _MyMusicAppState();
}

class _MyMusicAppState extends State<MyMusicApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MusicHomePage(),
    );
  }
}

class MusicHomePage extends StatefulWidget {
  @override
  _MusicHomePageState createState() => _MusicHomePageState();
}

class _MusicHomePageState extends State<MusicHomePage> {
  TextEditingController _searchController = TextEditingController();
  List<dynamic> _songs = [];
  bool _isLoading = false;
  String _error = '';
  int? _playingIndex;
  AudioPlayer _audioPlayer = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  bool _isSearching = false;
  Set<int> _favoriteIds = {};
  List<dynamic> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _fetchDefaultSongs();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('favorite_ids') ?? [];
    setState(() {
      _favoriteIds = ids.map((e) => int.tryParse(e) ?? 0).where((e) => e != 0).toSet();
    });
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorite_ids', _favoriteIds.map((e) => e.toString()).toList());
  }

  void _toggleFavorite(dynamic song) {
    final id = song['id'] as int;
    setState(() {
      if (_favoriteIds.contains(id)) {
        _favoriteIds.remove(id);
        _favorites.removeWhere((s) => s['id'] == id);
      } else {
        _favoriteIds.add(id);
        _favorites.add(song);
      }
    });
    _saveFavorites();
  }

  void _openFavorites() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FavoritesPage(
          favorites: _favorites,
          onPlay: (song, index) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NowPlayingPage(
                  songs: _favorites,
                  currentIndex: index,
                  isFavorite: (id) => _favoriteIds.contains(id),
                  onToggleFavorite: (song) => _toggleFavorite(song),
                ),
              ),
            );
          },
          isFavorite: (id) => _favoriteIds.contains(id),
          onToggleFavorite: (song) => _toggleFavorite(song),
        ),
      ),
    );
  }

  Future<void> _fetchDefaultSongs() async {
    setState(() {
      _isLoading = true;
      _error = '';
      _songs = [];
      _playingIndex = null;
    });
    try {
      // Daha etibarlı endpoint
      final url = Uri.parse('https://api.deezer.com/chart');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> songs = [];
        if (data['tracks'] != null && data['tracks']['data'] != null && data['tracks']['data'] is List) {
          songs = data['tracks']['data'];
        }
        setState(() {
          _songs = songs;
          if (_songs.isEmpty) _error = 'Default mahnılar tapılmadı.';
        });
      } else {
        setState(() {
          _error = 'Default mahnılar yüklənmədi.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Şəbəkə xətası (default)';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchSongs(String query) async {
    setState(() {
      _isLoading = true;
      _error = '';
      _songs = [];
      _playingIndex = null;
    });
    try {
      final url = Uri.parse('https://api.deezer.com/search?q=$query');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _songs = data['data'];
        });
      } else {
        setState(() {
          _error = 'Axtarışda xəta baş verdi';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Şəbəkə xətası';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _playPreview(String url, int index) async {
    if (_playingIndex == index && _playerState == PlayerState.playing) {
      await _audioPlayer.pause();
      setState(() {
        _playerState = PlayerState.paused;
      });
      return;
    }
    await _audioPlayer.stop();
    await _audioPlayer.play(UrlSource(url));
    setState(() {
      _playingIndex = index;
      _playerState = PlayerState.playing;
    });
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _playerState = PlayerState.stopped;
        _playingIndex = null;
      });
    });
  }

  Widget _buildSongItem(dynamic song, int index) {
    final isPlaying = _playingIndex == index && _playerState == PlayerState.playing;
    final isFavorite = _favoriteIds.contains(song['id']);
    return Card(
      color: Color(0xFF282828),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            song['album']['cover_medium'],
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Icon(Icons.music_note, color: Colors.white),
          ),
        ),
        title: Text(
          song['title'],
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          song['artist']['name'],
          style: TextStyle(color: Colors.white70),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.redAccent : Colors.white38,
              ),
              onPressed: () => _toggleFavorite(song),
            ),
            IconButton(
              icon: Icon(
                isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                color: Colors.greenAccent,
                size: 36,
              ),
              onPressed: song['preview'] != null && song['preview'].toString().isNotEmpty
                  ? () => _playPreview(song['preview'], index)
                  : null,
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NowPlayingPage(
                songs: _songs,
                currentIndex: index,
                isFavorite: (id) => _favoriteIds.contains(id),
                onToggleFavorite: (song) => _toggleFavorite(song),
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Color(0xFF191414),
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(Icons.favorite, color: Colors.redAccent),
        onPressed: _openFavorites,
      ),
      title: !_isSearching
          ? Text(
              'Music Player',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: 1.2,
              ),
            )
          : Container(
              height: 45,
              decoration: BoxDecoration(
                color: Color(0xFF282828),
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Mahnı və ya artist axtar...',
                  hintStyle: TextStyle(color: Colors.white54),
                  prefixIcon: Icon(Icons.search, color: Colors.white),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    _searchSongs(value.trim());
                  }
                  setState(() {
                    _isSearching = false;
                  });
                },
              ),
            ),
      actions: [
        !_isSearching
            ? IconButton(
                icon: Icon(Icons.search, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isSearching = true;
                  });
                },
              )
            : IconButton(
                icon: Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                    _fetchDefaultSongs();
                  });
                },
              ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF191414),
      appBar: _buildAppBar(),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.greenAccent))
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: TextStyle(color: Colors.white70, fontSize: 18)))
              : _songs.isEmpty
                  ? Center(
                      child: Text(
                        'Mahnı tapılmadı. Başqa axtarış edin.',
                        style: TextStyle(color: Colors.white70, fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _songs.length,
                      itemBuilder: (context, index) => _buildSongItem(_songs[index], index),
                    ),
    );
  }
}

extension on BuildContext {
  get theme => Theme.of(this);
}

class NowPlayingPage extends StatefulWidget {
  final List<dynamic> songs;
  final int currentIndex;
  final bool Function(int id) isFavorite;
  final void Function(dynamic song) onToggleFavorite;

  NowPlayingPage({required this.songs, required this.currentIndex, required this.isFavorite, required this.onToggleFavorite});

  @override
  _NowPlayingPageState createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  late int _currentIndex;
  bool _isPlaying = false;
  AudioPlayer _audioPlayer = AudioPlayer();
  Duration _position = Duration.zero;
  Duration _duration = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    _playCurrentSong();
    _audioPlayer.onPositionChanged.listen((pos) {
      setState(() {
        _position = pos;
      });
    });
    _audioPlayer.onDurationChanged.listen((dur) {
      setState(() {
        _duration = dur;
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playCurrentSong() async {
    final song = widget.songs[_currentIndex];
    if (song['preview'] != null && song['preview'].toString().isNotEmpty) {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(song['preview']));
      setState(() {
        _isPlaying = true;
        _position = Duration.zero;
        _duration = Duration(seconds: 30);
      });
      _audioPlayer.onPlayerComplete.listen((event) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      });
    }
  }

  void _playPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      await _audioPlayer.resume();
      setState(() {
        _isPlaying = true;
      });
    }
  }

  void _nextSong() {
    if (_currentIndex < widget.songs.length - 1) {
      setState(() {
        _currentIndex++;
        _isPlaying = false;
        _position = Duration.zero;
      });
      _playCurrentSong();
    }
  }

  void _prevSong() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isPlaying = false;
        _position = Duration.zero;
      });
      _playCurrentSong();
    }
  }

  void _seek(double value) async {
    final pos = Duration(seconds: value.round());
    await _audioPlayer.seek(pos);
    setState(() {
      _position = pos;
    });
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.songs[_currentIndex];
    final isFavorite = widget.isFavorite(song['id']);
    return Scaffold(
      backgroundColor: Color(0xFF191414),
      appBar: AppBar(
        backgroundColor: Color(0xFF191414),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text('Now Playing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.redAccent : Colors.white38),
            onPressed: () => widget.onToggleFavorite(song),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Hero(
              tag: song['id'].toString(),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(0.2),
                      blurRadius: 30,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.network(
                    song['album']['cover_xl'] ?? song['album']['cover_big'] ?? song['album']['cover_medium'],
                    width: 260,
                    height: 260,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 260,
                      height: 260,
                      color: Colors.deepPurple,
                      child: Icon(Icons.music_note, color: Colors.white, size: 100),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 36),
            Text(
              song['title'] ?? '',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 10),
            Text(
              song['artist']['name'] ?? '',
              style: TextStyle(fontSize: 20, color: Colors.white70),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 40),
            Slider(
              value: _position.inSeconds.toDouble().clamp(0, 30),
              min: 0,
              max: 30,
              activeColor: Colors.greenAccent,
              inactiveColor: Colors.white24,
              onChanged: (value) => _seek(value),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatTime(_position), style: TextStyle(color: Colors.white70)),
                Text('-${_formatTime(_duration - _position)}', style: TextStyle(color: Colors.white70)),
              ],
            ),
            SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.skip_previous),
                  iconSize: 48,
                  color: _currentIndex > 0 ? Colors.white : Colors.white24,
                  onPressed: _currentIndex > 0 ? _prevSong : null,
                ),
                SizedBox(width: 30),
                GestureDetector(
                  onTap: _playPause,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.greenAccent.withOpacity(0.4),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.black,
                        size: 54,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 30),
                IconButton(
                  icon: Icon(Icons.skip_next),
                  iconSize: 48,
                  color: _currentIndex < widget.songs.length - 1 ? Colors.white : Colors.white24,
                  onPressed: _currentIndex < widget.songs.length - 1 ? _nextSong : null,
                ),
              ],
            ),
            SizedBox(height: 40),
            Text(
              'from agayeff',
              style: TextStyle(color: Colors.white38, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final m = twoDigits(d.inMinutes);
    final s = twoDigits(d.inSeconds % 60);
    return '$m:$s';
  }
}

class FavoritesPage extends StatelessWidget {
  final List<dynamic> favorites;
  final void Function(dynamic song, int index) onPlay;
  final bool Function(int id) isFavorite;
  final void Function(dynamic song) onToggleFavorite;

  FavoritesPage({required this.favorites, required this.onPlay, required this.isFavorite, required this.onToggleFavorite});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF191414),
      appBar: AppBar(
        backgroundColor: Color(0xFF191414),
        elevation: 0,
        title: Text('Favorilər', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: favorites.isEmpty
          ? Center(
              child: Text('Favori mahnı yoxdur', style: TextStyle(color: Colors.white70, fontSize: 18)),
            )
          : ListView.builder(
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final song = favorites[index];
                final isFav = isFavorite(song['id']);
                return Card(
                  color: Color(0xFF282828),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        song['album']['cover_medium'],
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(Icons.music_note, color: Colors.white),
                      ),
                    ),
                    title: Text(
                      song['title'],
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      song['artist']['name'],
                      style: TextStyle(color: Colors.white70),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        color: isFav ? Colors.redAccent : Colors.white38,
                      ),
                      onPressed: () => onToggleFavorite(song),
                    ),
                    onTap: () => onPlay(song, index),
                  ),
                );
              },
            ),
    );
  }
}

Future<List<Map<String, dynamic>>> searchSongs(String query) async {
  final url = Uri.parse('https://api.deezer.com/search?q=$query');
  final response = await http.get(url);
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    return List<Map<String, dynamic>>.from(data['data']);
  } else {
    throw Exception('Axtarışda xəta baş verdi');
  }
}

AudioPlayer audioPlayer = AudioPlayer();

void playPreview(String url) async {
  await audioPlayer.play(UrlSource(url));
}

void pausePreview() async {
  await audioPlayer.pause();
}
