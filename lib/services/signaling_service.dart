import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Direct HTTP signaling service for WebRTC peer discovery
/// Optimized for TailScale/LAN direct IP connections
class SignalingService {
  static const int _port = 8888;
  static const Duration _timeout = Duration(seconds: 5);

  /// Exchange SDP offer/answer via HTTP POST
  /// Returns the response (answer if sending offer, or acknowledgement)
  Future<Map<String, dynamic>> exchangeSignal({
    required String targetIp,
    required Map<String, dynamic> signalData,
  }) async {
    try {
      final uri = Uri.parse('http://$targetIp:$_port/signal');
      debugPrint('Sending signal to: $uri');

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(signalData),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Signal exchange failed: $e');
    }
  }

  /// Start HTTP server to receive signaling from peer
  /// Returns a function to stop the server
  void Function() startSignalingServer({
    required String host,
    required int port,
    required Future<Map<String, dynamic>> Function(Map<String, dynamic>) onSignal,
  }) {
    // Note: Flutter doesn't have built-in HTTP server
    // This is a placeholder - you'll need to use a package like 'shelf' or 'http_server'
    // For now, we'll return a no-op function
    // TODO: Implement HTTP server using shelf or similar

    debugPrint('Signaling server would start on $host:$port');

    return () {
      debugPrint('Signaling server stopped');
    };
  }

  // Helper to serialize RTCSessionDescription for HTTP transport
  static Map<String, dynamic> sessionDescriptionToJson(RTCSessionDescription desc) {
    return {
      'sdp': desc.sdp,
      'type': desc.type,
    };
  }

  // Helper to deserialize RTCSessionDescription from HTTP response
  static RTCSessionDescription sessionDescriptionFromJson(Map<String, dynamic> json) {
    return RTCSessionDescription(
      json['sdp'] as String,
      json['type'] as String,
    );
  }

  // Helper to serialize RTCIceCandidate for HTTP transport
  static Map<String, dynamic> iceCandidateToJson(RTCIceCandidate candidate) {
    return {
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    };
  }

  // Helper to deserialize RTCIceCandidate from HTTP response
  static RTCIceCandidate iceCandidateFromJson(Map<String, dynamic> json) {
    return RTCIceCandidate(
      json['candidate'] as String,
      json['sdpMid'] as String?,
      json['sdpMLineIndex'] as int?,
    );
  }
}
