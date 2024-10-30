import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(const MyApp());
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
      home: Game2048(),
    );
  }
}


class Game2048 extends StatefulWidget {
  @override
  _Game2048State createState() => _Game2048State();
}

// Ad Unit IDs configuration
class AdHelper {
  // Banner Ad IDs
  static String get _bannerAdUnitId {
    try {
      if (kDebugMode) {
        return 'ca-app-pub-3940256099942544/6300978111'; // Test ID
      }
      // Return actual ad IDs based on platform
      if (Platform.isAndroid) {
        return 'ca-app-pub-3004590990738451/8563513230'; // Replace with your Android banner ad ID
      } else if (Platform.isIOS) {
        return 'YOUR_IOS_BANNER_AD_ID'; // Replace with your iOS banner ad ID
      } else {
        throw UnsupportedError('Unsupported platform');
      }
    } catch (e) {
      print('Error fetching Banner Ad Unit ID: $e');
      return ''; // Return an empty string or a fallback ad ID if desired
    }
  }

  // Interstitial Ad IDs
  static String get _interstitialAdUnitId {
    try {
      if (kDebugMode) {
        return 'ca-app-pub-3940256099942544/1033173712'; // Test ID
      }
      // Return actual ad IDs based on platform
      if (Platform.isAndroid) {
        return 'ca-app-pub-3004590990738451/9221988788'; // Replace with your Android interstitial ad ID
      } else if (Platform.isIOS) {
        return 'YOUR_IOS_INTERSTITIAL_AD_ID'; // Replace with your iOS interstitial ad ID
      } else {
        throw UnsupportedError('Unsupported platform');
      }
    } catch (e) {
      print('Error fetching Interstitial Ad Unit ID: $e');
      return ''; // Return an empty string or a fallback ad ID if desired
    }
  }
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

  // Ad related variables
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;
  // final String _bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111'; // Test ad unit ID
  // final String _interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712'; // Test ad unit ID

  @override
  void initState() {
    super.initState();
    freeReverts = 1;
    _loadBannerAd();
    _loadInterstitialAd();
    _loadHighScore(); 
    startNewGame();

    // Initialize ads with test devices if in debug mode
    if (kDebugMode) {
      MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: [
            '48bf97c5-da09-4731-b962-606470ed7a48'
          ], // Add your test device ID here
        ),
      );
    }
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

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: AdHelper._bannerAdUnitId,
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {});
          print('Banner ad loaded successfully');
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          print('Banner ad failed to load: ${error.message}');
          // Retry loading after failure
          Future.delayed(Duration(seconds: 30), _loadBannerAd);
        },
      ),
    );
    _bannerAd?.load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: AdHelper._interstitialAdUnitId,
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          print('Interstitial ad loaded successfully');
        },
        onAdFailedToLoad: (error) {
          print('Interstitial ad failed to load: ${error.message}');
          // Retry loading after failure
          Future.delayed(Duration(seconds: 30), _loadInterstitialAd);
        },
      ),
    );
  }

  void _showAd() {
    if (_isInterstitialAdReady) {
      _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitialAd();
          _showGameOverDialog(); // Show game over dialog after ad is dismissed
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadInterstitialAd();
          _showGameOverDialog(); // Show game over dialog if ad fails
        },
      );
      _interstitialAd?.show();
      _isInterstitialAdReady = false;
    } else {
      _showGameOverDialog(); // Show game over dialog if ad isn't ready
    }
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

   // Revert to previous state
  // Modified revertMove method
  void revertMove() {
    if (gameHistory.length < 2) return;

    if (freeReverts > 0) {
      // Use free revert
      _executeRevert();
      setState(() {
        freeReverts--;
      });
    } else if (_isInterstitialAdReady) {
      // Show ad then revert
      _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitialAd();
          _executeRevert();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadInterstitialAd();
        },
      );
      _interstitialAd?.show();
      _isInterstitialAdReady = false;
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
                if (freeReverts == 0 && gameHistory.length >= 2 && _isInterstitialAdReady)
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
          if (_bannerAd != null)
            Container(
              alignment: Alignment.center,
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
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
