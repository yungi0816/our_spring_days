import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart' as app_permission;
import 'package:uuid/uuid.dart';

import 'common_providers.dart';
import 'route_models.dart';

final travelRouteStreamProvider = StreamProvider<List<TravelRoute>>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return firebaseService.getTravelRouteStream();
});

final routeTrackingProvider =
    NotifierProvider<RouteTrackingNotifier, RouteTrackingState>(
      RouteTrackingNotifier.new,
    );

class RouteTrackingState {
  final bool isTracking;
  final bool isSaving;
  final String? routeId;
  final DateTime? startedAt;
  final DateTime tick;
  final double totalDistanceMeters;
  final List<RoutePoint> points;
  final String? error;

  const RouteTrackingState({
    this.isTracking = false,
    this.isSaving = false,
    this.routeId,
    this.startedAt,
    required this.tick,
    this.totalDistanceMeters = 0,
    this.points = const [],
    this.error,
  });

  factory RouteTrackingState.initial() {
    return RouteTrackingState(tick: DateTime.now());
  }

  Duration get elapsed => startedAt == null
      ? Duration.zero
      : tick.difference(startedAt!).isNegative
      ? Duration.zero
      : tick.difference(startedAt!);

  RouteTrackingState copyWith({
    bool? isTracking,
    bool? isSaving,
    String? routeId,
    DateTime? startedAt,
    DateTime? tick,
    double? totalDistanceMeters,
    List<RoutePoint>? points,
    String? error,
    bool clearError = false,
  }) {
    return RouteTrackingState(
      isTracking: isTracking ?? this.isTracking,
      isSaving: isSaving ?? this.isSaving,
      routeId: routeId ?? this.routeId,
      startedAt: startedAt ?? this.startedAt,
      tick: tick ?? this.tick,
      totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
      points: points ?? this.points,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class RouteTrackingNotifier extends Notifier<RouteTrackingState> {
  static const _travelNotificationId = 75415;
  static const _travelNotificationChannelId = 'geolocator_channel_01';

  StreamSubscription<Position>? _positionSubscription;
  Timer? _ticker;
  Timer? _autosaveTimer;
  Timer? _notificationTimer;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  String? _creatorId;
  bool _isWriting = false;
  bool _notificationsInitialized = false;

  @override
  RouteTrackingState build() {
    ref.onDispose(() {
      _positionSubscription?.cancel();
      _ticker?.cancel();
      _autosaveTimer?.cancel();
      _notificationTimer?.cancel();
    });
    return RouteTrackingState.initial();
  }

  Future<void> start(String creatorId) async {
    if (state.isTracking) {
      return;
    }

    state = RouteTrackingState.initial().copyWith(isSaving: true);

    try {
      await _ensureLocationPermission();
      await _tryEnsureNotificationPermission();
      _creatorId = creatorId;
      final now = DateTime.now();
      final routeId = const Uuid().v4();

      state = RouteTrackingState(
        isTracking: true,
        isSaving: false,
        routeId: routeId,
        startedAt: now,
        tick: now,
        points: const [],
      );

      final firstPosition = await _currentPositionWithFallback();
      if (firstPosition != null) {
        await _appendPosition(firstPosition, force: true);
      }
      _startTimers();
      await _startNotificationUpdates();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: _locationSettings(),
      ).listen(_appendPosition, onError: _handlePositionError);
    } catch (e) {
      state = RouteTrackingState.initial().copyWith(
        isSaving: false,
        error: e.toString(),
      );
    }
  }

  Future<void> stopAndSave() async {
    if (!state.isTracking || state.routeId == null || state.startedAt == null) {
      return;
    }

    state = state.copyWith(isSaving: true);
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _ticker?.cancel();
    _autosaveTimer?.cancel();
    await _stopNotificationUpdates();

    try {
      final finalPosition = await _currentPositionWithFallback();
      if (finalPosition != null) {
        await _appendPosition(finalPosition, force: true);
      }
      await _saveCurrentRoute(endTime: DateTime.now());
      state = RouteTrackingState.initial();
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
    }
  }

  Future<void> _appendPosition(Position position, {bool force = false}) async {
    if (!state.isTracking || state.routeId == null || state.startedAt == null) {
      return;
    }

    if (!force && position.accuracy > 120) {
      return;
    }

    final nextPoint = RoutePoint(
      position: LatLng(position.latitude, position.longitude),
      timestamp: position.timestamp,
      accuracy: position.accuracy,
    );

    final points = [...state.points];
    var totalDistance = state.totalDistanceMeters;
    if (points.isNotEmpty) {
      final lastPoint = points.last;
      final delta = Geolocator.distanceBetween(
        lastPoint.position.latitude,
        lastPoint.position.longitude,
        nextPoint.position.latitude,
        nextPoint.position.longitude,
      );

      if (!force && delta < 8) {
        return;
      }
      if (!force && delta > 1200) {
        return;
      }

      totalDistance += delta;
    }

    points.add(nextPoint);
    final creatorId = _creatorId;
    if (creatorId != null) {
      unawaited(
        ref
            .read(firebaseServiceProvider)
            .updateSharedUserLocation(creatorId, nextPoint.position),
      );
    }
    state = state.copyWith(
      points: points,
      totalDistanceMeters: totalDistance,
      tick: DateTime.now(),
      clearError: true,
    );
    unawaited(_tryShowTrackingNotification());

    if (points.length == 1 || points.length % 5 == 0) {
      unawaited(_saveCurrentRoute());
    }
  }

  Future<void> _saveCurrentRoute({DateTime? endTime}) async {
    if (_isWriting && endTime == null) {
      return;
    }

    if (_isWriting && endTime != null) {
      final completed = await _waitForCurrentWrite();
      if (!completed) {
        _isWriting = false;
      }
    }

    if (_isWriting ||
        state.routeId == null ||
        state.startedAt == null ||
        _creatorId == null) {
      return;
    }

    _isWriting = true;
    try {
      final route = TravelRoute(
        id: state.routeId!,
        title: _routeTitle(state.startedAt!),
        creatorId: _creatorId!,
        startTime: state.startedAt!,
        endTime: endTime,
        totalDistanceMeters: state.totalDistanceMeters,
        points: state.points,
        updatedAt: DateTime.now(),
      );
      await ref
          .read(firebaseServiceProvider)
          .setTravelRoute(route)
          .timeout(const Duration(seconds: 20));
    } finally {
      _isWriting = false;
    }
  }

  Future<bool> _waitForCurrentWrite() async {
    final startedAt = DateTime.now();
    while (_isWriting) {
      if (DateTime.now().difference(startedAt) > const Duration(seconds: 3)) {
        return false;
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    return true;
  }

  Future<Position?> _currentPositionWithFallback() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  void _startTimers() {
    _ticker?.cancel();
    _autosaveTimer?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 10), (_) {
      if (state.isTracking) {
        state = state.copyWith(tick: DateTime.now());
      }
    });
    _autosaveTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (state.isTracking) {
        unawaited(_saveCurrentRoute());
      }
    });
  }

