import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/webrtc_service.dart';

// State class - simplified for vehicle-only mode
class WebRTCState {
  final WebRTCMode? mode;
  final SignalingState connectionState;
  final bool isInitializing;

  const WebRTCState({
    this.mode,
    this.connectionState = SignalingState.idle,
    this.isInitializing = false,
  });

  WebRTCState copyWith({
    WebRTCMode? mode,
    SignalingState? connectionState,
    bool? isInitializing,
  }) {
    return WebRTCState(
      mode: mode ?? this.mode,
      connectionState: connectionState ?? this.connectionState,
      isInitializing: isInitializing ?? this.isInitializing,
    );
  }
}

// Notifier - simplified for vehicle-only mode
class WebRTCNotifier extends StateNotifier<WebRTCState> {
  WebRTCService? _webrtcService;

  WebRTCNotifier() : super(const WebRTCState());

  Future<void> initializeAsVehicle() async {
    state = state.copyWith(isInitializing: true, mode: WebRTCMode.vehicle);
    _webrtcService = WebRTCService();

    try {
      await _webrtcService!.initializeAsVehicle();

      _webrtcService!.state.listen((connectionState) {
        state = state.copyWith(connectionState: connectionState);
      });

      state = state.copyWith(isInitializing: false);
    } catch (e) {
      state = state.copyWith(isInitializing: false);
      throw Exception('Failed to initialize vehicle mode: $e');
    }
  }

  Future<void> disconnect() async {
    if (_webrtcService != null) {
      await _webrtcService!.dispose();
      _webrtcService = null;
    }
    state = const WebRTCState();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

// Provider
final webrtcProvider = StateNotifierProvider<WebRTCNotifier, WebRTCState>((ref) {
  return WebRTCNotifier();
});
