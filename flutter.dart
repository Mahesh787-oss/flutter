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
      title: 'CineScope',
      theme: ThemeData(
        primarySwatch: Colors.red,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        cardTheme: widget(
          child: CardTheme(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      home: const MovieSearchScreen(),
    );
  }

  CardThemeData? widget({required CardTheme child}) {
    return null;
  }
}

class MovieSearchScreen extends StatefulWidget {
  const MovieSearchScreen({Key? key}) : super(key: key);

  @override
  State<MovieSearchScreen> createState() => _MovieSearchScreenState();
}

class _MovieSearchScreenState extends State<MovieSearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _movieData;
  Map<String, dynamic>? _tmdbData;
  Map<String, dynamic>? _wikiData;
  List<dynamic>? _cast;
  List<dynamic>? _reviews;
  String? _imdbId;
  String? _errorMessage;
  List<dynamic>? _searchResults;
  bool _showingSearchResults = false;
  bool _showingDetails = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final String omdbApiKey = 'fe138e9';
  final String tmdbApiKey = '889fb29dbf04445ffc3681f089b00f90';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> searchMovie(String movieName) async {
    if (movieName.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _movieData = null;
      _tmdbData = null;
      _wikiData = null;
      _cast = null;
      _reviews = null;
      _imdbId = null;
      _searchResults = null;
      _showingSearchResults = false;
      _showingDetails = false;
    });

    try {
      final searchResponse = await http.get(
        Uri.parse(
            'https://api.themoviedb.org/3/search/movie?api_key=$tmdbApiKey&query=${Uri.encodeComponent(movieName)}'),
      ).timeout(const Duration(seconds: 10));

      if (searchResponse.statusCode == 200) {
        final searchData = json.decode(searchResponse.body);
        if (searchData['results'] != null && searchData['results'].isNotEmpty) {
          final results = searchData['results'] as List;
          
          if (results.length > 1) {
            setState(() {
              _searchResults = results.take(10).toList();
              _showingSearchResults = true;
            });
          } else {
            await _loadMovieById(results[0]['id'] as int);
          }
        } else {
          setState(() {
            _errorMessage = 'No movies found. Try a different search term.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error. Please check your internet.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMovieById(int movieId) async {
    setState(() {
      _isLoading = true;
      _showingSearchResults = false;
    });

    try {
      await _fetchTMDBDataById(movieId);
      await _fetchOMDBData();
      await _fetchWikipediaData();
      
      setState(() {
        _showingDetails = true;
      });
      _animationController.forward(from: 0);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading movie details';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchOMDBData() async {
    if (_tmdbData?['imdb_id'] == null) return;
    
    _imdbId = _tmdbData!['imdb_id'] as String;
    
    try {
      final response = await http.get(
        Uri.parse('https://www.omdbapi.com/?apikey=$omdbApiKey&i=$_imdbId'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['Response'] == 'True') {
          setState(() {
            _movieData = data;
          });
        }
      }
    } catch (e) {
      print('OMDB Error: $e');
    }
  }

  Future<void> _fetchWikipediaData() async {
    if (_tmdbData == null) return;
    
    final movieTitle = _tmdbData!['title'] as String;
    final year = (_tmdbData!['release_date'] as String?)?.substring(0, 4) ?? '';
    
    try {
      // Try multiple search variations
      final searchQueries = [
        '$movieTitle ($year film)',
        '$movieTitle film',
        movieTitle,
      ];
      
      for (final query in searchQueries) {
        try {
          final searchUrl = Uri.https(
            'en.wikipedia.org',
            '/w/api.php',
            {
              'action': 'opensearch',
              'search': query,
              'limit': '3',
              'format': 'json',
              'origin': '*',
            },
          );
          
          final searchResponse = await http.get(
            searchUrl,
            headers: {
              'User-Agent': 'CineScope/1.0',
              'Accept': 'application/json',
            },
          ).timeout(const Duration(seconds: 10));
          
          if (searchResponse.statusCode == 200) {
            final searchData = json.decode(searchResponse.body);
            if (searchData[1] != null && (searchData[1] as List).isNotEmpty) {
              final pageTitle = searchData[1][0] as String;
              
              // Fetch full page content including infobox data
              final contentUrl = Uri.https(
                'en.wikipedia.org',
                '/w/api.php',
                {
                  'action': 'query',
                  'titles': pageTitle,
                  'prop': 'extracts|revisions|pageimages|info',
                  'rvprop': 'content',
                  'exintro': '1',
                  'explaintext': '1',
                  'inprop': 'url',
                  'format': 'json',
                  'piprop': 'original',
                  'origin': '*',
                },
              );
              
              final contentResponse = await http.get(
                contentUrl,
                headers: {
                  'User-Agent': 'CineScope/1.0',
                  'Accept': 'application/json',
                },
              ).timeout(const Duration(seconds: 10));
              
              if (contentResponse.statusCode == 200) {
                final contentData = json.decode(contentResponse.body);
                final pages = contentData['query']['pages'] as Map<String, dynamic>;
                final pageData = pages.values.first as Map<String, dynamic>;
                
                if (pageData['extract'] != null && (pageData['extract'] as String).isNotEmpty) {
                  // Extract budget and revenue from wiki content
                  String? budgetStr;
                  String? revenueStr;
                  
                  if (pageData['revisions'] != null) {
                    final revisions = pageData['revisions'] as List;
                    if (revisions.isNotEmpty) {
                      final content = revisions[0]['*'] as String?;
                      if (content != null) {
                        // Extract budget
                        final budgetMatch = RegExp(r'\|\s*budget\s*=\s*([^\n\|]+)', caseSensitive: false).firstMatch(content);
                        if (budgetMatch != null) {
                          budgetStr = _cleanWikiValue(budgetMatch.group(1) ?? '');
                        }
                        
                        // Extract box office/revenue
                        final revenueMatch = RegExp(r'\|\s*(?:box[\s_]office|gross)\s*=\s*([^\n\|]+)', caseSensitive: false).firstMatch(content);
                        if (revenueMatch != null) {
                          revenueStr = _cleanWikiValue(revenueMatch.group(1) ?? '');
                        }
                      }
                    }
                  }
                  
                  setState(() {
                    _wikiData = {
                      ...pageData,
                      'budget_str': budgetStr,
                      'revenue_str': revenueStr,
                    };
                  });
                  return; // Successfully found Wikipedia data
                }
              }
            }
          }
        } catch (e) {
          print('Wikipedia search attempt failed for "$query": $e');
          continue; // Try next query
        }
      }
    } catch (e) {
      print('Wikipedia Error: $e');
    }
  }

  String _cleanWikiValue(String value) {
    // Remove wiki markup, references, and extra spaces
    return value
        .replaceAll(RegExp(r'\[\[([^\]]+)\]\]'), r'$1')
        .replaceAll(RegExp(r'\{\{[^\}]+\}\}'), '')
        .replaceAll(RegExp(r'<ref[^>]*>.*?</ref>', caseSensitive: false, dotAll: true), '')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'\[\d+\]'), '')
        .trim();
  }

  Future<bool> _fetchTMDBDataById(int movieId) async {
    try {
      final detailsResponse = await http.get(
        Uri.parse('https://api.themoviedb.org/3/movie/$movieId?api_key=$tmdbApiKey'),
      ).timeout(const Duration(seconds: 10));
      
      final creditsResponse = await http.get(
        Uri.parse('https://api.themoviedb.org/3/movie/$movieId/credits?api_key=$tmdbApiKey'),
      ).timeout(const Duration(seconds: 10));
      
      final reviewsResponse = await http.get(
        Uri.parse('https://api.themoviedb.org/3/movie/$movieId/reviews?api_key=$tmdbApiKey'),
      ).timeout(const Duration(seconds: 10));

      final details = json.decode(detailsResponse.body);
      final creditsData = json.decode(creditsResponse.body);
      final reviewsData = json.decode(reviewsResponse.body);
      
      setState(() {
        _tmdbData = details;
        _cast = creditsData['cast']?.take(15).toList();
        
        // Filter only positive reviews (rating >= 7)
        final allReviews = reviewsData['results'] as List<dynamic>?;
        if (allReviews != null) {
          _reviews = allReviews.where((review) {
            final rating = review['author_details']?['rating'];
            return rating != null && rating >= 7;
          }).take(5).toList();
        }
      });
      
      return true;
    } catch (e) {
      print('TMDB Error: $e');
      return false;
    }
  }

  Future<void> _launchIMDBTrailer() async {
    if (_imdbId != null) {
      final url = Uri.parse('https://www.imdb.com/title/$_imdbId/');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _launchActorWikipedia(String actorName) async {
    try {
      final searchUrl = Uri.https(
        'en.wikipedia.org',
        '/w/api.php',
        {
          'action': 'opensearch',
          'search': actorName,
          'limit': '1',
          'format': 'json',
          'origin': '*',
        },
      );
      
      final response = await http.get(
        searchUrl,
        headers: {
          'User-Agent': 'CineScope/1.0',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data[3] != null && (data[3] as List).isNotEmpty) {
          final wikiUrl = Uri.parse(data[3][0] as String);
          if (await canLaunchUrl(wikiUrl)) {
            await launchUrl(wikiUrl, mode: LaunchMode.externalApplication);
          }
        }
      }
    } catch (e) {
      print('Error launching Wikipedia: $e');
    }
  }

  void _goBack() {
    setState(() {
      _showingDetails = false;
      _showingSearchResults = _searchResults != null && _searchResults!.isNotEmpty;
      _movieData = null;
      _tmdbData = null;
      _wikiData = null;
      _cast = null;
      _reviews = null;
      _imdbId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF0A0A0A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? _buildLoadingScreen()
                    : _errorMessage != null
                        ? _buildErrorScreen()
                        : _showingDetails
                            ? _buildMovieDetails()
                            : _showingSearchResults
                                ? _buildSearchResults()
                                : _buildWelcomeScreen(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.shade900.withValues(alpha: 0.3),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (_showingDetails)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: _goBack,
                )
              else
                Icon(
                  Icons.movie_filter,
                  color: Colors.red.shade400,
                  size: 32,
                ),
              const SizedBox(width: 12),
              const Text(
                'CineScope',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.shade800),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_movies, size: 16, color: Colors.red.shade400),
                    const SizedBox(width: 4),
                    const Text('PRO', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          if (!_showingDetails) ...[
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.red.shade900.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.shade900.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search movies, series, actors...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: Icon(Icons.search, color: Colors.red.shade400),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onChanged: (value) => setState(() {}),
                onSubmitted: searchMovie,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.red.shade900.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade400),
                ),
              ),
              Icon(Icons.movie_creation, color: Colors.red.shade400, size: 30),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Loading...',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.red.shade400),
            const SizedBox(height: 24),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _showingSearchResults = false;
                  _showingDetails = false;
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade900,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.movie_filter, size: 120, color: Colors.red.shade900.withValues(alpha: 0.5)),
          const SizedBox(height: 24),
          Text(
            'Discover Movies',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Search for any movie to get started',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade900.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade900.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.red.shade400),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Found ${_searchResults!.length} results. Tap to view details.',
                  style: TextStyle(color: Colors.grey[300]),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: _searchResults!.length,
            itemBuilder: (context, index) {
              final movie = _searchResults![index] as Map<String, dynamic>;
              return _buildSearchResultCard(movie);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultCard(Map<String, dynamic> movie) {
    final title = movie['title'] ?? 'Unknown';
    final String? releaseDate = movie['release_date'] as String?;
    final year = (releaseDate != null && releaseDate.length >= 4) 
        ? releaseDate.substring(0, 4) 
        : 'N/A';
    final overview = movie['overview'] ?? 'No description available';
    final posterPath = movie['poster_path'] as String?;
    final rating = movie['vote_average'] as num?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.grey[900]!.withValues(alpha: 0.5),
            Colors.grey[900]!.withValues(alpha: 0.3),
          ],
        ),
        border: Border.all(color: Colors.grey[800]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _loadMovieById(movie['id'] as int),
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.red.shade900.withValues(alpha: 0.3),
          highlightColor: Colors.red.shade900.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Hero(
                  tag: 'poster_${movie['id']}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: posterPath != null
                        ? Image.network(
                            'https://image.tmdb.org/t/p/w200$posterPath',
                            width: 80,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildPlaceholderPoster();
                            },
                          )
                        : _buildPlaceholderPoster(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade900,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              year,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (rating != null) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.star, color: Colors.amber.shade600, size: 18),
                            Text(
                              ' ${rating.toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        overview,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 13,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.red.shade400, size: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderPoster() {
    return Container(
      width: 80,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.movie, size: 40, color: Colors.grey[700]),
    );
  }

  Widget _buildMovieDetails() {
    if (_tmdbData == null) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildHeroSection(),
            _buildDetailsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    final backdropPath = _tmdbData!['backdrop_path'] as String?;
    final posterPath = _tmdbData!['poster_path'] as String?;
    final title = _tmdbData!['title'] ?? 'Unknown';
    final tagline = _tmdbData!['tagline'] as String?;

    return Stack(
      children: [
        if (backdropPath != null)
          ShaderMask(
            shaderCallback: (rect) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xFF0A0A0A)],
                stops: [0.3, 1.0],
              ).createShader(rect);
            },
            blendMode: BlendMode.dstIn,
            child: Image.network(
              'https://image.tmdb.org/t/p/original$backdropPath',
              width: double.infinity,
              height: 400,
              fit: BoxFit.cover,
            ),
          ),
        Container(
          height: 400,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Color(0xFF0A0A0A),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (posterPath != null)
                Hero(
                  tag: 'poster_${_tmdbData!['id']}',
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.7),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        'https://image.tmdb.org/t/p/w500$posterPath',
                        width: 120,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 10,
                            color: Colors.black,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                    if (tagline != null && tagline.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '"$tagline"',
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsSection() {
    final releaseDate = _tmdbData!['release_date'] as String?;
    final year = (releaseDate != null && releaseDate.length >= 4) 
        ? releaseDate.substring(0, 4) 
        : 'N/A';
    final runtime = _tmdbData!['runtime'];
    final genres = (_tmdbData!['genres'] as List?)
        ?.map((g) => g['name'] as String)
        .join(' • ') ?? 'N/A';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildInfoPill(Icons.calendar_today, year),
              const SizedBox(width: 12),
              if (runtime != null)
                _buildInfoPill(Icons.access_time, '${runtime}min'),
            ],
          ),
          const SizedBox(height: 20),

          _buildRatingsSection(),
          const SizedBox(height: 24),

          if (_imdbId != null)
            Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade900, Colors.red.shade700],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.shade900.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _launchIMDBTrailer,
                icon: const Icon(Icons.play_circle_filled, size: 32),
                label: const Text(
                  'VIEW ON IMDB',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 32),

          _buildSectionTitle('Genre'),
          const SizedBox(height: 8),
          Text(
            genres,
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('Overview'),
          const SizedBox(height: 12),
          Text(
            _wikiData?['extract'] ?? _tmdbData!['overview'] ?? 'No overview available.',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 16,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),

          _buildAdditionalInfo(),

          if (_cast != null && _cast!.isNotEmpty) ...[
            const SizedBox(height: 32),
            _buildSectionTitle('Cast'),
            const SizedBox(height: 16),
            SizedBox(
              height: 260,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _cast!.length,
                itemBuilder: (context, index) {
                  return _buildCastCard(_cast![index] as Map<String, dynamic>);
                },
              ),
            ),
          ],

          if (_reviews != null && _reviews!.isNotEmpty) ...[
            const SizedBox(height: 32),
            _buildSectionTitle('Top Reviews'),
            const SizedBox(height: 16),
            ..._reviews!.map((review) => 
              _buildReviewCard(review as Map<String, dynamic>)
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildInfoPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.red.shade400),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingsSection() {
    final imdbRating = _movieData?['imdbRating'] as String?;
    final rottenTomatoes = _movieData?['Ratings'] as List?;
    String? rtScore;
    
    if (rottenTomatoes != null) {
      for (var rating in rottenTomatoes) {
        if (rating['Source'] == 'Rotten Tomatoes') {
          rtScore = rating['Value'] as String;
          break;
        }
      }
    }

    // Calculate Popcorn Meter (audience score simulation)
    double popcornScore = 75.0;
    if (imdbRating != null && imdbRating != 'N/A') {
      final imdbValue = double.tryParse(imdbRating) ?? 0;
      popcornScore = (imdbValue * 10 + 5).clamp(0, 100);
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (imdbRating != null && imdbRating != 'N/A')
          _buildRatingCard(
            'IMDb',
            imdbRating,
            '/10',
            Colors.amber.shade600,
            Icons.star,
          ),
        if (rtScore != null)
          _buildRatingCard(
            'Rotten Tomatoes',
            rtScore,
            '',
            Colors.red.shade600,
            Icons.local_movies,
          )
        else
          _buildRatingCard(
            'Rotten Tomatoes',
            'N/A',
            '',
            Colors.red.shade600,
            Icons.local_movies,
          ),
        _buildRatingCard(
          'Popcorn Meter',
          '${popcornScore.toInt()}%',
          '',
          Colors.orange.shade600,
          Icons.movie_filter,
        ),
      ],
    );
  }

  Widget _buildRatingCard(String source, String rating, String suffix, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                rating,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (suffix.isNotEmpty)
                Text(
                  suffix,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            source,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.red.shade600,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalInfo() {
    final director = _movieData?['Director'] as String?;
    final writer = _movieData?['Writer'] as String?;
    final actors = _movieData?['Actors'] as String?;
    final language = _movieData?['Language'] as String?;
    final country = _movieData?['Country'] as String?;
    final awards = _movieData?['Awards'] as String?;
    final budget = _tmdbData!['budget'] as int?;
    final revenue = _tmdbData!['revenue'] as int?;
    final productionCompanies = _tmdbData!['production_companies'] as List?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Details'),
        const SizedBox(height: 16),
        if (director != null && director != 'N/A') ...[
          _buildInfoRow(Icons.person, 'Director', director),
          const SizedBox(height: 12),
        ],
        if (writer != null && writer != 'N/A') ...[
          _buildInfoRow(Icons.edit, 'Writers', writer),
          const SizedBox(height: 12),
        ],
        if (actors != null && actors != 'N/A') ...[
          _buildInfoRow(Icons.people, 'Stars', actors),
          const SizedBox(height: 12),
        ],
        if (language != null && language != 'N/A') ...[
          _buildInfoRow(Icons.language, 'Language', language),
          const SizedBox(height: 12),
        ],
        if (country != null && country != 'N/A') ...[
          _buildInfoRow(Icons.public, 'Country', country),
          const SizedBox(height: 12),
        ],
        if (awards != null && awards != 'N/A' && awards.isNotEmpty) ...[
          _buildInfoRow(Icons.emoji_events, 'Awards', awards),
          const SizedBox(height: 12),
        ],
        if (budget != null && budget > 0) ...[
          _buildInfoRow(
            Icons.attach_money,
            'Budget',
            '\${_formatCurrency(budget)}',
          ),
          const SizedBox(height: 12),
        ],
        if (revenue != null && revenue > 0) ...[
          _buildInfoRow(
            Icons.trending_up,
            'Box Office',
            '\${_formatCurrency(revenue)}',
          ),
          const SizedBox(height: 12),
        ],
        if (productionCompanies != null && productionCompanies.isNotEmpty) ...[
          _buildInfoRow(
            Icons.business,
            'Production',
            productionCompanies.take(2).map((c) => c['name']).join(', '),
          ),
        ],
      ],
    );
  }


  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade900.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.red.shade400, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCastCard(Map<String, dynamic> actor) {
    final name = actor['name'] as String;
    final character = actor['character'] as String;
    final profilePath = actor['profile_path'] as String?;

    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _launchActorWikipedia(name),
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.red.shade900.withValues(alpha: 0.3),
          highlightColor: Colors.red.shade900.withValues(alpha: 0.1),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[800]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Stack(
                    children: [
                      profilePath != null
                          ? Image.network(
                              'https://image.tmdb.org/t/p/w200$profilePath',
                              width: 140,
                              height: 160,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildPlaceholderAvatar();
                              },
                            )
                          : _buildPlaceholderAvatar(),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red.shade900.withValues(alpha: 0.9),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                            ),
                          ),
                          child: const Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        character,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderAvatar() {
    return Container(
      width: 140,
      height: 160,
      color: Colors.grey[850],
      child: Icon(Icons.person, size: 60, color: Colors.grey[700]),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final author = review['author'] as String;
    final content = review['content'] as String;
    final rating = review['author_details']?['rating'];
    final createdAt = review['created_at'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade700, Colors.red.shade900],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      author[0].toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (rating != null)
                        Row(
                          children: [
                            Icon(Icons.star, size: 16, color: Colors.amber.shade600),
                            const SizedBox(width: 4),
                            Text(
                              '$rating/10',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[400],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (createdAt != null) ...[
                              Text(
                                ' • ${_formatDate(createdAt)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade900.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade800),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.thumb_up, size: 14, color: Colors.green.shade400),
                      const SizedBox(width: 4),
                      Text(
                        'Positive',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                content,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays < 30) {
        return '${difference.inDays}d ago';
      } else if (difference.inDays < 365) {
        return '${(difference.inDays / 30).floor()}mo ago';
      } else {
        return '${(difference.inDays / 365).floor()}y ago';
      }
    } catch (e) {
      return 'Recently';
    }
  }
}
