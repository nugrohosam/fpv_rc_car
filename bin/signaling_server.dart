/// Simple HTTP signaling server for WebRTC
/// Run this with: dart bin/signaling_server.dart
///
/// This server allows web browsers to connect to the Flutter app
/// by handling SDP exchange and ICE candidates via HTTP

import 'dart:io';
import 'dart:convert';

const int port = 8888;

// Store pending offers and ICE candidates
final Map<String, Map<String, dynamic>> _pendingOffers = {};
final Map<String, List<Map<String, dynamic>>> _iceCandidates = {};
Map<String, dynamic>? _currentOffer; // Most recent offer waiting for answer

Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  print('🚀 Signaling server running on http://0.0.0.0:$port');
  print('📱 Ready to receive WebRTC signals from browsers and Flutter apps');
  print('🌐 Web viewer available at: http://YOUR_IP:$port/viewer/');

  await server.forEach((HttpRequest request) {
    // Enable CORS
    _setCorsHeaders(request.response);

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      request.response.close();
      return;
    }

    final path = request.uri.path;

    switch (path) {
      case '/signal':
        _handleSignal(request);
        break;
      case '/poll':
        _handlePoll(request);
        break;
      case '/answer':
        _handleAnswer(request);
        break;
      case '/':
      case '/index.html':
        _serveViewer(request.response);
        break;
      case '/viewer/':
      case '/viewer/index.html':
        _serveViewer(request.response);
        break;
      case '/manual':
      case '/viewer/manual':
      case '/viewer/manual.html':
        _serveManualViewer(request.response);
        break;
      case '/favicon.ico':
        _serveFavicon(request.response);
        break;
      default:
        _sendError(request.response, HttpStatus.notFound, 'Not Found');
    }
  });
}

Future<void> _handlePoll(HttpRequest request) async {
  if (request.method != 'GET') {
    _sendError(request.response, HttpStatus.methodNotAllowed, 'Method not allowed');
    return;
  }

  // Return the current offer if one exists
  if (_currentOffer != null) {
    request.response.statusCode = HttpStatus.ok;
    request.response.write(jsonEncode({'offer': _currentOffer}));
    await request.response.close();
    print('  📤 Sent offer to polling phone');
  } else {
    request.response.statusCode = HttpStatus.noContent;
    await request.response.close();
  }
}

void _setCorsHeaders(HttpResponse response) {
  response.headers.set('Access-Control-Allow-Origin', '*');
  response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  response.headers.set('Access-Control-Allow-Headers', 'Content-Type');
  response.headers.set('Content-Type', 'application/json');
}

Future<void> _handleSignal(HttpRequest request) async {
  if (request.method != 'POST') {
    _sendError(request.response, HttpStatus.methodNotAllowed, 'Method not allowed');
    return;
  }

  try {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;

    print('  📦 Signal: ${data['type']}');

    if (data['type'] == 'offer') {
      // Store the offer for phone to poll
      _currentOffer = data;
      print('  📦 Offer received, waiting for phone to poll...');

      // Wait for answer (polling)
      final answer = await _waitForAnswer('browser');

      request.response.statusCode = HttpStatus.ok;
      request.response.write(jsonEncode(answer));
      await request.response.close();
    } else if (data['type'] == 'answer') {
      // Store answer for pending offer
      final offerId = data['offerId'] as String?;
      if (offerId != null && _pendingOffers.containsKey(offerId)) {
        _pendingOffers[offerId]?['answer'] = data;

        // Include any ICE candidates
        if (_iceCandidates.containsKey(offerId)) {
          _pendingOffers[offerId]?['iceCandidates'] = _iceCandidates[offerId];
        }

        print('  ✅ Answer received for offer: $offerId');
      }

      request.response.statusCode = HttpStatus.ok;
      request.response.write(jsonEncode({'status': 'ok'}));
      await request.response.close();
    }
  } catch (e) {
    print('  ❌ Error: $e');
    _sendError(request.response, HttpStatus.badRequest, 'Invalid request: $e');
  }
}

Future<Map<String, dynamic>> _waitForAnswer(String offerId) async {
  // Poll for answer (wait up to 30 seconds)
  final startTime = DateTime.now();
  while (DateTime.now().difference(startTime).inSeconds < 30) {
    await Future.delayed(const Duration(milliseconds: 100));

    final offer = _pendingOffers[offerId];
    if (offer != null && offer.containsKey('answer')) {
      final answer = {
        'type': 'answer',
        'sdp': {
          'sdp': offer['answer']['sdp'],
          'type': offer['answer']['type'],
        },
        'iceCandidates': [], // Add ICE candidates if needed
      };

      // Clean up
      _pendingOffers.remove(offerId);
      _iceCandidates.remove(offerId);

      return answer;
    }
  }

  throw TimeoutException('No answer received');
}

Future<void> _serveViewer(HttpResponse response) async {
  response.headers.set('Content-Type', 'text/html; charset=utf-8');

  final viewerFile = File('web/viewer/index.html');
  if (await viewerFile.exists()) {
    final content = await viewerFile.readAsString();
    response.statusCode = HttpStatus.ok;
    response.write(content);
  } else {
    response.statusCode = HttpStatus.notFound;
    response.write('<h1>404 - Viewer not found</h1>');
  }

  await response.close();
}

Future<void> _serveFavicon(HttpResponse response) async {
  response.headers.set('Content-Type', 'image/x-icon');

  final faviconFile = File('bin/favicon.ico');
  if (await faviconFile.exists()) {
    response.statusCode = HttpStatus.ok;
    await response.addStream(faviconFile.openRead());
  } else {
    response.statusCode = HttpStatus.notFound;
  }

  await response.close();
}

Future<void> _serveManualViewer(HttpResponse response) async {
  response.headers.set('Content-Type', 'text/html; charset=utf-8');

  final viewerFile = File('web/viewer/manual.html');
  if (await viewerFile.exists()) {
    final content = await viewerFile.readAsString();
    response.statusCode = HttpStatus.ok;
    response.write(content);
  } else {
    response.statusCode = HttpStatus.notFound;
    response.write('<h1>404 - Manual viewer not found</h1>');
  }

  await response.close();
}

void _sendError(HttpResponse response, int statusCode, String message) {
  response.statusCode = statusCode;
  response.write(jsonEncode({'error': message}));
  response.close();
}

// Handle missing methods
void _handleOffer(HttpRequest request) {
  _sendError(request.response, HttpStatus.notFound, 'Use /signal endpoint');
}

Future<void> _handleAnswer(HttpRequest request) async {
  if (request.method != 'POST') {
    _sendError(request.response, HttpStatus.methodNotAllowed, 'Method not allowed');
    return;
  }

  try {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;

    print('  📦 Answer received from phone');

    // Store the answer - notify waiting browser
    final offerId = 'browser';
    _pendingOffers[offerId] = {'answer': data};
    _currentOffer = null; // Clear the offer since we got an answer

    request.response.statusCode = HttpStatus.ok;
    request.response.write(jsonEncode({'status': 'ok'}));
    await request.response.close();
  } catch (e) {
    print('  ❌ Error: $e');
    _sendError(request.response, HttpStatus.badRequest, 'Invalid request: $e');
  }
}

void _handleIceCandidate(HttpRequest request) {
  _sendError(request.response, HttpStatus.notFound, 'Use /signal endpoint');
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
}
