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
  bool _showMainPage = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final String omdbApiKey = 'fe138e9';
  final String tmdbApiKey = '889fb29dbf04445ffc3681f089b00f90';

  // OTT platform mapping
  final Map<String, Map<String, String>> _ottPlatforms = {
    'They Call Him OG': {
      'platform': 'Netflix',
      'color': '#E50914',
      'icon': 'assets/netflix.png', // You'll need to add these assets
    },
    'Louis Menkins': {
      'platform': 'Amazon Prime',
      'color': '#00A8E1',
      'icon': 'assets/prime.png',
    },
    // Add more movie-OTT mappings as needed
  };

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

  void _showMainPageInterface() {
    setState(() {
      _showMainPage = true;
      _showingDetails = false;
      _showingSearchResults = false;
      _movieData = null;
      _tmdbData = null;
      _wikiData = null;
      _searchResults = null;
    });
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
      _showMainPage = false;
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
              _showMainPage = false;
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
      _showMainPage = false;
    });

    try {
      await _fetchTMDBDataById(movieId);
      await _fetchOMDBData();
      await _fetchWikipediaData();
      
      setState(() {
        _showingDetails = true;
        _showMainPage = false;
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
      if (_showingDetails) {
        _showingDetails = false;
        _showingSearchResults = _searchResults != null && _searchResults!.isNotEmpty;
        _showMainPage = !_showingSearchResults;
      } else if (_showingSearchResults) {
        _showingSearchResults = false;
        _showMainPage = true;
      }
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
                        : _showMainPage
                            ? _buildMainPageInterface()
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
            // ignore: deprecated_member_use
            Colors.red.shade900.withOpacity(0.3),
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
              GestureDetector(
                onTap: _showMainPageInterface,
                child: Icon(
                  Icons.movie_filter,
                  color: Colors.red.shade400,
                  size: 32,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _showMainPageInterface,
                child: const Text(
                  'CineScope',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: Colors.red.shade900.withOpacity(0.3),
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
          if (!_showingDetails && !_showMainPage) ...[
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(30),
                // ignore: deprecated_member_use
                border: Border.all(color: Colors.red.shade900.withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: Colors.red.shade900.withOpacity(0.3),
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

  Widget _buildMainPageInterface() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    // ignore: deprecated_member_use
                    Colors.red.shade900.withOpacity(0.5),
                    // ignore: deprecated_member_use
                    Colors.red.shade700.withOpacity(0.3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: Colors.red.shade900.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.movie_filter, size: 40, color: Colors.red.shade400),
                      const SizedBox(width: 12),
                      const Text(
                        'CineScope',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your Ultimate Movie Discovery Companion',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Description Section
            _buildSectionTitle('About CineScope'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: Colors.grey[900]!.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: const Text(
                'CineScope is a comprehensive movie discovery app that brings together information from multiple sources including TMDB, IMDb, and Wikipedia. Get detailed information about movies, cast, reviews, ratings, and streaming availability all in one place.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Features Section
            _buildSectionTitle('Key Features'),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildFeatureCard(
                  Icons.search,
                  'Smart Search',
                  'Search across thousands of movies with intelligent suggestions',
                ),
                _buildFeatureCard(
                  Icons.star,
                  'Multi-Source Ratings',
                  'Get ratings from IMDb, Rotten Tomatoes, and more',
                ),
                _buildFeatureCard(
                  Icons.people,
                  'Cast & Crew',
                  'Detailed information about actors and directors',
                ),
                _buildFeatureCard(
                  Icons.stream,
                  'OTT Platform Info',
                  'Find where movies are streaming',
                ),
                _buildFeatureCard(
                  Icons.reviews,
                  'Curated Reviews',
                  'Read the best positive reviews from critics',
                ),
                _buildFeatureCard(
                  Icons.trending_up,
                  'Box Office Data',
                  'Budget, revenue, and financial information',
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Search CTA
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.red.shade900,
                    Colors.red.shade700,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: Colors.red.shade900.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Ready to Explore?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Start searching for your favorite movies and discover new ones',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showMainPage = false;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      'Start Searching',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String description) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.3),
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: Colors.red.shade900.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.red.shade400, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
                height: 1.4,
              ),
            ),
          ],
        ),
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
                      // ignore: deprecated_member_use
                      Colors.red.shade900.withOpacity(0.3),
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
                  _showMainPage = true;
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
          // ignore: deprecated_member_use
          Icon(Icons.movie_filter, size: 120, color: Colors.red.shade900.withOpacity(0.5)),
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
            // ignore: deprecated_member_use
            color: Colors.red.shade900.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            // ignore: deprecated_member_use
            border: Border.all(color: Colors.red.shade900.withOpacity(0.5)),
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
            // ignore: deprecated_member_use
            Colors.grey[900]!.withOpacity(0.5),
            // ignore: deprecated_member_use
            Colors.grey[900]!.withOpacity(0.3),
          ],
        ),
        border: Border.all(color: Colors.grey[800]!),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.5),
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
          // ignore: deprecated_member_use
          splashColor: Colors.red.shade900.withOpacity(0.3),
          // ignore: deprecated_member_use
          highlightColor: Colors.red.shade900.withOpacity(0.1),
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
                          // ignore: deprecated_member_use
                          color: Colors.black.withOpacity(0.7),
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
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (tagline != null && tagline.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        tagline,
                        style: TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[400],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildRatingSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSection() {
    final tmdbRating = _tmdbData!['vote_average'] as num?;
    final imdbRating = _movieData?['imdbRating'] as String?;
    final voteCount = _tmdbData!['vote_count'] as num?;

    return Row(
      children: [
        if (tmdbRating != null) ...[
          _buildRatingChip(
            'TMDB',
            tmdbRating.toStringAsFixed(1),
            Colors.blue,
            voteCount != null ? '${voteCount} votes' : null,
          ),
          const SizedBox(width: 12),
        ],
        if (imdbRating != null && imdbRating != 'N/A') ...[
          _buildRatingChip(
            'IMDb',
            imdbRating,
            Colors.amber,
          ),
          const SizedBox(width: 12),
        ],
        // Add OTT platform chip if available
        if (_ottPlatforms.containsKey(_tmdbData!['title'] as String)) ...[
          _buildOTTPlatformChip(),
        ],
      ],
    );
  }

  Widget _buildOTTPlatformChip() {
    final movieTitle = _tmdbData!['title'] as String;
    final ottInfo = _ottPlatforms[movieTitle]!;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Color(int.parse(ottInfo['color']!.substring(1), radix: 16)).withAlpha(255),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_circle_fill, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            ottInfo['platform']!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingChip(String label, String rating, Color color, [String? subtitle]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        // ignore: deprecated_member_use
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.star, color: color, size: 14),
              Text(
                rating,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                // ignore: deprecated_member_use
                color: color.withOpacity(0.8),
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMovieInfoRow(),
          const SizedBox(height: 24),
          _buildOverviewSection(),
          const SizedBox(height: 24),
          _buildCastSection(),
          const SizedBox(height: 24),
          _buildReviewsSection(),
          const SizedBox(height: 24),
          _buildWikiDataSection(),
          const SizedBox(height: 24),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildMovieInfoRow() {
    final releaseDate = _tmdbData!['release_date'] as String?;
    final runtime = _tmdbData!['runtime'] as num?;
    final genres = _tmdbData!['genres'] as List<dynamic>?;
    final budget = _tmdbData!['budget'] as num?;
    final revenue = _tmdbData!['revenue'] as num?;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (releaseDate != null && releaseDate.isNotEmpty) ...[
          _buildInfoChip(Icons.calendar_today, '${releaseDate.substring(0, 4)}'),
        ],
        if (runtime != null && runtime > 0) ...[
          _buildInfoChip(Icons.schedule, '${runtime} min'),
        ],
        if (genres != null && genres.isNotEmpty) ...[
          ...genres.take(3).map((genre) {
            return _buildInfoChip(Icons.category, genre['name'] as String);
          }).toList(),
        ],
        if (budget != null && budget > 0) ...[
          _buildInfoChip(Icons.attach_money, '\$${(budget / 1000000).toStringAsFixed(1)}M'),
        ],
        if (revenue != null && revenue > 0) ...[
          _buildInfoChip(Icons.trending_up, '\$${(revenue / 1000000).toStringAsFixed(1)}M'),
        ],
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.red.shade400),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewSection() {
    final overview = _tmdbData!['overview'] as String?;
    
    if (overview == null || overview.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Overview'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: Colors.grey[900]!.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: Text(
            overview,
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCastSection() {
    if (_cast == null || _cast!.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Cast'),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _cast!.length,
            itemBuilder: (context, index) {
              final actor = _cast![index] as Map<String, dynamic>;
              return _buildCastCard(actor);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCastCard(Map<String, dynamic> actor) {
    final name = actor['name'] ?? 'Unknown';
    final character = actor['character'] ?? 'Unknown';
    final profilePath = actor['profile_path'] as String?;

    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _launchActorWikipedia(name),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red.shade900, width: 2),
              ),
              child: ClipOval(
                child: profilePath != null
                    ? Image.network(
                        'https://image.tmdb.org/t/p/w200$profilePath',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholderAvatar(name);
                        },
                      )
                    : _buildPlaceholderAvatar(name),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            character,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[400],
            ),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderAvatar(String name) {
    return Container(
      color: Colors.grey[800],
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildReviewsSection() {
    if (_reviews == null || _reviews!.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Top Reviews'),
        const SizedBox(height: 12),
        Column(
          children: _reviews!.map((review) {
            return _buildReviewCard(review as Map<String, dynamic>);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final author = review['author'] ?? 'Anonymous';
    final content = review['content'] ?? '';
    final rating = review['author_details']?['rating'] as num?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Colors.grey[900]!.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  author,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (rating != null) ...[
                Icon(Icons.star, color: Colors.amber.shade600, size: 16),
                const SizedBox(width: 4),
                Text(
                  rating.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.amber.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
              height: 1.4,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildWikiDataSection() {
    if (_wikiData == null) return const SizedBox.shrink();

    final extract = _wikiData!['extract'] as String?;
    final budgetStr = _wikiData!['budget_str'] as String?;
    final revenueStr = _wikiData!['revenue_str'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Wikipedia Info'),
        const SizedBox(height: 12),
        if (extract != null && extract.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: Colors.grey[900]!.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: Text(
              extract,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (budgetStr != null || revenueStr != null) ...[
          Row(
            children: [
              if (budgetStr != null) ...[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      // ignore: deprecated_member_use
                      color: Colors.blue.shade900.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade800),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Budget',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade400,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          budgetStr,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (revenueStr != null) ...[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      // ignore: deprecated_member_use
                      color: Colors.green.shade900.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade800),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Box Office',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade400,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          revenueStr,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _launchIMDBTrailer,
            icon: const Icon(Icons.play_arrow),
            label: const Text('View on IMDb'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Search'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.grey[700]!),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          height: 24,
          width: 4,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.red.shade400,
                Colors.red.shade900,
              ],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
