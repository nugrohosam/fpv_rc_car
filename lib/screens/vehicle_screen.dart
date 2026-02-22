import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:wakelock_plus/wakelock_plus.dart';
import '../providers/webrtc_provider.dart';
import '../services/webrtc_service.dart';

class VehicleScreen extends ConsumerStatefulWidget {
  const VehicleScreen({super.key});

  @override
  ConsumerState<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends ConsumerState<VehicleScreen> {
  String? _localIp;
  String _localOffer = '';
  String _localAnswer = '';
  String _remoteOffer = '';
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVehicle();
      _getLocalIp();
    });
  }

  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }

  Future<void> _stopCamera() async {
    _pollingTimer?.cancel();
    _pollingTimer = null;

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }

    if (_peerConnection != null) {
      await _peerConnection!.close();
      _peerConnection = null;
    }

    await WakelockPlus.disable();
  }

  Future<void> _disconnect() async {
    await _stopCamera();
    await ref.read(webrtcProvider.notifier).disconnect();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _getLocalIp() async {
    // Load saved IP from shared preferences
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('vehicle_ip');

    if (savedIp != null && savedIp.isNotEmpty) {
      setState(() {
        _localIp = savedIp;
      });
    }
  }

  Future<void> _showManualConnectionDialog() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Manual WebRTC Connection'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Step 1: Create Offer',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                ),
                const SizedBox(height: 8),
                const Text('Click to create an offer for the browser:'),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    await _createOffer();
                    setDialogState(() {});
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Create Offer'),
                ),
                const SizedBox(height: 12),
                if (_localOffer.isNotEmpty) ...[
                  const Text('Your Offer (copy this to browser):'),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _localOffer,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _localOffer));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Offer copied!')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Offer'),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'Step 2: Paste Browser\'s Offer',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Paste browser\'s offer here',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                  onChanged: (value) {
                    setState(() {
                      _remoteOffer = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    await _acceptRemoteOffer();
                    setDialogState(() {});
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Accept & Create Answer'),
                ),
                const SizedBox(height: 16),
                if (_localAnswer.isNotEmpty) ...[
                  const Text('Your Answer (copy this to browser):'),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _localAnswer,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _localAnswer));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Answer copied!')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Answer'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initializeVehicle() async {
    try {
      await ref.read(webrtcProvider.notifier).initializeAsVehicle();

      // Setup WebRTC for manual connection
      await _setupWebRTC();

      // Keep screen on while streaming
      await WakelockPlus.enable();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize: $e')),
        );
      }
    }
  }

  Future<void> _setupWebRTC() async {
    final config = {
      'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}],
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
    };

    // Get user media
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': false,
      'video': {
        'width': {'ideal': 160, 'max': 160},
        'height': {'ideal': 120, 'max': 120},
        'frameRate': {'ideal': 12, 'max': 15},
        'facingMode': 'environment',
      }
    });

    // Add tracks to peer connection
    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    // Start polling for connection requests
    _startPollingSignalingServer();
  }

  void _startPollingSignalingServer() {
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final pcIp = prefs.getString('pc_signaling_ip');

        if (pcIp == null || pcIp.isEmpty) {
          // No PC IP set yet, skip polling
          return;
        }

        // Poll the signaling server for pending offers
        final response = await http.get(
          Uri.parse('http://$pcIp:8888/poll'),
        ).timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['offer'] != null) {
            debugPrint('Received offer from browser, creating answer...');
            await _handleIncomingOffer(data['offer'], pcIp);
          }
        }
      } catch (e) {
        // Silently ignore polling errors
        debugPrint('Polling: $e');
      }
    });
  }

  Future<void> _handleIncomingOffer(Map<String, dynamic> offerData, String pcIp) async {
    try {
      // Extract SDP and type from nested structure
      final sdpData = offerData['sdp'];
      final sdpString = sdpData is Map ? sdpData['sdp'] : sdpData;
      final typeString = sdpData is Map ? sdpData['type'] : offerData['type'];

      final offer = RTCSessionDescription(sdpString, typeString);
      await _peerConnection!.setRemoteDescription(offer);

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // Wait for ICE gathering
      await Future.delayed(const Duration(seconds: 2));

      final localDesc = await _peerConnection!.getLocalDescription();
      final answerData = {
        'sdp': localDesc!.sdp,
        'type': localDesc.type,
      };

      // Send answer to signaling server
      await http.post(
        Uri.parse('http://$pcIp:8888/answer'),
        body: jsonEncode(answerData),
        headers: {'Content-Type': 'application/json'},
      );

      debugPrint('Answer sent to signaling server!');
    } catch (e) {
      debugPrint('Error handling offer: $e');
    }
  }

  Future<void> _createOffer() async {
    try {
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': false,
        'offerToReceiveVideo': false,
      });

      await _peerConnection!.setLocalDescription(offer);

      // Wait for ICE gathering to complete
      await Future.delayed(const Duration(seconds: 2));

      final offerData = {
        'sdp': (await _peerConnection!.getLocalDescription())!.sdp,
        'type': (await _peerConnection!.getLocalDescription())!.type,
      };

      setState(() {
        _localOffer = jsonEncode(offerData);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offer created! Copy it to the browser.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create offer: $e')),
        );
      }
    }
  }

  Future<void> _acceptRemoteOffer() async {
    try {
      if (_remoteOffer.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please paste the browser\'s offer first')),
        );
        return;
      }

      final offerData = jsonDecode(_remoteOffer);
      final offer = RTCSessionDescription(
        offerData['sdp'],
        offerData['type'],
      );

      await _peerConnection!.setRemoteDescription(offer);

      // Create answer
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // Wait for ICE gathering
      await Future.delayed(const Duration(seconds: 2));

      final answerData = {
        'sdp': (await _peerConnection!.getLocalDescription())!.sdp,
        'type': (await _peerConnection!.getLocalDescription())!.type,
      };

      setState(() {
        _localAnswer = jsonEncode(answerData);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Answer created! Copy it to the browser.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept offer: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(webrtcProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Vehicle Mode'),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getConnectionColor(state.connectionState).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getConnectionColor(state.connectionState),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _getConnectionText(state.connectionState),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      body: state.isInitializing
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Main status display
                Expanded(
                  child: Container(
                    color: Colors.grey[900],
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icon
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.deepPurple[400]!.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: const Icon(
                                Icons.videocam,
                                size: 50,
                                color: Colors.deepPurple,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Status text
                            const Text(
                              'Vehicle Mode Active',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Camera/mic status
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildStatusChip(
                                  icon: Icons.videocam,
                                  label: 'Camera',
                                  isActive: true,
                                ),
                                const SizedBox(width: 8),
                                _buildStatusChip(
                                  icon: Icons.mic,
                                  label: 'Microphone',
                                  isActive: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),

                            // Web viewer info
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey[800]!.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.deepPurple[400]!.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.web,
                                        color: Colors.deepPurple[400],
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          'Web Viewer Access',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Open a web browser and navigate to:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[900],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.deepPurple[400]!.withOpacity(0.5),
                                        width: 1,
                                      ),
                                    ),
                                                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'http://YOUR_IP:8888/viewer/',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.deepPurple,
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.content_copy),
                                          color: Colors.deepPurple[400],
                                          onPressed: () {
                                            // Copy to clipboard
                                            // You'd implement this with flutter/services
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.green[900]!.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.green[400]!.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.autorenew,
                                              color: Colors.green[400],
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Auto-Connecting...',
                                              style: TextStyle(
                                                color: Colors.green[400],
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Polling for browser connections',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Connection info
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[800]!.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Waiting for web browser connections...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Make sure the signaling server is running on port 8888',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Connection status panel
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.grey[400],
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Vehicle is streaming and ready for connections',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _disconnect,
                            icon: const Icon(Icons.videocam_off, size: 18),
                            label: const Text('Stop & Disconnect'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[800],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withOpacity(0.2) : Colors.grey[800],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? Colors.green : Colors.grey[700]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isActive ? Colors.green : Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? Colors.green : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Color _getConnectionColor(SignalingState state) {
    switch (state) {
      case SignalingState.connected:
        return Colors.green;
      case SignalingState.connecting:
        return Colors.orange;
      case SignalingState.disconnected:
        return Colors.red;
      case SignalingState.idle:
        return Colors.grey;
    }
  }

  String _getConnectionText(SignalingState state) {
    switch (state) {
      case SignalingState.connected:
        return 'Connected';
      case SignalingState.connecting:
        return 'Connecting...';
      case SignalingState.disconnected:
        return 'Disconnected';
      case SignalingState.idle:
        return 'Idle';
    }
  }
}
