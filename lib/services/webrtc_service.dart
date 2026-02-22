import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/control_data.dart';

// No STUN/TURN - direct TailScale IP only
const _iceServers = <Map<String, dynamic>>[];

// Ultra-low latency video constraints: QCIF 160×120 @ 10-15fps
const _ultraLowLatencyVideoConstraints = {
  'audio': false,
  'video': {
    'width': {'ideal': 160, 'max': 160},
    'height': {'ideal': 120, 'max': 120},
    'frameRate': {'ideal': 12, 'max': 15},
    'facingMode': 'environment',
  }
};

enum SignalingState {
  idle,
  connecting,
  connected,
  disconnected,
}

enum WebRTCMode {
  vehicle, // Camera/mic sender
  controller, // Video receiver
}

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final _dataChannelController = StreamController<ControlData>.broadcast();
  RTCDataChannel? _dataChannel;
  SignalingState _state = SignalingState.idle;
  WebRTCMode? _mode;

  final StreamController<SignalingState> _stateController =
      StreamController<SignalingState>.broadcast();
  final StreamController<MediaStream> _remoteStreamController =
      StreamController<MediaStream>.broadcast();

  Stream<ControlData> get controlData => _dataChannelController.stream;
  Stream<SignalingState> get state => _stateController.stream;
  Stream<MediaStream> get remoteStream => _remoteStreamController.stream;
  SignalingState get currentState => _state;

  Future<void> initializeAsVehicle() async {
    _mode = WebRTCMode.vehicle;
    await _createPeerConnection();
    await _getUserMedia(_ultraLowLatencyVideoConstraints);
    _setupDataChannel();
    _addLocalStreamToPC();
  }

  Future<void> initializeAsController() async {
    _mode = WebRTCMode.controller;
    await _createPeerConnection();
    _setupDataChannelListener();
  }

  Future<void> _createPeerConnection() async {
    final config = {
      'iceServers': _iceServers,
      'iceTransportPolicy': 'all',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
    };

    _peerConnection = await createPeerConnection(config);

    _peerConnection!.onIceCandidate = (candidate) {
      debugPrint('ICE Candidate: ${candidate.candidate}');
    };

    _peerConnection!.onIceConnectionState = (state) {
      debugPrint('ICE Connection State: $state');
      final stateStr = state.toString();
      if (stateStr.contains('disconnected') || stateStr.contains('failed')) {
        _setState(SignalingState.disconnected);
      } else if (stateStr.contains('connected') || stateStr.contains('completed')) {
        _setState(SignalingState.connected);
      }
    };

    if (_mode == WebRTCMode.controller) {
      _peerConnection!.onTrack = (event) {
        debugPrint('Received remote track');
        if (event.streams.isNotEmpty) {
          _remoteStreamController.add(event.streams[0]);
        }
      };
    }
  }

  Future<void> _getUserMedia(Map<String, dynamic> constraints) async {
    try {
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      debugPrint('Got user media: ${_localStream!.getTracks().length} tracks');
    } catch (e) {
      debugPrint('Error getting user media: $e');
      rethrow;
    }
  }

  void _setupDataChannel() async {
    _dataChannel = await _peerConnection!.createDataChannel(
      'control',
      RTCDataChannelInit()
        ..ordered = false      // No order guarantee for speed
        ..maxRetransmits = 0, // No retransmissions - send and forget
    );

    _dataChannel!.onDataChannelState = (state) {
      debugPrint('Data channel state: $state');
    };

    _dataChannel!.onMessage = (message) {
      try {
        if (message.isBinary) {
          // Handle binary data if needed
          return;
        }

        final data = ControlData.fromJson(
          Map<String, dynamic>.from(
            json.decode(message.text) as Map,
          ),
        );
        _dataChannelController.add(data);
      } catch (e) {
        debugPrint('Error parsing control data: $e');
      }
    };
  }

  void _setupDataChannelListener() {
    _peerConnection!.onDataChannel = (channel) {
      _dataChannel = channel;
      _dataChannel!.onDataChannelState = (state) {
        debugPrint('Data channel state: $state');
      };

      _dataChannel!.onMessage = (message) {
        try {
          if (message.isBinary) {
            return;
          }

          final data = ControlData.fromJson(
            Map<String, dynamic>.from(
              json.decode(message.text) as Map,
            ),
          );
          _dataChannelController.add(data);
        } catch (e) {
          debugPrint('Error parsing control data: $e');
        }
      };
    };
  }

  void _addLocalStreamToPC() {
    if (_localStream != null && _peerConnection != null) {
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });
    }
  }

  // Prefer VP8 codec and cap bandwidth to 200 kbps in SDP
  String _modifySdp(String sdp) {
    final lines = sdp.split('\r\n');
    int? vp8Payload;

    for (final line in lines) {
      final match = RegExp(r'^a=rtpmap:(\d+) VP8/').firstMatch(line);
      if (match != null) {
        vp8Payload = int.parse(match.group(1)!);
        break;
      }
    }

    final result = <String>[];
    bool inVideo = false;
    bool bandwidthAdded = false;

    for (final line in lines) {
      if (line.startsWith('m=video')) {
        inVideo = true;
        bandwidthAdded = false;
        if (vp8Payload != null) {
          final parts = line.split(' ');
          final payloads = parts.sublist(3).toList();
          final vp8Str = vp8Payload.toString();
          if (payloads.contains(vp8Str) && payloads.first != vp8Str) {
            payloads.remove(vp8Str);
            payloads.insert(0, vp8Str);
          }
          result.add('${parts[0]} ${parts[1]} ${parts[2]} ${payloads.join(' ')}');
          continue;
        }
      } else if (line.startsWith('m=')) {
        inVideo = false;
      }

      if (inVideo && !bandwidthAdded && line.startsWith('c=')) {
        result.add(line);
        result.add('b=AS:200');
        bandwidthAdded = true;
        continue;
      }

      result.add(line);
    }

    return result.join('\r\n');
  }

  // Create offer (vehicle mode)
  Future<RTCSessionDescription> createOffer() async {
    final raw = await _peerConnection!.createOffer({
      'offerToReceiveAudio': 'false',
      'offerToReceiveVideo': _mode == WebRTCMode.controller ? 'true' : 'false',
    });

    final offer = RTCSessionDescription(_modifySdp(raw.sdp ?? ''), raw.type);
    await _peerConnection!.setLocalDescription(offer);
    return offer;
  }

  // Create answer (controller mode)
  Future<RTCSessionDescription> createAnswer() async {
    final raw = await _peerConnection!.createAnswer();
    final answer = RTCSessionDescription(_modifySdp(raw.sdp ?? ''), raw.type);
    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  // Set remote description (both modes)
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    await _peerConnection!.setRemoteDescription(description);
  }

  // Add ICE candidate (both modes)
  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    await _peerConnection!.addCandidate(candidate);
  }

  // Send control data (controller mode)
  void sendControlData(ControlData data) {
    if (_dataChannel != null &&
        _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      final jsonString = json.encode(data.toJson());
      _dataChannel!.send(RTCDataChannelMessage(jsonString));
    }
  }

  void _setState(SignalingState state) {
    _state = state;
    _stateController.add(state);
  }

  Future<void> dispose() async {
    await _dataChannelController.close();
    await _stateController.close();
    await _remoteStreamController.close();

    if (_dataChannel != null) {
      await _dataChannel!.close();
    }

    if (_localStream != null) {
      await _localStream!.dispose();
    }

    if (_peerConnection != null) {
      await _peerConnection!.close();
      await _peerConnection!.dispose();
    }
  }
}
