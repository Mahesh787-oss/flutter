import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(MovieMateApp());

class MovieMateApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MovieMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.redAccent,
      ),
      home: MovieHomePage(),
    );
  }
}

class MovieHomePage extends StatefulWidget {
  @override
  _MovieHomePageState createState() => _MovieHomePageState();
}

class _MovieHomePageState extends State<MovieHomePage> {
  final TextEditingController _controller = TextEditingController();
  Map<String, dynamic>? movieData;
  bool isLoading = false;
  String? error;

  Future<void> fetchMovie(String title) async {
    setState(() {
      isLoading = true;
      error = null;
    });

    final url = 'https://www.omdbapi.com/?t=$title&apikey=fe138e9';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['Response'] == 'True') {
        setState(() => movieData = data);
      } else {
        setState(() => error = 'Movie not found!');
      }
    } else {
      setState(() => error = 'Error fetching data.');
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎬 MovieMate'),
        centerTitle: true,
        backgroundColor: Colors.redAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Enter movie name',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.search, color: Colors.redAccent),
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    fetchMovie(_controller.text);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (isLoading)
              const CircularProgressIndicator(color: Colors.redAccent)
            else if (error != null)
              Text(error!, style: const TextStyle(color: Colors.redAccent))
            else if (movieData != null)
              Expanded(
                child: SingleChildScrollView(
                  child: Card(
                    color: Colors.grey[900],
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          if (movieData!['Poster'] != 'N/A')
                            Image.network( // Changed from CachedNetworkImage to Image.network
                              movieData!['Poster'],
                              height: 300,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image, size: 300, color: Colors.grey),
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return SizedBox(
                                  height: 300,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: 16),
                          Text(movieData!['Title'],
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          Text("Year: ${movieData!['Year']}"),
                          Text("Genre: ${movieData!['Genre']}"),
                          Text("⭐ IMDb: ${movieData!['imdbRating']}"),
                          const SizedBox(height: 10),
                          Text(movieData!['Plot'],
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}