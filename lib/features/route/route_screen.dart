import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/providers/common_providers.dart';
import '../../core/providers/map_provider.dart';
import '../../core/providers/route_models.dart';
import '../../core/providers/route_provider.dart';
import '../../core/utils/translation_service.dart';

class RouteScreen extends ConsumerStatefulWidget {
  const RouteScreen({super.key});

  @override
  ConsumerState<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends ConsumerState<RouteScreen> {
  static const _allDays = '전체';
  String? _selectedRouteId;
  String _selectedDay = _allDays;
  GoogleMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(translationProvider);
    final routesAsync = ref.watch(travelRouteStreamProvider);
    final spotsAsync = ref.watch(dateSpotsStreamProvider);
    final trackingState = ref.watch(routeTrackingProvider);

    return Scaffold(
      body: routesAsync.when(
        data: (routes) {
          final selectedRoute = _selectedRoute(routes);
          if (selectedRoute != null) {
            return _buildRouteDetail(
              context,
              tr,
              selectedRoute,
              trackingState,
              spotsAsync.maybeWhen(
                data: (spots) => spots,
                orElse: () => const [],
              ),
            );
          }
          return _buildRouteList(context, tr, routes, trackingState);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildRouteList(
    BuildContext context,
    TranslationService tr,
    List<TravelRoute> routes,
    RouteTrackingState trackingState,
  ) {
    if (routes.isEmpty) {
      return Center(
        child: Text(
          tr.locale.languageCode == 'ko' ? '아직 여행 기록이 없어요.' : 'まだ旅行記録がありません。',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: routes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final route = routes[index];
        final isActive = _isActivelyRecording(route, trackingState);
        final isOpenButInactive = route.isRecording && !isActive;
        return Card(
          elevation: 1,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isActive
                  ? Colors.pinkAccent
                  : isOpenButInactive
                  ? Colors.orangeAccent
                  : Colors.blueAccent,
              foregroundColor: Colors.white,
              child: Icon(isActive ? Icons.directions_walk : Icons.route),
            ),
            title: Text(
              route.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              [
                DateFormat('yyyy.MM.dd HH:mm').format(route.startTime),
                _formatDuration(route.duration),
                _formatDistance(route.totalDistanceMeters),
                if (isActive) 'Recording',
                if (isOpenButInactive) 'Incomplete',
              ].join(' / '),
            ),
            trailing: IconButton(
              tooltip: '삭제',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteRoute(route),
            ),
            onTap: () => setState(() {
              _selectedRouteId = route.id;
              _selectedDay = _allDays;
              _mapController = null;
            }),
          ),
        );
      },
    );
  }

  Widget _buildRouteDetail(
    BuildContext context,
    TranslationService tr,
    TravelRoute route,
    RouteTrackingState trackingState,
    List<DateSpot> spots,
  ) {
    final dayKeys = [_allDays, ..._dayKeys(route.points)];
    if (_selectedDay != _allDays && !dayKeys.contains(_selectedDay)) {
      _selectedDay = _allDays;
    }

    final points = _pointsForDay(route.points, _selectedDay);
    final matches = _candidateSpots(points, spots);
    final markers = _markersFor(route, points, matches);
    final isActive = _isActivelyRecording(route, trackingState);
    final polylines = points.length < 2
        ? <Polyline>{}
        : {
            Polyline(
              polylineId: PolylineId('${route.id}_$_selectedDay'),
              color: Colors.pinkAccent,
              width: 5,
              points: points.map((point) => point.position).toList(),
            ),
          };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 6),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() {
                  _selectedRouteId = null;
                  _selectedDay = _allDays;
                }),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${_formatDuration(_durationForPoints(points, route))} · ${_formatDistance(_distanceForPoints(points, route))}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (isActive)
                TextButton.icon(
                  onPressed: () =>
                      ref.read(routeTrackingProvider.notifier).stopAndSave(),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Stop'),
                )
              else
                IconButton(
                  tooltip: 'Delete',
                  onPressed: () => _deleteRoute(route),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: dayKeys.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final day = dayKeys[index];
              return ChoiceChip(
                label: Text(day == _allDays ? day : _compactDay(day)),
                selected: day == _selectedDay,
                onSelected: (_) => setState(() {
                  _selectedDay = day;
                  _mapController = null;
                }),
              );
            },
          ),
        ),
        Expanded(
          child: points.isEmpty
              ? Center(
                  child: Text(
                    tr.locale.languageCode == 'ko'
                        ? '이 날짜에는 기록된 위치가 없어요.'
                        : 'この日には記録された位置がありません。',
                  ),
                )
              : GoogleMap(
                  key: ValueKey('${route.id}_$_selectedDay'),
                  initialCameraPosition: CameraPosition(
                    target: points.first.position,
                    zoom: 13,
                  ),
                  markers: markers,
                  polylines: polylines,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _fitRoute(points, matches);
                  },
                ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr.locale.languageCode == 'ko' ? '아마 방문한 장소' : '訪問した可能性のある場所',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (matches.isEmpty)
                Text(
                  tr.locale.languageCode == 'ko'
                      ? '루트 근처에 저장된 추천 장소가 아직 없어요.'
                      : 'ルート付近に保存されたおすすめ場所はまだありません。',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                )
              else
                ...matches
                    .take(4)
                    .map(
                      (match) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.place,
                              color: Colors.blueAccent,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${match.spot.name} · ${match.spot.category}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${match.distanceMeters.round()}m',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  TravelRoute? _selectedRoute(List<TravelRoute> routes) {
    final selectedId = _selectedRouteId;
    if (selectedId == null) {
      return null;
    }

    for (final route in routes) {
      if (route.id == selectedId) {
        return route;
      }
    }
    return null;
  }

  bool _isActivelyRecording(
    TravelRoute route,
    RouteTrackingState trackingState,
  ) {
    return trackingState.isTracking && trackingState.routeId == route.id;
  }

  Future<void> _deleteRoute(TravelRoute route) async {
    await ref.read(firebaseServiceProvider).deleteTravelRoute(route.id);
    if (!mounted) return;
    if (_selectedRouteId == route.id) {
      setState(() {
        _selectedRouteId = null;
        _selectedDay = _allDays;
      });
    }
  }

  Set<Marker> _markersFor(
    TravelRoute route,
    List<RoutePoint> points,
    List<_SpotMatch> matches,
  ) {
    final markers = <Marker>{};
    if (points.isNotEmpty) {
      markers.add(
        Marker(
          markerId: MarkerId('${route.id}_start'),
          position: points.first.position,
          infoWindow: const InfoWindow(title: '출발'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
      markers.add(
        Marker(
          markerId: MarkerId('${route.id}_end'),
          position: points.last.position,
          infoWindow: const InfoWindow(title: '도착'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    for (final match in matches.take(10)) {
      markers.add(
        Marker(
          markerId: MarkerId('match_${match.spot.id}'),
          position: match.spot.position,
          infoWindow: InfoWindow(
            title: match.spot.name,
            snippet: '아마 방문 · ${match.distanceMeters.round()}m',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }
    return markers;
  }

  List<String> _dayKeys(List<RoutePoint> points) {
    final days = <String>{};
    for (final point in points) {
      days.add(_dayKey(point.timestamp));
    }
    return days.toList();
  }

  List<RoutePoint> _pointsForDay(List<RoutePoint> points, String day) {
    if (day == _allDays) {
      return points;
    }
    return points.where((point) => _dayKey(point.timestamp) == day).toList();
  }

  List<_SpotMatch> _candidateSpots(
    List<RoutePoint> points,
    List<DateSpot> spots,
  ) {
    if (points.isEmpty || spots.isEmpty) {
      return [];
    }

    final matches = <_SpotMatch>[];
    for (final spot in spots) {
      var nearest = double.infinity;
      for (final point in points) {
        nearest = min(
          nearest,
          Geolocator.distanceBetween(
            point.position.latitude,
            point.position.longitude,
            spot.position.latitude,
            spot.position.longitude,
          ),
        );
      }
      if (nearest <= 500) {
        matches.add(_SpotMatch(spot: spot, distanceMeters: nearest));
      }
    }

    matches.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return matches;
  }

  Future<void> _fitRoute(
    List<RoutePoint> points,
    List<_SpotMatch> matches,
  ) async {
    final controller = _mapController;
    if (controller == null || points.isEmpty) {
      return;
    }

    final positions = [
      ...points.map((point) => point.position),
      ...matches.take(5).map((match) => match.spot.position),
    ];

    if (positions.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(positions.first, 15),
      );
      return;
    }

    final bounds = _boundsFor(positions);
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 64));
  }

  LatLngBounds _boundsFor(List<LatLng> positions) {
    var minLat = positions.first.latitude;
    var maxLat = positions.first.latitude;
    var minLng = positions.first.longitude;
    var maxLng = positions.first.longitude;

    for (final position in positions.skip(1)) {
      minLat = min(minLat, position.latitude);
      maxLat = max(maxLat, position.latitude);
      minLng = min(minLng, position.longitude);
      maxLng = max(maxLng, position.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  Duration _durationForPoints(List<RoutePoint> points, TravelRoute route) {
    if (_selectedDay == _allDays || points.length < 2) {
      return route.duration;
    }
    return points.last.timestamp.difference(points.first.timestamp);
  }

  double _distanceForPoints(List<RoutePoint> points, TravelRoute route) {
    if (_selectedDay == _allDays || points.length < 2) {
      return route.totalDistanceMeters;
    }

    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += Geolocator.distanceBetween(
        points[i - 1].position.latitude,
        points[i - 1].position.longitude,
        points[i].position.latitude,
        points[i].position.longitude,
      );
    }
    return total;
  }

  String _dayKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  String _compactDay(String day) =>
      DateFormat('MM.dd').format(DateTime.parse(day));
}

class _SpotMatch {
  final DateSpot spot;
  final double distanceMeters;

  _SpotMatch({required this.spot, required this.distanceMeters});
}

String _formatDuration(Duration duration) {
  final days = duration.inDays;
  final hours = duration.inHours.remainder(24);
  final minutes = duration.inMinutes.remainder(60);

  if (days > 0) {
    return '$days일 $hours시간 $minutes분';
  }
  if (hours > 0) {
    return '$hours시간 $minutes분';
  }
  return '${max(0, minutes)}분';
}

String _formatDistance(double meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }
  return '${meters.round()}m';
}
