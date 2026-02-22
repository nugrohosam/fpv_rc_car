/// Control commands sent from controller to vehicle via WebRTC data channel
/// Optimized for minimal payload size to reduce latency
class ControlData {
  final double throttle; // -1.0 to 1.0 (forward/backward)
  final double steering; // -1.0 to 1.0 (left/right)
  final int timestamp;

  ControlData({
    required this.throttle,
    required this.steering,
  }) : timestamp = DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
    't': throttle,
    's': steering,
    'ts': timestamp,
  };

  factory ControlData.fromJson(Map<String, dynamic> json) => ControlData(
    throttle: (json['t'] as num).toDouble(),
    steering: (json['s'] as num).toDouble(),
  );

  @override
  String toString() => 'ControlData(throttle: $throttle, steering: $steering)';
}
