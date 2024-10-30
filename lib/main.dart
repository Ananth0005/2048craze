import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initializeUnityAds();
  runApp(const MyApp());
}

// Initialize Unity Ads
void initializeUnityAds() {
  UnityAds.init(
    gameId: Platform.isAndroid 
      ? '5721951'  // Replace with your Android Game ID
      : '5721950',     // Replace with your iOS Game ID
    testMode: false,             // Set to false for production
    onComplete: () => print('Unity Ads Initialization Complete'),
    onFailed: (error, message) => print('Unity Ads Initialization Failed: $message'),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Color(0xFFFAF8EF),
      ),
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.7, curve: Curves.easeInOut),
      ),
    );

    _controller.forward();

    // Navigate to main game after animation
    Future.delayed(Duration(milliseconds: 2500), () {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: Duration(milliseconds: 500),
          pageBuilder: (_, __, ___) => Game2048(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    });
  }

  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAF8EF),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo/Title
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Color(0xFF776E65),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            offset: Offset(0, 4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Center(
                          child:Container(
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/just_merge_logo.png'),
                              repeat: ImageRepeat.repeat,
                            ),
                          ),
                        )
                      ),
                    ),
                    SizedBox(height: 24),
                    // Loading indicator
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF776E65)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}


class Game2048 extends StatefulWidget {
  @override
  _Game2048State createState() => _Game2048State();
}

// Unity Ads configuration
class AdsHelper {
  static const String _bannerAdPlacementId = 'Banner_Android';       // Replace with your Banner placement ID
  static const String _interstitialAdPlacementId = 'Interstitial_Android'; // Replace with your Interstitial placement ID

  static String get bannerAdPlacementId => _bannerAdPlacementId;
  static String get interstitialAdPlacementId => _interstitialAdPlacementId;
}

class _Game2048State extends State<Game2048> {
  late List<List<int>> grid;
  int score = 0;
  int highScore = 0;
  bool gameOver = false;

  // Add new state variable to track available free reverts
  int freeReverts = 1;  // Start with one free revert
   // Add state history for revert functionality
  List<Map<String, dynamic>> gameHistory = [];

  bool _isInterstitialAdLoaded = false;

  @override
  void initState() {
    super.initState();
    freeReverts = 1;
    _loadInterstitialAd();
    _loadHighScore(); 
    startNewGame();
  }

