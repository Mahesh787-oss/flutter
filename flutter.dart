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
        cardTheme: CardThemeData(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const WelcomeScreen(),
    );
  }
}

// Welcome Screen with App Features
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

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
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            // FIX: Wrap the Column in a SingleChildScrollView to prevent overflow
            child: SingleChildScrollView( 
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.red.shade900.withAlpha(77),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.movie_filter,
                      size: 100,
                      color: Colors.red.shade400,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // App Name
                  const Text(
                    'CineScope',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Tagline
                  Text(
                    'Your Complete Movie Database',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[400],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Features List
                  _buildFeature(Icons.star_rate, 'Multiple Ratings', 'IMDb, Rotten Tomatoes & Popcorn Meter'),
                  const SizedBox(height: 16),
                  _buildFeature(Icons.play_circle_outline, 'IMDb Integration', 'Direct links to trailers & full details'),
                  const SizedBox(height: 16),
                  _buildFeature(Icons.people_alt, 'Cast Information', 'Complete cast with Wikipedia links'),
                  const SizedBox(height: 16),
                  _buildFeature(Icons.rate_review, 'Top Reviews', 'Curated positive user reviews'),
                  const SizedBox(height: 16),
                  _buildFeature(Icons.info, 'Detailed Info', 'Budget, box office, awards & more'),
                  
                  const SizedBox(height: 48),
                  
                  // Get Started Button
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
                          color: Colors.red.shade900.withAlpha(128),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute<void>(
                            builder: (context) => const MovieSearchScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'GET STARTED',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeature(IconData icon, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withAlpha(77)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade700, Colors.red.shade900],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  void _goToHome() {
    setState(() {
      _showingDetails = false;
      _showingSearchResults = false;
      _movieData = null;
      _tmdbData = null;
      _wikiData = null;
      _cast = null;
      _reviews = null;
      _imdbId = null;
      _searchResults = null;
      _errorMessage = null;
      _searchController.clear();
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
    });

    try {
      final searchResponse = await http.get(
        Uri.parse(
            'https://api.themoviedb.org/3/search/movie?api_key=$tmdbApiKey&query=${Uri.encodeComponent(movieName)}'),
      ).timeout(const Duration(seconds: 10));

      if (searchResponse.statusCode == 200) {
        final Map<String, dynamic> searchData = json.decode(searchResponse.body) as Map<String, dynamic>;
        if (searchData['results'] != null && (searchData['results'] as List).isNotEmpty) {
          final List<dynamic> results = searchData['results'] as List<dynamic>;
          
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
      } else {
         setState(() {
          _errorMessage = 'Failed to fetch search results. Status code: ${searchResponse.statusCode}';
        });
      }
    } on http.ClientException catch (e) {
      setState(() {
        _errorMessage = 'Network error: ${e.message}. Please check your internet connection.';
      });
    } on FormatException catch (e) {
      setState(() {
        _errorMessage = 'Data format error: ${e.message}. Unexpected response from server.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: $e';
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
      _errorMessage = null; // Clear any previous error
    });

    try {
      await _fetchTMDBDataById(movieId);
      if (_tmdbData == null) {
        setState(() {
          _errorMessage = 'Failed to fetch TMDB data for this movie.';
        });
        return;
      }
      await _fetchOMDBData();
      await _fetchWikipediaData();
      
      setState(() {
        _showingDetails = true;
      });
      _animationController.forward(from: 0);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading movie details: $e';
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
        final Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;
        if (data['Response'] == 'True') {
          setState(() {
            _movieData = data;
          });
        }
      }
    } on http.ClientException catch (e) {
      print('OMDB Network Error: ${e.message}');
    } on FormatException catch (e) {
      print('OMDB Data Format Error: ${e.message}');
    } catch (e) {
      print('OMDB Error: $e');
    }
  }

  Future<void> _fetchWikipediaData() async {
    if (_tmdbData == null) return;
    
    final String movieTitle = _tmdbData!['title'] as String;
    final String year = (_tmdbData!['release_date'] as String?)?.substring(0, 4) ?? '';
    
    try {
      final List<String> searchQueries = [
        '$movieTitle ($year film)',
        '$movieTitle film',
        movieTitle,
      ];
      
      for (final String query in searchQueries) {
        try {
          final Uri searchUrl = Uri.https(
            'en.wikipedia.org',
            '/w/api.php',
            <String, dynamic>{
              'action': 'opensearch',
              'search': query,
              'limit': '3',
              'format': 'json',
              'origin': '*',
            },
          );
          
          final http.Response searchResponse = await http.get(
            searchUrl,
            headers: <String, String>{
              'User-Agent': 'CineScope/1.0',
              'Accept': 'application/json',
            },
          ).timeout(const Duration(seconds: 10));
          
          if (searchResponse.statusCode == 200) {
            final List<dynamic> searchData = json.decode(searchResponse.body) as List<dynamic>;
            if (searchData[1] != null && (searchData[1] as List).isNotEmpty) {
              final String pageTitle = searchData[1][0] as String;
              
              final Uri contentUrl = Uri.https(
                'en.wikipedia.org',
                '/w/api.php',
                <String, dynamic>{
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
              
              final http.Response contentResponse = await http.get(
                contentUrl,
                headers: <String, String>{
                  'User-Agent': 'CineScope/1.0',
                  'Accept': 'application/json',
                },
              ).timeout(const Duration(seconds: 10));
              
              if (contentResponse.statusCode == 200) {
                final Map<String, dynamic> contentData = json.decode(contentResponse.body) as Map<String, dynamic>;
                final Map<String, dynamic> pages = contentData['query']['pages'] as Map<String, dynamic>;
                final Map<String, dynamic> pageData = pages.values.first as Map<String, dynamic>;
                
                if (pageData['extract'] != null && (pageData['extract'] as String).isNotEmpty) {
                  String? budgetStr;
                  String? revenueStr;
                  
                  if (pageData['revisions'] != null) {
                    final List<dynamic> revisions = pageData['revisions'] as List<dynamic>;
                    if (revisions.isNotEmpty) {
                      final String? content = revisions[0]['*'] as String?;
                      if (content != null) {
                        final RegExpMatch? budgetMatch = RegExp(r'\|\s*budget\s*=\s*([^\n\|]+)', caseSensitive: false).firstMatch(content);
                        if (budgetMatch != null) {
                          budgetStr = _cleanWikiValue(budgetMatch.group(1) ?? '');
                        }
                        
                        final RegExpMatch? revenueMatch = RegExp(r'\|\s*(?:box[\s_]office|gross)\s*=\s*([^\n\|]+)', caseSensitive: false).firstMatch(content);
                        if (revenueMatch != null) {
                          revenueStr = _cleanWikiValue(revenueMatch.group(1) ?? '');
                        }
                      }
                    }
                  }
                  
                  setState(() {
                    _wikiData = <String, dynamic>{
                      ...pageData,
                      'budget_str': budgetStr,
                      'revenue_str': revenueStr,
                    };
                  });
                  return;
                }
              }
            }
          }
        } on http.ClientException catch (e) {
          print('Wikipedia search attempt failed for "$query" (Network Error): ${e.message}');
          continue;
        } on FormatException catch (e) {
          print('Wikipedia search attempt failed for "$query" (Data Format Error): ${e.message}');
          continue;
        } catch (e) {
          print('Wikipedia search attempt failed for "$query": $e');
          continue;
        }
      }
    } on http.ClientException catch (e) {
      print('Wikipedia Network Error: ${e.message}');
    } on FormatException catch (e) {
      print('Wikipedia Data Format Error: ${e.message}');
    } catch (e) {
      print('Wikipedia General Error: $e');
    }
  }

  String _cleanWikiValue(String value) {
    return value
        .replaceAll(RegExp(r'\[\[(?:[^|\]]+\|)?([^\]]+)\]\]'), r'$1') // Handle [[link|text]] and [[link]]
        .replaceAll(RegExp(r'\{\{[^\}]+\}\}'), '') // Remove templates like {{cite web}}
        .replaceAll(RegExp(r'<ref[^>]*>.*?</ref>', caseSensitive: false, dotAll: true), '') // Remove <ref> tags
        .replaceAll(RegExp(r'<[^>]+>'), '') // Remove other HTML tags
        .replaceAll(RegExp(r'\[\d+\]'), '') // Remove reference numbers like [1]
        .replaceAll(RegExp(r'&nbsp;'), ' ') // Replace non-breaking space
        .trim();
  }

  Future<bool> _fetchTMDBDataById(int movieId) async {
    try {
      final http.Response detailsResponse = await http.get(
        Uri.parse('https://api.themoviedb.org/3/movie/$movieId?api_key=$tmdbApiKey'),
      ).timeout(const Duration(seconds: 10));
      
      final http.Response creditsResponse = await http.get(
        Uri.parse('https://api.themoviedb.org/3/movie/$movieId/credits?api_key=$tmdbApiKey'),
      ).timeout(const Duration(seconds: 10));
      
      final http.Response reviewsResponse = await http.get(
        Uri.parse('https://api.themoviedb.org/3/movie/$movieId/reviews?api_key=$tmdbApiKey'),
      ).timeout(const Duration(seconds: 10));

      if (detailsResponse.statusCode != 200 || creditsResponse.statusCode != 200 || reviewsResponse.statusCode != 200) {
        print('TMDB API call failed with status codes: ${detailsResponse.statusCode}, ${creditsResponse.statusCode}, ${reviewsResponse.statusCode}');
        return false;
      }

      final Map<String, dynamic> details = json.decode(detailsResponse.body) as Map<String, dynamic>;
      final Map<String, dynamic> creditsData = json.decode(creditsResponse.body) as Map<String, dynamic>;
      final Map<String, dynamic> reviewsData = json.decode(reviewsResponse.body) as Map<String, dynamic>;
      
      setState(() {
        _tmdbData = details;
        _cast = (creditsData['cast'] as List<dynamic>?)?.take(15).toList();
        
        final List<dynamic>? allReviews = reviewsData['results'] as List<dynamic>?;
        if (allReviews != null) {
          _reviews = allReviews.where((review) {
            final dynamic rating = (review as Map<String, dynamic>)['author_details']?['rating'];
            return rating is num && rating >= 7;
          }).take(5).toList();
        }
      });
      
      return true;
    } on http.ClientException catch (e) {
      print('TMDB Network Error: ${e.message}');
      return false;
    } on FormatException catch (e) {
      print('TMDB Data Format Error: ${e.message}');
      return false;
    } catch (e) {
      print('TMDB Error: $e');
      return false;
    }
  }

  String _formatCurrency(int amount) {
    if (amount == 0) return 'N/A';
    final double inr = amount * 83.0; // Assuming 1 USD = 83 INR for conversion
    final double crores = inr / 10000000;
    
    if (crores >= 1000) {
      return '₹${(crores / 1000).toStringAsFixed(1)}k cr';
    } else if (crores >= 100) {
      return '₹${crores.toStringAsFixed(0)} crore';
    } else if (crores >= 1) {
      return '₹${crores.toStringAsFixed(1)} crore';
    } else {
      final double lakhs = inr / 100000;
      return '₹${lakhs.toStringAsFixed(1)} lakh';
    }
  }

  Future<void> _launchIMDBTrailer() async {
    if (_imdbId != null) {
      final Uri url = Uri.parse('https://www.imdb.com/title/$_imdbId/');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        print('Could not launch $url');
      }
    }
  }

  Future<void> _launchActorWikipedia(String actorName) async {
    try {
      final Uri searchUrl = Uri.https(
        'en.wikipedia.org',
        '/w/api.php',
        <String, dynamic>{
          'action': 'opensearch',
          'search': actorName,
          'limit': '1',
          'format': 'json',
          'origin': '*',
        },
      );
      
      final http.Response response = await http.get(
        searchUrl,
        headers: <String, String>{
          'User-Agent': 'CineScope/1.0',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body) as List<dynamic>;
        if (data[3] != null && (data[3] as List).isNotEmpty) {
          final Uri wikiUrl = Uri.parse(data[3][0] as String);
          if (await canLaunchUrl(wikiUrl)) {
            await launchUrl(wikiUrl, mode: LaunchMode.externalApplication);
          } else {
            print('Could not launch $wikiUrl');
          }
        }
      }
    } on http.ClientException catch (e) {
      print('Error launching Wikipedia (Network Error): ${e.message}');
    } on FormatException catch (e) {
      print('Error launching Wikipedia (Data Format Error): ${e.message}');
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
            children: <Widget>[
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
            Colors.red.shade900.withAlpha(77),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              if (_showingDetails || _showingSearchResults)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: _showingDetails ? _goBack : _goToHome,
                )
              else
                Icon(
                  Icons.movie_filter,
                  color: Colors.red.shade400,
                  size: 32,
                ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _goToHome,
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
                  color: Colors.red.shade900.withAlpha(77),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.shade800),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.local_movies, size: 16, color: Colors.red.shade400),
                    const SizedBox(width: 4),
                    const Text('PRO', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          if (!_showingDetails) ...<Widget>[
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(77),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.red.shade900.withAlpha(128)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.red.shade900.withAlpha(77),
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
                onChanged: (String value) => setState(() {}),
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
        children: <Widget>[
          Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.red.shade900.withAlpha(77),
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
          children: <Widget>[
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
        children: <Widget>[
          Icon(Icons.movie_filter, size: 120, color: Colors.red.shade900.withAlpha(128)),
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
    if (_searchResults == null || _searchResults!.isEmpty) {
      return const Center(child: Text('No search results found.'));
    }
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade900.withAlpha(51),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade900.withAlpha(128)),
          ),
          child: Row(
            children: <Widget>[
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
            itemBuilder: (BuildContext context, int index) {
              final Map<String, dynamic> movie = _searchResults![index] as Map<String, dynamic>;
              return _buildSearchResultCard(movie);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultCard(Map<String, dynamic> movie) {
    final String title = movie['title'] as String? ?? 'Unknown';
    final String? releaseDate = movie['release_date'] as String?;
    final String year = (releaseDate != null && releaseDate.length >= 4) 
        ? releaseDate.substring(0, 4) 
        : 'N/A';
    final String overview = movie['overview'] as String? ?? 'No description available';
    final String? posterPath = movie['poster_path'] as String?;
    final num? rating = movie['vote_average'] as num?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: <Color>[
            Colors.grey[900]!.withAlpha(128),
            Colors.grey[900]!.withAlpha(77),
          ],
        ),
        border: Border.all(color: Colors.grey[800]!),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withAlpha(128),
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
          splashColor: Colors.red.shade900.withAlpha(77),
          highlightColor: Colors.red.shade900.withAlpha(26),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
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
                            errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
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
                    children: <Widget>[
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
                        children: <Widget>[
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
                          if (rating != null) ...<Widget>[
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
          children: <Widget>[
            _buildHeroSection(),
            _buildDetailsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    final String? backdropPath = _tmdbData!['backdrop_path'] as String?;
    final String? posterPath = _tmdbData!['poster_path'] as String?;
    final String title = _tmdbData!['title'] as String? ?? 'Unknown';
    final String? tagline = _tmdbData!['tagline'] as String?;

    return Stack(
      children: <Widget>[
        if (backdropPath != null)
          ShaderMask(
            shaderCallback: (Rect rect) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Colors.transparent, Color(0xFF0A0A0A)],
                stops: <double>[0.3, 1.0],
              ).createShader(rect);
            },
            blendMode: BlendMode.dstIn,
            child: Image.network(
              'https://image.tmdb.org/t/p/original$backdropPath',
              width: double.infinity,
              height: 400,
              fit: BoxFit.cover,
               errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                return Container(
                  width: double.infinity,
                  height: 400,
                  color: Colors.grey[900],
                  child: Icon(Icons.broken_image, size: 80, color: Colors.grey[700]),
                );
              },
            ),
          ),
        Container(
          height: 400,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
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
            children: <Widget>[
              if (posterPath != null)
                Hero(
                  tag: 'poster_${_tmdbData!['id']}',
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withAlpha(179),
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
                        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                          return _buildPlaceholderPoster();
                        },
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: <Shadow>[
                          Shadow(
                            blurRadius: 10,
                            color: Colors.black,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                    if (tagline != null && tagline.isNotEmpty) ...<Widget>[
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
    final String? releaseDate = _tmdbData!['release_date'] as String?;
    final String year = (releaseDate != null && releaseDate.length >= 4) 
        ? releaseDate.substring(0, 4) 
        : 'N/A';
    final int? runtime = _tmdbData!['runtime'] as int?;
    final String genres = (_tmdbData!['genres'] as List<dynamic>?)
        ?.map<String>((dynamic g) => (g as Map<String, dynamic>)['name'] as String)
        .join(' • ') ?? 'N/A';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
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
                  colors: <Color>[Colors.red.shade900, Colors.red.shade700],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.red.shade900.withAlpha(128),
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
            _wikiData?['extract'] as String? ?? _tmdbData!['overview'] as String? ?? 'No overview available.',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 16,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),

          _buildAdditionalInfo(),

          if (_cast != null && _cast!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 32),
            _buildSectionTitle('Cast'),
            const SizedBox(height: 16),
            SizedBox(
              height: 260,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _cast!.length,
                itemBuilder: (BuildContext context, int index) {
                  return _buildCastCard(_cast![index] as Map<String, dynamic>);
                },
              ),
            ),
          ],

          if (_reviews != null && _reviews!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 32),
            _buildSectionTitle('Top Reviews'),
            const SizedBox(height: 16),
            ..._reviews!.map<Widget>((dynamic review) => // Explicitly type map to Widget
              _buildReviewCard(review as Map<String, dynamic>)
            ).toList(), // Convert to List<Widget>
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
        children: <Widget>[
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
    final String? imdbRating = _movieData?['imdbRating'] as String?;
    final List<dynamic>? rottenTomatoes = _movieData?['Ratings'] as List<dynamic>?;
    String? rtScore;
    
    if (rottenTomatoes != null) {
      for (dynamic rating in rottenTomatoes) {
        final Map<String, dynamic> ratingMap = rating as Map<String, dynamic>;
        if (ratingMap['Source'] == 'Rotten Tomatoes') {
          rtScore = ratingMap['Value'] as String;
          break;
        }
      }
    }

    double popcornScore = 75.0; // Default or fallback score
    if (imdbRating != null && imdbRating != 'N/A') {
      final double? imdbValue = double.tryParse(imdbRating.split('/')[0]); // Take only the rating part
      if (imdbValue != null) {
        popcornScore = (imdbValue * 10).clamp(0, 100);
      }
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        if (imdbRating != null && imdbRating != 'N/A')
          _buildRatingCard(
            'IMDb',
            imdbRating.split('/')[0], // Display only the score, not /10
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
        border: Border.all(color: color.withAlpha(128)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withAlpha(51),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
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
      children: <Widget>[
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
    final String? director = _movieData?['Director'] as String?;
    final String? writer = _movieData?['Writer'] as String?;
    final String? actors = _movieData?['Actors'] as String?;
    final String? language = _movieData?['Language'] as String?;
    final String? country = _movieData?['Country'] as String?;
    final String? awards = _movieData?['Awards'] as String?;
    final int? budget = _tmdbData!['budget'] as int?;
    final int? revenue = _tmdbData!['revenue'] as int?;
    final List<dynamic>? productionCompanies = _tmdbData!['production_companies'] as List<dynamic>?;
    
    final String? wikiBudget = _wikiData?['budget_str'] as String?;
    final String? wikiRevenue = _wikiData?['revenue_str'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildSectionTitle('Details'),
        const SizedBox(height: 16),
        if (director != null && director != 'N/A') ...<Widget>[
          _buildInfoRow(Icons.person, 'Director', director),
          const SizedBox(height: 12),
        ],
        if (writer != null && writer != 'N/A') ...<Widget>[
          _buildInfoRow(Icons.edit, 'Writers', writer),
          const SizedBox(height: 12),
        ],
        if (actors != null && actors != 'N/A') ...<Widget>[
          _buildInfoRow(Icons.people, 'Stars', actors),
          const SizedBox(height: 12),
        ],
        if (language != null && language != 'N/A') ...<Widget>[
          _buildInfoRow(Icons.language, 'Language', language),
          const SizedBox(height: 12),
        ],
        if (country != null && country != 'N/A') ...<Widget>[
          _buildInfoRow(Icons.public, 'Country', country),
          const SizedBox(height: 12),
        ],
        if (awards != null && awards != 'N/A' && awards.isNotEmpty) ...<Widget>[
          _buildInfoRow(Icons.emoji_events, 'Awards', awards),
          const SizedBox(height: 12),
        ],
        if (wikiBudget != null && wikiBudget.isNotEmpty) ...<Widget>[
          _buildInfoRow(Icons.attach_money, 'Budget', wikiBudget),
          const SizedBox(height: 12),
        ] else if (budget != null && budget > 0) ...<Widget>[
          _buildInfoRow(Icons.attach_money, 'Budget', _formatCurrency(budget)),
          const SizedBox(height: 12),
        ],
        if (wikiRevenue != null && wikiRevenue.isNotEmpty) ...<Widget>[
          _buildInfoRow(Icons.trending_up, 'Box Office', wikiRevenue),
          const SizedBox(height: 12),
        ] else if (revenue != null && revenue > 0) ...<Widget>[
          _buildInfoRow(Icons.trending_up, 'Box Office', _formatCurrency(revenue)),
          const SizedBox(height: 12),
        ],
        if (productionCompanies != null && productionCompanies.isNotEmpty) ...<Widget>[
          _buildInfoRow(
            Icons.business,
            'Production',
            productionCompanies.take(2).map<String>((dynamic c) => (c as Map<String, dynamic>)['name'] as String).join(', '),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withAlpha(128),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade900.withAlpha(77),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.red.shade400, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
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
    final String name = actor['name'] as String;
    final String character = actor['character'] as String;
    final String? profilePath = actor['profile_path'] as String?;

    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _launchActorWikipedia(name),
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.red.shade900.withAlpha(77),
          highlightColor: Colors.red.shade900.withAlpha(26),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[800]!),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withAlpha(77),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: <Widget>[
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Stack(
                    children: <Widget>[
                      profilePath != null
                          ? Image.network(
                              'https://image.tmdb.org/t/p/w200$profilePath',
                              width: 140,
                              height: 160,
                              fit: BoxFit.cover,
                              errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
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
                            color: Colors.red.shade900.withAlpha(230),
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
                    children: <Widget>[
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
    final String author = review['author'] as String;
    final String content = review['content'] as String;
    final dynamic rating = review['author_details']?['rating'];
    final String? createdAt = review['created_at'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withAlpha(77),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[Colors.red.shade700, Colors.red.shade900],
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
                    children: <Widget>[
                      Text(
                        author,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (rating != null)
                        Row(
                          children: <Widget>[
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
                            if (createdAt != null) ...<Widget>[
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
                    color: Colors.green.shade900.withAlpha(77),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade800),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
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
                color: Colors.black.withAlpha(77),
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
      final DateTime date = DateTime.parse(dateString);
      final DateTime now = DateTime.now();
      final Duration difference = now.difference(date);

      if (difference.inDays < 1) {
        return 'Today';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else if (difference.inDays < 30) {
        return '${(difference.inDays / 7).floor()}w ago';
      } else if (difference.inDays < 365) {
        return '${(difference.inDays / 30).floor()}mo ago';
      } else {
        return '${(difference.inDays / 365).floor()}y ago';
      }
    } catch (e) {
      return dateString.split('T')[0]; // Fallback to YYYY-MM-DD
    }
  }
}