  Future<void> _startNotificationUpdates() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    final shown = await _tryShowTrackingNotification();
    if (!shown) {
      return;
    }
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (state.isTracking) {
        unawaited(_tryShowTrackingNotification());
      }
    });
  }

  Future<void> _stopNotificationUpdates() async {
    _notificationTimer?.cancel();
    _notificationTimer = null;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _notifications.cancel(id: _travelNotificationId);
      } catch (_) {
        // Tracking cleanup should not fail because the notification plugin fails.
      }
    }
  }

  Future<void> _initializeNotifications() async {
    if (_notificationsInitialized) {
      return;
    }

    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _notificationsInitialized = true;
  }

  Future<bool> _tryShowTrackingNotification() async {
    try {
      await _showTrackingNotification();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _showTrackingNotification() async {
    if (defaultTargetPlatform != TargetPlatform.android ||
        !state.isTracking ||
        state.startedAt == null) {
      return;
    }

    await _initializeNotifications();
    await _notifications.show(
      id: _travelNotificationId,
      title: '여행기록중',
      body:
          '${_formatElapsedForNotification(state.elapsed)}째 · ${_formatDistanceForNotification(state.totalDistanceMeters)} 이동중',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _travelNotificationChannelId,
          '여행 기록',
          channelDescription: '여행 기록 중 이동 시간과 거리를 표시합니다.',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          silent: true,
          showWhen: true,
          when: state.startedAt!.millisecondsSinceEpoch,
          usesChronometer: true,
          color: const Color(0xFFE91E63),
        ),
      ),
    );
  }

  Future<void> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw '기기의 위치 서비스를 켜 주세요.';
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw '여행 기록을 위해 위치 권한이 필요합니다.';
    }
  }

  Future<void> _ensureNotificationPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    final status = await app_permission.Permission.notification.status;
    if (status.isGranted || status.isLimited) {
      return;
    }

    final result = await app_permission.Permission.notification.request();
    if (!result.isGranted && !result.isLimited) {
      throw '상단 알림창에 여행기록중 알림을 표시하려면 알림 권한이 필요합니다.';
    }
  }

  Future<void> _tryEnsureNotificationPermission() async {
    try {
      await _ensureNotificationPermission();
    } catch (_) {
      // Location tracking can continue even if local notification setup fails.
    }
  }

  LocationSettings _locationSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 20,
        intervalDuration: const Duration(seconds: 15),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: '여행기록중',
          notificationText: '비비랑 우리가 이동 경로를 기록하고 있어요.',
          notificationChannelName: '여행 기록',
          enableWakeLock: true,
          setOngoing: true,
          color: Color(0xFFE91E63),
        ),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 20,
        activityType: ActivityType.otherNavigation,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20,
    );
  }

  void _handlePositionError(Object error) {
    state = state.copyWith(error: error.toString());
  }

  String _routeTitle(DateTime startedAt) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${startedAt.year}.${twoDigits(startedAt.month)}.${twoDigits(startedAt.day)} 여행 기록';
  }

  String _formatElapsedForNotification(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours시간 $minutes분';
    }
    return '$minutes분';
  }

  String _formatDistanceForNotification(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
    return '${meters.round()}m';
  }
}
