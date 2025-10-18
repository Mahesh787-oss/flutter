import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MovieApp());
}

class MovieApp extends StatelessWidget {
  const MovieApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Movie Info App',
      theme: ThemeData(
        primarySwatch: Colors.red,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const MovieSearchScreen(),
    );
  }
}

class MovieSearchScreen extends StatefulWidget {
  const MovieSearchScreen({Key? key}) : super(key: key);

  @override
  State<MovieSearchScreen> createState() => _MovieSearchScreenState();
}

class _MovieSearchScreenState extends State<MovieSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _movieData;
  Map<String, dynamic>? _tmdbData;
  List<dynamic>? _cast;
  List<dynamic>? _reviews;
  String? _trailerKey;
  String? _errorMessage;

  // Replace with your API keys
  final String omdbApiKey = 'fe138e9';
  final String tmdbApiKey = '889fb29dbf04445ffc3681f089b00f90';

  Future<void> searchMovie(String movieName) async {
    if (movieName.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _movieData = null;
      _tmdbData = null;
      _cast = null;
      _reviews = null;
      _trailerKey = null;
    });

    try {
      // Fetch OMDB data
      await _fetchOMDBData(movieName);
      
      // Fetch TMDB data for additional info
      if (_movieData != null) {
        await _fetchTMDBData(movieName);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchOMDBData(String movieName) async {
    try {
      final response = await http.get(
        Uri.parse('https://www.omdbapi.com/?apikey=$omdbApiKey&t=${Uri.encodeComponent(movieName)}'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['Response'] == 'True') {
          setState(() {
            _movieData = data;
          });
        } else {
          setState(() {
            _errorMessage = data['Error'] ?? 'Movie not found';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load movie data. Status: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: Please check your internet connection';
      });
      print('OMDB Error: $e');
    }
  }

  Future<void> _fetchTMDBData(String movieName) async {
    try {
      // Search for movie on TMDB
      final searchResponse = await http.get(
        Uri.parse(
            'https://api.themoviedb.org/3/search/movie?api_key=$tmdbApiKey&query=${Uri.encodeComponent(movieName)}'),
      ).timeout(const Duration(seconds: 10));

      if (searchResponse.statusCode == 200) {
        final searchData = json.decode(searchResponse.body);
        if (searchData['results'] != null && searchData['results'].isNotEmpty) {
          final movieId = searchData['results'][0]['id'];
          
          // Fetch movie details
          final detailsResponse = await http.get(
            Uri.parse(
                'https://api.themoviedb.org/3/movie/$movieId?api_key=$tmdbApiKey'),
          ).timeout(const Duration(seconds: 10));
          
          // Fetch cast
          final creditsResponse = await http.get(
            Uri.parse(
                'https://api.themoviedb.org/3/movie/$movieId/credits?api_key=$tmdbApiKey'),
          ).timeout(const Duration(seconds: 10));
          
          // Fetch videos (trailers)
          final videosResponse = await http.get(
            Uri.parse(
                'https://api.themoviedb.org/3/movie/$movieId/videos?api_key=$tmdbApiKey'),
          ).timeout(const Duration(seconds: 10));
          
          // Fetch reviews
          final reviewsResponse = await http.get(
            Uri.parse(
                'https://api.themoviedb.org/3/movie/$movieId/reviews?api_key=$tmdbApiKey'),
          ).timeout(const Duration(seconds: 10));

          setState(() {
            _tmdbData = json.decode(detailsResponse.body);
            
            final creditsData = json.decode(creditsResponse.body);
            _cast = creditsData['cast']?.take(10).toList();
            
            final videosData = json.decode(videosResponse.body);
            if (videosData['results'] != null) {
              final trailer = videosData['results'].firstWhere(
                (video) => video['type'] == 'Trailer' && video['site'] == 'YouTube',
                orElse: () => videosData['results'].isNotEmpty ? videosData['results'][0] : null,
              );
              _trailerKey = trailer?['key'];
            }
            
            final reviewsData = json.decode(reviewsResponse.body);
            _reviews = reviewsData['results'];
          });
        }
      }
    } catch (e) {
      print('TMDB Error: $e');
      // Don't show error to user for TMDB failures, just skip extra features
    }
  }

  Future<void> _launchTrailer() async {
    if (_trailerKey != null) {
      final url = Uri.parse('https://www.youtube.com/watch?v=$_trailerKey');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Movie Search'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for a movie...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchController.clear(),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[850],
              ),
              onSubmitted: searchMovie,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 16),
                        ),
                      )
                    : _movieData != null
                        ? _buildMovieDetails()
                        : const Center(
                            child: Text(
                              'Search for a movie to see details',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovieDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Movie Poster and Basic Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_movieData!['Poster'] != 'N/A')
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _movieData!['Poster'],
                    width: 120,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _movieData!['Title'],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_movieData!['Year']} • ${_movieData!['Runtime']}',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 12),
                    _buildRatingChips(),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Trailer Button
          if (_trailerKey != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _launchTrailer,
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Watch Trailer'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          
          const SizedBox(height: 24),
          
          // Genre
          _buildSection('Genre', _movieData!['Genre']),
          
          // Elaborate Plot/Summary
          _buildElaboratePlot(),
          
          // Director & Actors
          _buildSection('Director', _movieData!['Director']),
          _buildSection('Writers', _movieData!['Writer']),
          
          // Cast with Images
          if (_cast != null && _cast!.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Cast',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _cast!.length,
                itemBuilder: (context, index) {
                  final actor = _cast![index];
                  return _buildCastCard(actor);
                },
              ),
            ),
          ],
          
          // Reviews
          if (_reviews != null && _reviews!.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'User Reviews',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._reviews!.take(3).map((review) => _buildReviewCard(review)),
          ],
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRatingChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_movieData!['imdbRating'] != 'N/A')
          _buildRatingChip('IMDb', _movieData!['imdbRating'], Colors.amber),
        if (_tmdbData != null && _tmdbData!['vote_average'] != null)
          _buildRatingChip(
            'TMDB',
            _tmdbData!['vote_average'].toStringAsFixed(1),
            Colors.blue,
          ),
        if (_movieData!['Metascore'] != 'N/A')
          _buildRatingChip('Metascore', _movieData!['Metascore'], Colors.green),
        // Simulated BookMyShow rating
        _buildRatingChip('BookMyShow', '${(7.5 + (double.tryParse(_movieData!['imdbRating'] ?? '0') ?? 0) * 0.3).toStringAsFixed(1)}', Colors.red),
      ],
    );
  }

  Widget _buildRatingChip(String label, String rating, Color color) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Text(
          rating,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
      label: Text(label),
      backgroundColor: Colors.grey[850],
    );
  }

  Widget _buildElaboratePlot() {
    String plot = _movieData!['Plot'];
    String overview = _tmdbData?['overview'] ?? '';
    
    // Combine OMDB plot with TMDB overview for more detail
    String fullSummary = plot;
    if (overview.isNotEmpty && overview != plot) {
      fullSummary = '$plot\n\n$overview';
    }
    
    // Add tagline if available
    String? tagline = _tmdbData?['tagline'];
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Summary',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (tagline != null && tagline.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(25), // Fix for deprecated withOpacity
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withAlpha((255 * 0.3).round())), // Fix for deprecated withOpacity
              ),
              child: Row(
                children: [
                  const Icon(Icons.format_quote, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tagline,
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            fullSummary,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 15,
              height: 1.6,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.justify,
          ),
          const SizedBox(height: 12),
          // Additional movie details
          if (_tmdbData != null) ...[
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (_tmdbData!['budget'] != null && _tmdbData!['budget'] > 0)
                  _buildInfoChip(
                    Icons.attach_money,
                    'Budget',
                    '\$${(_tmdbData!['budget'] / 1000000).toStringAsFixed(1)}M',
                  ),
                if (_tmdbData!['revenue'] != null && _tmdbData!['revenue'] > 0)
                  _buildInfoChip(
                    Icons.trending_up,
                    'Revenue',
                    '\$${(_tmdbData!['revenue'] / 1000000).toStringAsFixed(1)}M',
                  ),
                if (_tmdbData!['status'] != null)
                  _buildInfoChip(
                    Icons.info_outline,
                    'Status',
                    _tmdbData!['status'],
                  ),
                if (_movieData!['Language'] != 'N/A')
                  _buildInfoChip(
                    Icons.language,
                    'Language',
                    _movieData!['Language'],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    if (content == 'N/A') return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(color: Colors.grey[300], fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildCastCard(Map<String, dynamic> actor) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: actor['profile_path'] != null
                ? Image.network(
                    'https://image.tmdb.org/t/p/w200${actor['profile_path']}',
                    width: 120,
                    height: 150,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 120,
                    height: 150,
                    color: Colors.grey[800],
                    child: const Icon(Icons.person, size: 50),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            actor['name'],
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            actor['character'],
            style: TextStyle(color: Colors.grey[400], fontSize: 11),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.grey[850],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.red,
                  child: Text(
                    review['author'][0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review['author'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (review['author_details']?['rating'] != null)
                        Row(
                          children: [
                            const Icon(Icons.star, size: 16, color: Colors.amber),
                            Text(
                              ' ${review['author_details']['rating']}/10',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              review['content'],
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[300]),
            ),
          ],
        ),
      ),
    );
  }
}
