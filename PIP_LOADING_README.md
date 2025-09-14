# PIP Loading Overlay for BetterPlayer

This extension adds PIP (Picture-in-Picture) loading overlay functionality to the BetterPlayer package without modifying the original package code.

## Features

- ✅ Shows loading overlay for 3 seconds when starting PIP
- ✅ Shows loading overlay for 3 seconds when stopping PIP  
- ✅ Shows loading overlay for 3 seconds when going fullscreen from PIP
- ✅ Works with the original BetterPlayer package
- ✅ No modifications needed to the original package

## Usage

### 1. Import the extension

```dart
import 'package:better_player/better_player.dart';
import 'package:better_player/src/pip_loading_extension.dart';
```

### 2. Use BetterPlayerControllerWithPipLoading instead of BetterPlayerController

```dart
class MyVideoPlayer extends StatefulWidget {
  @override
  _MyVideoPlayerState createState() => _MyVideoPlayerState();
}

class _MyVideoPlayerState extends State<MyVideoPlayer> {
  late BetterPlayerControllerWithPipLoading _betterPlayerController;
  bool _isPipLoading = false;

  @override
  void initState() {
    super.initState();
    _betterPlayerController = BetterPlayerControllerWithPipLoading(
      BetterPlayerConfiguration(
        aspectRatio: 16 / 9,
        autoPlay: false,
        looping: false,
      ),
    );

    // Setup data source
    _betterPlayerController.setupDataSource(
      BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        "https://example.com/video.mp4",
      ),
    );

    // Listen to PIP loading stream
    _betterPlayerController.pipLoadingStream.listen((isLoading) {
      setState(() {
        _isPipLoading = isLoading;
      });
    });
  }

  @override
  void dispose() {
    _betterPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Use BetterPlayerWithPipLoading instead of BetterPlayer
          AspectRatio(
            aspectRatio: 16 / 9,
            child: BetterPlayerWithPipLoading(
              controller: _betterPlayerController,
            ),
          ),
          // Show loading status
          Container(
            padding: EdgeInsets.all(16),
            color: _isPipLoading ? Colors.orange : Colors.green,
            child: Text(
              _isPipLoading ? 'PIP Loading...' : 'Ready',
              style: TextStyle(color: Colors.white),
            ),
          ),
          // PIP controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () async {
                  await _betterPlayerController.enablePictureInPicture(GlobalKey());
                },
                child: Text('Start PIP'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _betterPlayerController.disablePictureInPicture();
                },
                child: Text('Stop PIP'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

## How it works

1. **BetterPlayerControllerWithPipLoading**: Extends the original BetterPlayerController and adds PIP loading functionality
2. **BetterPlayerWithPipLoading**: A wrapper widget that shows loading overlay when PIP loading is active
3. **PipLoadingExtension**: Internal extension that manages the loading state and stream

## API Reference

### BetterPlayerControllerWithPipLoading

- `bool get isPipLoading`: Get current PIP loading state
- `Stream<bool> get pipLoadingStream`: Stream that emits PIP loading state changes
- `Future<void> enablePictureInPicture(GlobalKey key)`: Start PIP with loading overlay
- `Future<void>? disablePictureInPicture()`: Stop PIP with loading overlay
- `void toggleFullScreen()`: Toggle fullscreen with loading overlay if in PIP mode

### BetterPlayerWithPipLoading

- `controller`: BetterPlayerControllerWithPipLoading instance
- `key`: Optional key for the widget

## Customization

You can customize the loading overlay by modifying the `BetterPlayerWithPipLoading` widget:

```dart
if (isPipLoading)
  Container(
    color: Colors.black54, // Change background color
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Colors.white, // Change loading color
          ),
          SizedBox(height: 16),
          Text(
            'Loading...', // Add custom text
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    ),
  ),
```

## Requirements

- Flutter 3.0+
- BetterPlayer package
- No modifications to the original BetterPlayer package needed

## License

This extension follows the same license as the BetterPlayer package.