      // Load high score from SharedPreferences
  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      highScore = prefs.getInt('highScore') ?? 0;
    });
  }
  // Save high score to SharedPreferences
  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('highScore', highScore);
  }

  void _loadInterstitialAd() {
    UnityAds.load(
      placementId: AdsHelper.interstitialAdPlacementId,
      onComplete: (placementId) {
        print('Interstitial Ad Load Complete');
        setState(() {
          _isInterstitialAdLoaded = true;
        });
      },
      onFailed: (placementId, error, message) {
        print('Interstitial Ad Load Failed: $message');
        // Retry loading after failure
        Future.delayed(Duration(seconds: 30), _loadInterstitialAd);
      },
    );
  }

  void _showInterstitialAd(VoidCallback onComplete) {
    if (_isInterstitialAdLoaded) {
      UnityAds.showVideoAd(
        placementId: AdsHelper.interstitialAdPlacementId,
        onComplete: (placementId) {
          print('Interstitial Ad Show Complete');
          _loadInterstitialAd(); // Load the next ad
          onComplete();
        },
        onFailed: (placementId, error, message) {
          print('Interstitial Ad Show Failed: $message');
          onComplete();
        },
        onStart: (placementId) => print('Interstitial Ad Started'),
        onClick: (placementId) => print('Interstitial Ad Clicked'),
      );
      _isInterstitialAdLoaded = false;
    } else {
      onComplete();
    }
  }

  void _showAd() {
    _showInterstitialAd(() {
      _showGameOverDialog();
    });
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Game Over!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Score: $score'),
            Text('High Score: $highScore'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                startNewGame();
              });
            },
            child: Text('Play Again'),
          ),
          IconButton(
            icon: Icon(Icons.undo, color: Colors.brown[400]),
            onPressed: gameHistory.length < 2 ? null : revertMove,
          ),
        ],
      ),
    );
  }

  void startNewGame() {
    setState(() {
      freeReverts = 1;  // Reset free reverts on new game
      grid = List.generate(4, (_) => List.filled(4, 0));
      score = 0;
      gameOver = false;
      gameHistory.clear();
      addNewTile();
      addNewTile();
      _saveGameState();
    });
  }

  // Save current game state to history
  void _saveGameState() {
    gameHistory.add({
      'grid': List.generate(4, (i) => List.from(grid[i])),
      'score': score,
    });
    // Keep only last 5 moves to manage memory
    if (gameHistory.length > 5) {
      gameHistory.removeAt(0);
    }
  }

  void revertMove() {
    if (gameHistory.length < 2) return;

    if (freeReverts > 0) {
      _executeRevert();
      setState(() {
        freeReverts--;
      });
    } else if (_isInterstitialAdLoaded) {
      _showInterstitialAd(() {
        _executeRevert();
      });
    }
  }

  // Helper method to execute the revert
  void _executeRevert() {
    // First pop any open dialogs
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    
    // Remove current state and get previous state
    gameHistory.removeLast();
    final previousState = gameHistory.last;
    
    setState(() {
      grid = List.generate(4, (i) => List.from(previousState['grid'][i]));
      score = previousState['score'];
      gameOver = false;
    });
  }

  Color getTileColor(int value) {
    switch (value) {
      case 2:
        return Color(0xFFEEE4DA);
      case 4:
        return Color(0xFFEDE0C8);
      case 8:
        return Color(0xFFF2B179);
      case 16:
        return Color(0xFFF59563);
      case 32:
        return Color(0xFFF67C5F);
      case 64:
        return Color(0xFFF65E3B);
      case 128:
        return Color(0xFFEDCF72);
      case 256:
        return Color(0xFFEDCC61);
      case 512:
        return Color(0xFFEDC850);
      case 1024:
        return Color(0xFFEDC53F);
      case 2048:
        return Color(0xFFEDC22E);
      default:
        return Color(0xFFCDC1B4);
    }
  }

  Color getTileTextColor(int value) {
    return value <= 4 ? Color(0xFF776E65) : Colors.white;
  }

  void addNewTile() {
    List<Point<int>> emptyTiles = [];
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        if (grid[i][j] == 0) {
          emptyTiles.add(Point(i, j));
        }
      }
    }

    if (emptyTiles.isEmpty) return;

    final random = Random();
    final Point<int> randomTile = emptyTiles[random.nextInt(emptyTiles.length)];
    grid[randomTile.x][randomTile.y] = random.nextInt(10) < 9 ? 2 : 4;
  }

  bool canMove() {
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        if (grid[i][j] == 0) return true;
        if (i < 3 && grid[i][j] == grid[i + 1][j]) return true;
        if (j < 3 && grid[i][j] == grid[i][j + 1]) return true;
      }
    }
    return false;
  }

  List<List<int>> rotateGrid(List<List<int>> grid, bool clockwise) {
    List<List<int>> newGrid = List.generate(4, (_) => List.filled(4, 0));
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        if (clockwise) {
          newGrid[j][3 - i] = grid[i][j];
        } else {
          newGrid[3 - j][i] = grid[i][j];
        }
      }
    }
    return newGrid;
  }

  void move(Direction direction) {
    if (gameOver) return;

    bool moved = false;
    List<List<int>> newGrid =
        List.generate(4, (i) => List.generate(4, (j) => grid[i][j]));

    // Rotate grid to always process left-to-right
    switch (direction) {
      case Direction.up:
        newGrid = rotateGrid(newGrid, false);
        break;
      case Direction.right:
        newGrid = rotateGrid(rotateGrid(newGrid, true), true);
        break;
      case Direction.down:
        newGrid = rotateGrid(newGrid, true);
        break;
      case Direction.left:
        // No rotation needed
        break;
    }

    // Process movement
    for (int i = 0; i < 4; i++) {
      List<int> row = newGrid[i];
      List<int> newRow = [];
      List<int> mergedRow = [];

      // Remove zeros and merge
      for (int value in row) {
        if (value != 0) {
          if (newRow.isNotEmpty &&
              newRow.last == value &&
              !mergedRow.contains(newRow.length - 1)) {
            newRow[newRow.length - 1] *= 2;
            score += newRow[newRow.length - 1];
            mergedRow.add(newRow.length - 1);
            moved = true;
          } else {
            newRow.add(value);
          }
        }
      }

      // Fill with zeros
      while (newRow.length < 4) {
        newRow.add(0);
      }

      if (!moved && !listEquals(row, newRow)) {
        moved = true;
      }
      newGrid[i] = newRow;
    }

    // Rotate back
    switch (direction) {
      case Direction.up:
        newGrid = rotateGrid(newGrid, true);
        break;
      case Direction.right:
        newGrid = rotateGrid(rotateGrid(newGrid, false), false);
        break;
      case Direction.down:
        newGrid = rotateGrid(newGrid, false);
        break;
      case Direction.left:
        // No rotation needed
        break;
    }

    if (moved) {
      setState(() {
        grid = newGrid;
        addNewTile();
        
        // Check for game over condition
        if (!canMove()) {
          gameOver = true;
          if (score > highScore) {
            highScore = score;
            _saveHighScore();
          }
          _showAd(); // This will trigger the game over dialog after showing ad
        }
        _saveGameState();
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('2048',style: TextStyle(color: Colors.white),),
        backgroundColor: Color(0xFF776E65),
        actions: [
          // Modified revert button with visual indicators
          Tooltip(
            message: freeReverts > 0 
              ? 'Undo last move (${freeReverts} free)'
              : 'Watch ad to undo last move',
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.undo,
                    color: gameHistory.length < 2 
                      ? Colors.white.withOpacity(0.5)
                      : Colors.white,
                  ),
                  onPressed: gameHistory.length < 2 ? null : revertMove,
                ),
                if (freeReverts > 0 && gameHistory.length >= 2)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$freeReverts',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (freeReverts == 0 && gameHistory.length >= 2 && _isInterstitialAdLoaded)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    Text('Score', style: TextStyle(fontSize: 20)),
                    Text('$score', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  children: [
                    Text('High Score', style: TextStyle(fontSize: 20)),
                    Text('$highScore', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
                ElevatedButton(
                  onPressed: startNewGame,
                  child: Text('New Game', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF776E65),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior
                  .opaque, // Add this line to fix gesture detection
              onVerticalDragUpdate: (details) {
                // Store the start position of the drag
                if (details.delta.dy > 10) {
                  move(Direction.down);
                } else if (details.delta.dy < -10) {
                  move(Direction.up);
                }
              },
              onHorizontalDragUpdate: (details) {
                if (details.delta.dx > 10) {
                  move(Direction.right);
                } else if (details.delta.dx < -10) {
                  move(Direction.left);
                }
              },
              child: Container(
                padding: EdgeInsets.all(16.0),
                child: GridView.builder(
                  physics:
                      NeverScrollableScrollPhysics(), // Prevent grid from scrolling
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: 16,
                  itemBuilder: (context, index) {
                    int row = index ~/ 4;
                    int col = index % 4;
                    int value = grid[row][col];
                    return AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      key: ValueKey<int>(value * 100 + index),
                      decoration: BoxDecoration(
                        color: getTileColor(value),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text( 
                          value != 0 ? value.toString() : '',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: getTileTextColor(value),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          // Unity Banner Ad
          UnityBannerAd(
            placementId: AdsHelper.bannerAdPlacementId,
            onLoad: (placementId) => print('Banner loaded: $placementId'),
            onClick: (placementId) => print('Banner clicked: $placementId'),
            onFailed: (placementId, error, message) => 
              print('Banner Ad $placementId failed: $message'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

enum Direction { up, right, down, left }

bool listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
