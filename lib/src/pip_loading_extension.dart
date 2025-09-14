import 'dart:async';
import 'package:better_player/better_player.dart';
import 'package:flutter/material.dart';

/// Extension to add PIP loading functionality to BetterPlayerController
class PipLoadingExtension {
  static final Map<BetterPlayerController, PipLoadingExtension> _instances = {};
  
  final BetterPlayerController _controller;
  bool _isPipLoading = false;
  Timer? _pipLoadingTimer;
  final StreamController<bool> _pipLoadingStreamController = StreamController.broadcast();
  
  PipLoadingExtension._(this._controller);
  
  /// Get or create PIP loading extension for a controller
  static PipLoadingExtension of(BetterPlayerController controller) {
    if (!_instances.containsKey(controller)) {
      _instances[controller] = PipLoadingExtension._(controller);
    }
    return _instances[controller]!;
  }
  
  /// Get PIP loading state
  bool get isPipLoading => _isPipLoading;
  
  /// Get PIP loading stream
  Stream<bool> get pipLoadingStream => _pipLoadingStreamController.stream;
  
  /// Start PIP loading overlay for 3 seconds
  void startPipLoading() {
    _isPipLoading = true;
    _pipLoadingStreamController.add(true);
    _pipLoadingTimer?.cancel();
    _pipLoadingTimer = Timer(const Duration(seconds: 3), () {
      _isPipLoading = false;
      _pipLoadingStreamController.add(false);
    });
  }
  
  /// Dispose the extension
  void dispose() {
    _pipLoadingTimer?.cancel();
    _pipLoadingStreamController.close();
    _instances.remove(_controller);
  }
}

/// Enhanced BetterPlayerController with PIP loading functionality
class BetterPlayerControllerWithPipLoading extends BetterPlayerController {
  late final PipLoadingExtension _pipExtension;
  
  BetterPlayerControllerWithPipLoading(BetterPlayerConfiguration configuration, {BetterPlayerPlaylistConfiguration? playlistConfiguration}) 
      : super(configuration) {
    _pipExtension = PipLoadingExtension.of(this);
  }
  
  /// Get PIP loading state
  bool get isPipLoading => _pipExtension.isPipLoading;
  
  /// Get PIP loading stream
  Stream<bool> get pipLoadingStream => _pipExtension.pipLoadingStream;
  
  @override
  Future<void> enablePictureInPicture(GlobalKey betterPlayerGlobalKey) async {
    _pipExtension.startPipLoading();
    return super.enablePictureInPicture(betterPlayerGlobalKey);
  }
  
  @override
  Future<void>? disablePictureInPicture() {
    _pipExtension.startPipLoading();
    return super.disablePictureInPicture();
  }
  
  @override
  void toggleFullScreen() {
    // Check if we're in PIP mode and user wants to go fullscreen
    if (isPipLoading) {
      _pipExtension.startPipLoading();
    }
    super.toggleFullScreen();
  }
  
  @override
  void dispose({bool forceDispose = false}) {
    _pipExtension.dispose();
    super.dispose(forceDispose: forceDispose);
  }
}

/// Enhanced BetterPlayer widget with PIP loading support
class BetterPlayerWithPipLoading extends StatelessWidget {
  final BetterPlayerControllerWithPipLoading controller;
  final Key? key;
  
  const BetterPlayerWithPipLoading({
    required this.controller,
    this.key,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: controller.pipLoadingStream,
      initialData: false,
      builder: (context, snapshot) {
        final bool isPipLoading = snapshot.data ?? false;
        return Stack(
          children: [
            BetterPlayer(
              controller: controller,
              key: key,
            ),
            if (isPipLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
