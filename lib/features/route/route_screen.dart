import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

import '../../core/providers/common_providers.dart';
import '../../core/providers/map_provider.dart';
import '../../core/providers/route_models.dart';
import '../../core/providers/route_provider.dart';
import '../../core/providers/user_profile_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/utils/translation_service.dart';

class RouteScreen extends ConsumerStatefulWidget {
  const RouteScreen({super.key});

  @override
  ConsumerState<RouteScreen> createState() => _RouteScreenState();
}

enum _SortMode { date, name, group }

String _routeText(Locale locale, String ko, String ja) =>
    locale.languageCode == 'ja' ? ja : ko;

class _RouteScreenState extends ConsumerState<RouteScreen> {
  static const _allDays = '__all_days__';
  String? _selectedRouteId;
  String _selectedDay = _allDays;
  GoogleMapController? _mapController;
  final _commentController = TextEditingController();
  bool _isSendingComment = false;
  _SortMode _sortMode = _SortMode.date;
  String? _filterGroupId;
  Set<String> _filterDays = {};
  final Map<String, BitmapDescriptor> _routePhotoMarkerIcons = {};
  Timer? _timelineTimer;
  int _timelineIndex = 0;
  bool _timelinePlaying = false;
  double _timelineSpeed = 1;

  @override
  void dispose() {
    _timelineTimer?.cancel();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(translationProvider);
    final routesAsync = ref.watch(travelRouteStreamProvider);
    final spotsAsync = ref.watch(dateSpotsStreamProvider);
    final trackingState = ref.watch(routeTrackingProvider);
    final groupsAsync = ref.watch(routeGroupStreamProvider);

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
          final groups = groupsAsync.maybeWhen(
            data: (g) => g,
            orElse: () => const <RouteGroup>[],
          );
          return _buildRouteList(context, tr, routes, trackingState, groups);
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
    List<RouteGroup> groups,
  ) {
    if (routes.isEmpty) {
      return Center(
        child: Text(
          _routeText(tr.locale, '아직 여행 기록이 없어요', '旅行記録はまだありません'),
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    var filtered = routes.where((r) {
      if (_filterGroupId != null && r.groupId != _filterGroupId) return false;
      if (_filterDays.isNotEmpty) {
        final routeDays = _dayKeys(r.points).toSet();
        if (_filterDays.intersection(routeDays).isEmpty) return false;
      }
      return true;
    }).toList();

    // 정렬
    switch (_sortMode) {
      case _SortMode.date:
        filtered.sort((a, b) => b.startTime.compareTo(a.startTime));
      case _SortMode.name:
        filtered.sort((a, b) => a.title.compareTo(b.title));
      case _SortMode.group:
        filtered.sort((a, b) => (a.groupId ?? '').compareTo(b.groupId ?? ''));
    }

    // 기록에 포함된 날짜 목록
    final allDays = <String>{};
    for (final r in routes) {
      allDays.addAll(_dayKeys(r.points));
    }
    final sortedDays = allDays.toList()..sort();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              // 정렬 메뉴
              PopupMenuButton<_SortMode>(
                tooltip: _routeText(tr.locale, '정렬', '並び替え'),
                initialValue: _sortMode,
                onSelected: (v) => setState(() => _sortMode = v),
                icon: const Icon(Icons.sort, size: 20),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _SortMode.date,
                    child: Text(_routeText(tr.locale, '날짜순', '日付順')),
                  ),
                  PopupMenuItem(
                    value: _SortMode.name,
                    child: Text(_routeText(tr.locale, '이름순', '名前順')),
                  ),
                  PopupMenuItem(
                    value: _SortMode.group,
                    child: Text(_routeText(tr.locale, '그룹순', 'グループ順')),
                  ),
                ],
              ),
              // 그룹 필터
              PopupMenuButton<String?>(
                tooltip: _routeText(tr.locale, '그룹 필터', 'グループ絞り込み'),
                initialValue: _filterGroupId,
                onSelected: (v) => setState(() => _filterGroupId = v),
                icon: Icon(
                  Icons.folder_outlined,
                  size: 20,
                  color: _filterGroupId != null ? Colors.pinkAccent : null,
                ),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: null,
                    child: Text(_routeText(tr.locale, '전체 그룹', 'すべてのグループ')),
                  ),
                  ...groups.map(
                    (g) => PopupMenuItem(value: g.id, child: Text(g.name)),
                  ),
                ],
              ),
              // 날짜 필터
              if (sortedDays.isNotEmpty)
                IconButton(
                  tooltip: _routeText(tr.locale, '날짜 필터', '日付絞り込み'),
                  icon: Icon(
                    Icons.date_range,
                    size: 20,
                    color: _filterDays.isNotEmpty ? Colors.pinkAccent : null,
                  ),
                  onPressed: () => _showDayFilterDialog(sortedDays),
                ),
              const Spacer(),
              // 그룹 생성
              TextButton.icon(
                onPressed: () => _createGroupDialog(),
                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                label: Text(
                  _routeText(tr.locale, '그룹 생성', 'グループ作成'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        // 그룹 빠른 선택
        if (groups.isNotEmpty)
          SizedBox(
            height: 36,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: groups.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final group = groups[index];
                final isSelected = _filterGroupId == group.id;
                return GestureDetector(
                  onLongPress: () => _showGroupOptions(group),
                  child: ChoiceChip(
                    label: Text(group.name),
                    selected: isSelected,
                    onSelected: (_) => setState(() {
                      _filterGroupId = isSelected ? null : group.id;
                    }),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              },
            ),
          ),
        if (_filterDays.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Row(
              children: [
                Icon(Icons.filter_alt, size: 14, color: Colors.pinkAccent),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _filterDays.map(_compactDay).join(', '),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.pinkAccent,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _filterDays = {}),
                  child: const Icon(Icons.close, size: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _routeText(
                      tr.locale,
                      '조건에 맞는 여행 기록이 없어요',
                      '条件に合う旅行記録がありません',
                    ),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final route = filtered[index];
                    final isActive = _isActivelyRecording(route, trackingState);
                    final isOpenButInactive = route.isRecording && !isActive;
                    final groupName = groups
                        .where((g) => g.id == route.groupId)
                        .map((g) => g.name)
                        .firstOrNull;
                    return Card(
                      elevation: 1,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isActive
                              ? Colors.pinkAccent
                              : isOpenButInactive
                              ? Colors.orangeAccent
                              : route.routeColor != null
                              ? Color(route.routeColor!)
                              : Colors.blueAccent,
                          foregroundColor: Colors.white,
                          child: Icon(
                            isActive ? Icons.directions_walk : Icons.route,
                          ),
                        ),
                        title: Text(
                          _displayRouteTitle(route, tr.locale),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          [
                            DateFormat(
                              'yyyy.MM.dd HH:mm',
                            ).format(route.startTime),
                            _formatDuration(route.duration, tr.locale),
                            _formatDistance(route.totalDistanceMeters),
                            ?groupName,
                            if (isActive) _routeText(tr.locale, '기록 중', '記録中'),
                            if (isOpenButInactive)
                              _routeText(tr.locale, '미완료', '未完了'),
                          ].join(' / '),
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (v) {
                            if (v == 'delete') _deleteRoute(route);
                            if (v == 'move') _moveRouteToGroup(route, groups);
                            if (v == 'color') _changeRouteColor(route);
                            if (v == 'marker_image') _changeMarkerImage(route);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'color',
                              child: Text(
                                _routeText(tr.locale, '색상 변경', '色を変更'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'marker_image',
                              child: Text(
                                _routeText(tr.locale, '마커 사진', 'マーカー写真'),
                              ),
                            ),
                            if (groups.isNotEmpty)
                              PopupMenuItem(
                                value: 'move',
                                child: Text(
                                  _routeText(tr.locale, '그룹 이동', 'グループ移動'),
                                ),
                              ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(_routeText(tr.locale, '삭제', '削除')),
                            ),
                          ],
                        ),
                        onTap: () => setState(() {
                          _resetTimeline();
                          _selectedRouteId = route.id;
                          _selectedDay = _allDays;
                          _mapController = null;
                        }),
                      ),
                    );
                  },
                ),
        ),
      ],
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

    unawaited(_ensureRoutePhotoMarker(route));
    final points = _pointsForDay(route.points, _selectedDay);
    final matches = _candidateSpots(points, spots);
    final timelineIndex = points.isEmpty
        ? 0
        : min(_timelineIndex, points.length - 1).toInt();
    final timelinePoint = points.isEmpty ? null : points[timelineIndex];
    final markers = _markersFor(
      route,
      points,
      matches,
      timelinePoint: timelinePoint,
      locale: tr.locale,
    );
    final isActive = _isActivelyRecording(route, trackingState);
    final currentUserId = ref.watch(currentUserProvider);
    final currentProfile = ref
        .watch(userProfileProvider(currentUserId))
        .maybeWhen(data: (profile) => profile, orElse: () => null);
    final commentsAsync = ref.watch(routeCommentsProvider(route.id));
    final routeLineColor = route.routeColor != null
        ? Color(route.routeColor!)
        : Colors.pinkAccent;
    final polylines = points.length < 2
        ? <Polyline>{}
        : {
            Polyline(
              polylineId: PolylineId('${route.id}_$_selectedDay'),
              color: routeLineColor,
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
                  _resetTimeline();
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
                      _displayRouteTitle(route, tr.locale),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${_formatDuration(_durationForPoints(points, route), tr.locale)} · ${_formatDistance(_distanceForPoints(points, route))}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (isActive)
                TextButton.icon(
                  onPressed: () => _stopActiveRouteWithTitle(route),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: Text(_routeText(tr.locale, '중지', '停止')),
                )
              else
                IconButton(
                  tooltip: _routeText(tr.locale, '삭제', '削除'),
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
                label: Text(
                  day == _allDays
                      ? _routeText(tr.locale, '전체', 'すべて')
                      : _compactDay(day),
                ),
                selected: day == _selectedDay,
                onSelected: (_) => setState(() {
                  _resetTimeline();
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
                        ? '이 날짜에는 기록된 위치가 없어요'
                        : 'この日には記録された位置がありません',
                  ),
                )
              : GestureDetector(
                  onTap: () =>
                      _showFullscreenMap(route, points, matches, tr.locale),
                  child: Stack(
                    children: [
                      GoogleMap(
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
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: FloatingActionButton.small(
                          heroTag: 'fullscreenMap',
                          backgroundColor: Colors.white,
                          onPressed: () => _showFullscreenMap(
                            route,
                            points,
                            matches,
                            tr.locale,
                          ),
                          child: const Icon(
                            Icons.fullscreen,
                            color: Colors.pinkAccent,
                          ),
                        ),
                      ),
                      if (points.length > 1)
                        Positioned(
                          left: 12,
                          right: 68,
                          bottom: 10,
                          child: _RouteTimelineControls(
                            points: points,
                            index: timelineIndex,
                            isPlaying: _timelinePlaying,
                            speed: _timelineSpeed,
                            locale: tr.locale,
                            onPlayToggle: () => _toggleTimeline(points),
                            onIndexChanged: (value) =>
                                _seekTimeline(points, value),
                            onSpeedChanged: (value) =>
                                _setTimelineSpeed(points, value),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        _RouteDetailBottomPanel(
          matches: matches,
          commentsAsync: commentsAsync,
          currentUserId: currentUserId,
          currentProfile: currentProfile,
          commentController: _commentController,
          isSending: _isSendingComment,
          onSend: () => _sendRouteComment(route),
          onDelete: (comment) => _deleteRouteComment(route, comment),
          locale: tr.locale,
        ),
      ],
    );
  }

  void _resetTimeline() {
    _timelineTimer?.cancel();
    _timelineTimer = null;
    _timelinePlaying = false;
    _timelineIndex = 0;
  }

  void _toggleTimeline(List<RoutePoint> points) {
    if (_timelinePlaying) {
      setState(() {
        _timelineTimer?.cancel();
        _timelineTimer = null;
        _timelinePlaying = false;
      });
      return;
    }

    if (points.length < 2) {
      return;
    }
    if (_timelineIndex >= points.length - 1) {
      _timelineIndex = 0;
    }
    setState(() => _timelinePlaying = true);
    _timelineTimer?.cancel();
    _timelineTimer = Timer.periodic(_timelineInterval, (_) {
      if (!mounted || !_timelinePlaying) {
        return;
      }
      if (_timelineIndex >= points.length - 1) {
        setState(() {
          _timelineTimer?.cancel();
          _timelineTimer = null;
          _timelinePlaying = false;
        });
        return;
      }
      _seekTimeline(points, _timelineIndex + 1, animate: true);
    });
  }

  void _setTimelineSpeed(List<RoutePoint> points, double speed) {
    final wasPlaying = _timelinePlaying;
    if (wasPlaying) {
      _timelineTimer?.cancel();
      _timelineTimer = null;
      _timelinePlaying = false;
    }
    setState(() => _timelineSpeed = speed);
    if (wasPlaying) {
      _toggleTimeline(points);
    }
  }

  Duration get _timelineInterval {
    final millis = (900 / _timelineSpeed.clamp(1, 8)).round();
    return Duration(milliseconds: max(120, millis));
  }

  void _seekTimeline(
    List<RoutePoint> points,
    int index, {
    bool animate = false,
  }) {
    if (points.isEmpty) {
      return;
    }
    final nextIndex = index.clamp(0, points.length - 1).toInt();
    setState(() => _timelineIndex = nextIndex);
    if (animate) {
      final target = points[nextIndex].position;
      unawaited(_mapController?.animateCamera(CameraUpdate.newLatLng(target)));
    }
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

  Future<void> _stopActiveRouteWithTitle(TravelRoute route) async {
    final title = await _askRouteTitle(route.startTime);
    if (title == null) {
      return;
    }
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await ref.read(routeTrackingProvider.notifier).stopAndSave(title: title);
    if (!mounted) return;
    final error = ref.read(routeTrackingProvider).error;
    final locale = ref.read(translationProvider).locale;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ?? _routeText(locale, '여행 기록이 저장되었습니다.', '旅行記録を保存しました。'),
        ),
      ),
    );
  }

  Future<String?> _askRouteTitle(DateTime startedAt) async {
    final locale = ref.read(translationProvider).locale;
    final controller = TextEditingController(
      text: _defaultRouteTitle(startedAt, locale),
    );
    void closeDialog(BuildContext dialogContext, [String? value]) {
      FocusScope.of(dialogContext).unfocus();
      Navigator.of(dialogContext, rootNavigator: true).pop(value);
    }

    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_routeText(locale, '여행 기록 제목', '旅行記録のタイトル')),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: _routeText(locale, '제목', 'タイトル'),
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) =>
              closeDialog(dialogContext, controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => closeDialog(dialogContext),
            child: Text(_routeText(locale, '취소', 'キャンセル')),
          ),
          FilledButton(
            onPressed: () => closeDialog(dialogContext, controller.text.trim()),
            child: Text(_routeText(locale, '저장', '保存')),
          ),
        ],
      ),
    );
    await WidgetsBinding.instance.endOfFrame;
    controller.dispose();
    return title;
  }

  Future<void> _sendRouteComment(TravelRoute route) async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _isSendingComment) {
      return;
    }

    setState(() => _isSendingComment = true);
    _commentController.clear();
    final currentUserId = ref.read(currentUserProvider);
    final profile = ref
        .read(userProfileProvider(currentUserId))
        .maybeWhen(data: (profile) => profile, orElse: () => null);
    final comment = RouteComment(
      id: const Uuid().v4(),
      routeId: route.id,
      authorId: currentUserId,
      authorNickname: profile?.displayName ?? currentUserId,
      authorPhotoUrl: profile?.photoUrl,
      content: content,
      createdAt: DateTime.now(),
    );

    try {
      await ref
          .read(firebaseServiceProvider)
          .addRouteComment(route.id, comment)
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      if (mounted) {
        final locale = ref.read(translationProvider).locale;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _routeText(
                locale,
                '댓글 저장 요청을 보냈어요. 잠시 뒤 반영됩니다.',
                'コメント保存リクエストを送りました。少し後に反映されます。',
              ),
            ),
          ),
        );
      }
    } catch (e) {
      _commentController.text = content;
      if (mounted) {
        final locale = ref.read(translationProvider).locale;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_routeText(locale, '댓글 저장 실패', 'コメント保存失敗')}: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingComment = false);
      }
    }
  }

  Future<void> _deleteRouteComment(
    TravelRoute route,
    RouteComment comment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          _routeText(ref.read(translationProvider).locale, '댓글 삭제', 'コメント削除'),
        ),
        content: Text(
          _routeText(
            ref.read(translationProvider).locale,
            '이 댓글을 삭제할까요?',
            'このコメントを削除しますか？',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              _routeText(ref.read(translationProvider).locale, '취소', 'キャンセル'),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              _routeText(ref.read(translationProvider).locale, '삭제', '削除'),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    await ref
        .read(firebaseServiceProvider)
        .deleteRouteComment(route.id, comment.id);
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
    List<_SpotMatch> matches, {
    RoutePoint? timelinePoint,
    required Locale locale,
  }) {
    final markers = <Marker>{};
    final startHue = route.markerColor != null
        ? _hueFromColor(Color(route.markerColor!))
        : BitmapDescriptor.hueGreen;
    final endHue = route.markerColor != null
        ? _hueFromColor(Color(route.markerColor!))
        : BitmapDescriptor.hueRed;
    final photoIcon = _routePhotoMarkerIcons[route.id];
    if (points.isNotEmpty) {
      markers.add(
        Marker(
          markerId: MarkerId('${route.id}_start'),
          position: points.first.position,
          infoWindow: InfoWindow(title: _routeText(locale, '출발', '出発')),
          icon: photoIcon ?? BitmapDescriptor.defaultMarkerWithHue(startHue),
        ),
      );
      markers.add(
        Marker(
          markerId: MarkerId('${route.id}_end'),
          position: points.last.position,
          infoWindow: InfoWindow(title: _routeText(locale, '도착', '到着')),
          icon: BitmapDescriptor.defaultMarkerWithHue(endHue),
        ),
      );
    }

    if (timelinePoint != null) {
      markers.add(
        Marker(
          markerId: MarkerId('${route.id}_timeline'),
          position: timelinePoint.position,
          zIndexInt: 10,
          infoWindow: InfoWindow(
            title: DateFormat('HH:mm:ss').format(timelinePoint.timestamp),
            snippet:
                '${_routeText(locale, '정확도', '精度')} ${timelinePoint.accuracy.toStringAsFixed(0)}m',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueViolet,
          ),
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
            snippet:
                '${_routeText(locale, '가까운 장소', '近くの場所')} · ${match.distanceMeters.round()}m',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }
    return markers;
  }

  double _hueFromColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.hue;
  }

  Future<void> _ensureRoutePhotoMarker(TravelRoute route) async {
    final imageUrl = route.markerImageUrl?.trim();
    if (imageUrl == null ||
        imageUrl.isEmpty ||
        _routePhotoMarkerIcons.containsKey(route.id)) {
      return;
    }
    try {
      final icon = await _createRoutePhotoMarker(
        imageUrl,
        route.markerColor != null
            ? Color(route.markerColor!)
            : Colors.pinkAccent,
      );
      if (!mounted) {
        return;
      }
      setState(() => _routePhotoMarkerIcons[route.id] = icon);
    } catch (_) {
      // The default colored marker is still usable if the custom photo fails.
    }
  }

  Future<BitmapDescriptor> _createRoutePhotoMarker(
    String imageUrl,
    Color color,
  ) async {
    const size = 112.0;
    const photoSize = 70.0;
    final response = await NetworkAssetBundle(Uri.parse(imageUrl)).load('');
    final image = await _decodeUiImage(response.buffer.asUint8List());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2 - 10);
    final paint = Paint()..isAntiAlias = true;

    final markerPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: 43))
      ..moveTo(size / 2 - 12, size - 28)
      ..quadraticBezierTo(size / 2, size - 8, size / 2 + 12, size - 28)
      ..close();
    canvas.drawShadow(
      markerPath,
      Colors.black.withValues(alpha: 0.28),
      5,
      true,
    );
    canvas.drawPath(markerPath, paint..color = color);
    canvas.drawCircle(center, 36, Paint()..color = Colors.white);

    final photoRect = Rect.fromCenter(
      center: center,
      width: photoSize,
      height: photoSize,
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(photoRect));
    paintImage(
      canvas: canvas,
      rect: photoRect,
      image: image,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
    );
    canvas.restore();

    final rendered = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final byteData = await rendered.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      byteData?.buffer.asUint8List() ?? Uint8List(0),
      imagePixelRatio: 2.6,
    );
  }

  Future<ui.Image> _decodeUiImage(Uint8List bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
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

  String _displayRouteTitle(TravelRoute route, Locale locale) {
    return route.isDisconnectedCoupleRecord
        ? '${_routeText(locale, '(해제)', '(解除済み)')} ${route.title}'
        : route.title;
  }

  String _defaultRouteTitle(DateTime startedAt, Locale locale) {
    return '${DateFormat('yyyy.MM.dd').format(startedAt)} ${_routeText(locale, '여행 기록', '旅行記録')}';
  }

  // --- 그룹 관리 ---
  Future<void> _createGroupDialog() async {
    final locale = ref.read(translationProvider).locale;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_routeText(locale, '새 그룹 생성', '新しいグループを作成')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: _routeText(locale, '그룹 이름', 'グループ名'),
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.pop(ctx, controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_routeText(locale, '취소', 'キャンセル')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(_routeText(locale, '생성', '作成')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    final group = RouteGroup(
      id: const Uuid().v4(),
      name: name,
      createdAt: DateTime.now(),
    );
    await ref.read(firebaseServiceProvider).addRouteGroup(group);
  }

  void _showGroupOptions(RouteGroup group) {
    final locale = ref.read(translationProvider).locale;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
              ),
              title: Text(
                _routeText(
                  locale,
                  '${group.name} 그룹 삭제',
                  '${group.name} グループを削除',
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _deleteGroup(group);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteGroup(RouteGroup group) async {
    final locale = ref.read(translationProvider).locale;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_routeText(locale, '그룹 삭제', 'グループ削除')),
        content: Text(
          _routeText(
            locale,
            '${group.name} 그룹을 삭제할까요?\n(루트는 삭제되지 않습니다)',
            '${group.name} グループを削除しますか？\n(ルートは削除されません)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_routeText(locale, '취소', 'キャンセル')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_routeText(locale, '삭제', '削除')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(firebaseServiceProvider).deleteRouteGroup(group.id);
    if (_filterGroupId == group.id) {
      setState(() => _filterGroupId = null);
    }
  }

  Future<void> _moveRouteToGroup(
    TravelRoute route,
    List<RouteGroup> groups,
  ) async {
    final locale = ref.read(translationProvider).locale;
    final groupId = await showDialog<String?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(_routeText(locale, '그룹 이동', 'グループ移動')),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ''),
            child: Text(_routeText(locale, '그룹 없음', 'グループなし')),
          ),
          ...groups.map(
            (g) => SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, g.id),
              child: Text(g.name),
            ),
          ),
        ],
      ),
    );
    if (groupId == null) return;
    await ref.read(firebaseServiceProvider).updateTravelRouteFields(route.id, {
      'groupId': groupId.isEmpty ? null : groupId,
    });
  }

  // --- 색상 변경 ---
  Future<void> _changeRouteColor(TravelRoute route) async {
    final locale = ref.read(translationProvider).locale;
    final colors = [
      Colors.pinkAccent,
      Colors.redAccent,
      Colors.orangeAccent,
      Colors.amber,
      Colors.green,
      Colors.teal,
      Colors.blueAccent,
      Colors.indigo,
      Colors.purple,
      Colors.brown,
    ];
    final result = await showDialog<({int? marker, int? route})>(
      context: context,
      builder: (ctx) {
        int selectedMarker = route.markerColor ?? colors.first.toARGB32();
        int selectedRoute = route.routeColor ?? Colors.pinkAccent.toARGB32();
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(_routeText(locale, '색상 변경', '色を変更')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _routeText(locale, '마커 색상', 'マーカー色'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colors.map((c) {
                    final value = c.toARGB32();
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedMarker = value),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedMarker == value
                                ? Colors.black
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  _routeText(locale, '경로 색상', 'ルート色'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colors.map((c) {
                    final value = c.toARGB32();
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedRoute = value),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedRoute == value
                                ? Colors.black
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(_routeText(locale, '취소', 'キャンセル')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, (
                  marker: selectedMarker,
                  route: selectedRoute,
                )),
                child: Text(_routeText(locale, '적용', '適用')),
              ),
            ],
          ),
        );
      },
    );
    if (result == null) return;
    await ref.read(firebaseServiceProvider).updateTravelRouteFields(route.id, {
      'markerColor': result.marker,
      'routeColor': result.route,
    });
  }

  // --- 마커 사진 설정 ---
  Future<void> _changeMarkerImage(TravelRoute route) async {
    final locale = ref.read(translationProvider).locale;
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    if (!mounted) return;

    try {
      final url = await ref
          .read(firebaseServiceProvider)
          .uploadImage(
            File(image.path),
            'route_markers/${route.id}/${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
      await ref.read(firebaseServiceProvider).updateTravelRouteFields(
        route.id,
        {'markerImageUrl': url},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _routeText(locale, '마커 사진을 설정했어요.', 'マーカー写真を設定しました。'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_routeText(locale, '사진 업로드 실패', '写真アップロード失敗')}: $e',
            ),
          ),
        );
      }
    }
  }

  // --- 날짜 필터 ---
  Future<void> _showDayFilterDialog(List<String> allDays) async {
    final locale = ref.read(translationProvider).locale;
    var selected = Set<String>.from(_filterDays);
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_routeText(locale, '날짜 선택', '日付を選択')),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: allDays.length,
              itemBuilder: (_, index) {
                final day = allDays[index];
                return CheckboxListTile(
                  title: Text(_compactDay(day)),
                  value: selected.contains(day),
                  onChanged: (v) {
                    setDialogState(() {
                      if (v == true) {
                        selected.add(day);
                      } else {
                        selected.remove(day);
                      }
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setDialogState(() => selected = {});
              },
              child: Text(_routeText(locale, '초기화', 'リセット')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_routeText(locale, '적용', '適用')),
            ),
          ],
        ),
      ),
    );
    setState(() => _filterDays = selected);
  }

  // --- 전체 화면 지도 ---
  void _showFullscreenMap(
    TravelRoute route,
    List<RoutePoint> points,
    List<_SpotMatch> matches,
    Locale locale,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullscreenMapPage(
          route: route,
          points: points,
          matches: matches,
          locale: locale,
        ),
      ),
    );
  }
}

class _SpotMatch {
  final DateSpot spot;
  final double distanceMeters;

  _SpotMatch({required this.spot, required this.distanceMeters});
}

class _RouteTimelineControls extends StatelessWidget {
  final List<RoutePoint> points;
  final int index;
  final bool isPlaying;
  final double speed;
  final Locale locale;
  final VoidCallback onPlayToggle;
  final ValueChanged<int> onIndexChanged;
  final ValueChanged<double> onSpeedChanged;

  const _RouteTimelineControls({
    required this.points,
    required this.index,
    required this.isPlaying,
    required this.speed,
    required this.locale,
    required this.onPlayToggle,
    required this.onIndexChanged,
    required this.onSpeedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final safeIndex = points.isEmpty
        ? 0
        : index.clamp(0, points.length - 1).toInt();
    final point = points[safeIndex];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
        child: Row(
          children: [
            IconButton.filledTonal(
              visualDensity: VisualDensity.compact,
              onPressed: onPlayToggle,
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('HH:mm:ss').format(point.timestamp),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                    ),
                    child: Slider(
                      value: safeIndex.toDouble(),
                      min: 0,
                      max: max(1, points.length - 1).toDouble(),
                      divisions: max(1, points.length - 1),
                      onChanged: (value) => onIndexChanged(value.round()),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<double>(
              tooltip: _routeText(locale, '배속', '再生速度'),
              initialValue: speed,
              onSelected: onSpeedChanged,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 1, child: Text('1x')),
                PopupMenuItem(value: 2, child: Text('2x')),
                PopupMenuItem(value: 4, child: Text('4x')),
                PopupMenuItem(value: 8, child: Text('8x')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Text(
                  '${speed.toStringAsFixed(0)}x',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteDetailBottomPanel extends StatelessWidget {
  final List<_SpotMatch> matches;
  final AsyncValue<List<RouteComment>> commentsAsync;
  final String currentUserId;
  final UserProfile? currentProfile;
  final TextEditingController commentController;
  final bool isSending;
  final VoidCallback onSend;
  final ValueChanged<RouteComment> onDelete;
  final Locale locale;

  const _RouteDetailBottomPanel({
    required this.matches,
    required this.commentsAsync,
    required this.currentUserId,
    required this.currentProfile,
    required this.commentController,
    required this.isSending,
    required this.onSend,
    required this.onDelete,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final keyboardVisible = keyboardHeight > 0;
    final effectiveHeight = max(280.0, mediaQuery.size.height - keyboardHeight);
    final panelHeight = keyboardVisible
        ? min(max(effectiveHeight * 0.32, 132.0), 220.0)
        : min(mediaQuery.size.height * 0.43, 360.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      height: panelHeight,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
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
        children: [
          if (!keyboardVisible) ...[
            _VisitedSpotSummary(matches: matches, locale: locale),
            const Divider(height: 18),
          ],
          Expanded(
            child: commentsAsync.when(
              data: (comments) => comments.isEmpty
                  ? Center(
                      child: Text(
                        _routeText(locale, '아직 코멘트가 없어요', 'まだコメントがありません'),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: comments.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _RouteCommentBubble(
                        comment: comments[index],
                        isMine: comments[index].authorId == currentUserId,
                        onDelete: () => onDelete(comments[index]),
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Text(
                  '${_routeText(locale, '댓글을 불러오지 못했어요', 'コメントを読み込めませんでした')}: $error',
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: commentController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: _routeText(
                      locale,
                      '${currentProfile?.displayName ?? currentUserId} 님의 코멘트',
                      '${currentProfile?.displayName ?? currentUserId} さんのコメント',
                    ),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: isSending ? null : onSend,
                icon: isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VisitedSpotSummary extends StatelessWidget {
  final List<_SpotMatch> matches;
  final Locale locale;

  const _VisitedSpotSummary({required this.matches, required this.locale});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _routeText(locale, '가까이 지나간 장소', '近くを通った場所'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (matches.isEmpty)
          Text(
            locale.languageCode == 'ko'
                ? '루트 근처에 저장된 추천 장소가 아직 없어요'
                : 'ルート近くに保存済みのおすすめ場所はまだありません',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          )
        else
          ...matches
              .take(2)
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
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
      ],
    );
  }
}

class _RouteCommentBubble extends ConsumerWidget {
  final RouteComment comment;
  final bool isMine;
  final VoidCallback onDelete;

  const _RouteCommentBubble({
    required this.comment,
    required this.isMine,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(translationProvider).locale;
    final authorProfile = ref
        .watch(userProfileProvider(comment.authorId))
        .maybeWhen(data: (profile) => profile, orElse: () => null);
    final authorName = authorProfile?.displayName ?? comment.authorNickname;
    final authorPhotoUrl = authorProfile?.photoUrl ?? comment.authorPhotoUrl;
    final defaultPhotoAsset = _defaultCommentPhotoAsset(
      comment.authorId,
      authorProfile,
    );
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.66;
    final bubbleColor = isMine ? const Color(0xFFFFE7EF) : Colors.grey[100]!;
    final crossAxisAlignment = isMine
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    final bubble = Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          authorName,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[700],
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxBubbleWidth),
          child: GestureDetector(
            onLongPress: isMine ? onDelete : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isMine ? 14 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 14),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                child: Text(comment.content),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('HH:mm').format(comment.createdAt),
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
            if (isMine) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: onDelete,
                child: Text(
                  _routeText(locale, '삭제', '削除'),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ),
            ],
          ],
        ),
      ],
    );

    return Row(
      mainAxisAlignment: isMine
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isMine) ...[
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: _CommentAvatar(
              photoUrl: authorPhotoUrl,
              defaultAsset: defaultPhotoAsset,
              radius: 22,
              onTap: () => _showAuthorProfile(
                context,
                authorName,
                authorPhotoUrl,
                defaultPhotoAsset,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(child: bubble),
      ],
    );
  }

  void _showAuthorProfile(
    BuildContext context,
    String authorName,
    String? photoUrl,
    String defaultAsset,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(authorName, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ProfilePhotoImage(
              photoUrl: photoUrl,
              defaultAsset: defaultAsset,
              size: 132,
            ),
            const SizedBox(height: 12),
            Text(
              authorName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentAvatar extends StatelessWidget {
  final String? photoUrl;
  final String defaultAsset;
  final double radius;
  final VoidCallback? onTap;

  const _CommentAvatar({
    this.photoUrl,
    required this.defaultAsset,
    required this.radius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(1.5),
          child: _ProfilePhotoImage(
            photoUrl: photoUrl,
            defaultAsset: defaultAsset,
            size: radius * 2,
          ),
        ),
      ),
    );
  }
}

class _ProfilePhotoImage extends StatelessWidget {
  final String? photoUrl;
  final String defaultAsset;
  final double size;

  const _ProfilePhotoImage({
    this.photoUrl,
    required this.defaultAsset,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim();
    final fallback = Image.asset(defaultAsset, fit: BoxFit.cover);

    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFFFFE7EF)),
          child: url != null && url.isNotEmpty
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                )
              : fallback,
        ),
      ),
    );
  }
}

String _defaultCommentPhotoAsset(String userId, UserProfile? profile) {
  if (profile?.gender == '여성') {
    return 'images/girl.png';
  }
  if (profile?.gender == '남성') {
    return 'images/boy.png';
  }
  return isPartnerAUser(userId) ? 'images/girl.png' : 'images/boy.png';
}

String _formatDuration(Duration duration, Locale locale) {
  final days = duration.inDays;
  final hours = duration.inHours.remainder(24);
  final minutes = duration.inMinutes.remainder(60);
  final isJa = locale.languageCode == 'ja';

  if (days > 0) {
    return isJa ? '$days日 $hours時間 $minutes分' : '$days일 $hours시간 $minutes분';
  }
  if (hours > 0) {
    return isJa ? '$hours時間 $minutes分' : '$hours시간 $minutes분';
  }
  final safeMinutes = max(0, minutes);
  return isJa ? '$safeMinutes分' : '$safeMinutes분';
}

String _formatDistance(double meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }
  return '${meters.round()}m';
}

class _FullscreenMapPage extends StatefulWidget {
  final TravelRoute route;
  final List<RoutePoint> points;
  final List<_SpotMatch> matches;
  final Locale locale;

  const _FullscreenMapPage({
    required this.route,
    required this.points,
    required this.matches,
    required this.locale,
  });

  @override
  State<_FullscreenMapPage> createState() => _FullscreenMapPageState();
}

class _FullscreenMapPageState extends State<_FullscreenMapPage> {
  GoogleMapController? _controller;
  bool _showMarkers = true;
  bool _isSaving = false;
  BitmapDescriptor? _photoIcon;
  final _repaintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    unawaited(_loadPhotoIcon());
  }

  Set<Marker> get _markers {
    if (!_showMarkers) return {};
    final markers = <Marker>{};
    final route = widget.route;
    final startHue = route.markerColor != null
        ? HSLColor.fromColor(Color(route.markerColor!)).hue
        : BitmapDescriptor.hueGreen;
    final endHue = route.markerColor != null
        ? HSLColor.fromColor(Color(route.markerColor!)).hue
        : BitmapDescriptor.hueRed;
    if (widget.points.isNotEmpty) {
      markers.add(
        Marker(
          markerId: MarkerId('${route.id}_start'),
          position: widget.points.first.position,
          infoWindow: InfoWindow(title: _routeText(widget.locale, '출발', '出発')),
          icon: _photoIcon ?? BitmapDescriptor.defaultMarkerWithHue(startHue),
        ),
      );
      markers.add(
        Marker(
          markerId: MarkerId('${route.id}_end'),
          position: widget.points.last.position,
          infoWindow: InfoWindow(title: _routeText(widget.locale, '도착', '到着')),
          icon: BitmapDescriptor.defaultMarkerWithHue(endHue),
        ),
      );
    }
    for (final m in widget.matches.take(10)) {
      markers.add(
        Marker(
          markerId: MarkerId('match_${m.spot.id}'),
          position: m.spot.position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }
    return markers;
  }

  Set<Polyline> get _polylines {
    if (widget.points.length < 2) return {};
    final color = widget.route.routeColor != null
        ? Color(widget.route.routeColor!)
        : Colors.pinkAccent;
    return {
      Polyline(
        polylineId: PolylineId(widget.route.id),
        color: color,
        width: 5,
        points: widget.points.map((p) => p.position).toList(),
      ),
    };
  }

  Future<void> _loadPhotoIcon() async {
    final imageUrl = widget.route.markerImageUrl?.trim();
    if (imageUrl == null || imageUrl.isEmpty) {
      return;
    }
    try {
      final icon = await _buildPhotoIcon(
        imageUrl,
        widget.route.markerColor != null
            ? Color(widget.route.markerColor!)
            : Colors.pinkAccent,
      );
      if (mounted) {
        setState(() => _photoIcon = icon);
      }
    } catch (_) {
      // Keep the default marker if the custom photo cannot be rendered.
    }
  }

  Future<BitmapDescriptor> _buildPhotoIcon(String imageUrl, Color color) async {
    const size = 112.0;
    const photoSize = 70.0;
    final response = await NetworkAssetBundle(Uri.parse(imageUrl)).load('');
    final image = await _decodeUiImage(response.buffer.asUint8List());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2 - 10);
    final path = Path()
      ..addOval(Rect.fromCircle(center: center, radius: 43))
      ..moveTo(size / 2 - 12, size - 28)
      ..quadraticBezierTo(size / 2, size - 8, size / 2 + 12, size - 28)
      ..close();
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.28), 5, true);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawCircle(center, 36, Paint()..color = Colors.white);

    final photoRect = Rect.fromCenter(
      center: center,
      width: photoSize,
      height: photoSize,
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(photoRect));
    paintImage(
      canvas: canvas,
      rect: photoRect,
      image: image,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
    );
    canvas.restore();

    final rendered = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final byteData = await rendered.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      byteData?.buffer.asUint8List() ?? Uint8List(0),
      imagePixelRatio: 2.6,
    );
  }

  Future<ui.Image> _decodeUiImage(Uint8List bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }

  void _fitBounds() {
    if (_controller == null || widget.points.isEmpty) return;
    final sw = LatLng(
      widget.points.map((p) => p.position.latitude).reduce(min),
      widget.points.map((p) => p.position.longitude).reduce(min),
    );
    final ne = LatLng(
      widget.points.map((p) => p.position.latitude).reduce(max),
      widget.points.map((p) => p.position.longitude).reduce(max),
    );
    _controller!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: sw, northeast: ne),
        48,
      ),
    );
  }

  Future<void> _saveMapImage() async {
    setState(() => _isSaving = true);
    try {
      if (!await Gal.hasAccess()) {
        await Gal.requestAccess();
      }
      final imageBytes = await _controller?.takeSnapshot();
      if (imageBytes == null) {
        throw _routeText(
          widget.locale,
          '지도 이미지를 만들 수 없었어요.',
          '地図画像を作成できませんでした。',
        );
      }
      await Gal.putImageBytes(
        imageBytes,
        album: _routeText(widget.locale, '우리의 여행기록', '私たちの旅行記録'),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _routeText(
                widget.locale,
                '지도가 갤러리에 저장되었습니다.',
                '地図をギャラリーに保存しました。',
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_routeText(widget.locale, '저장 실패', '保存失敗')}: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          RepaintBoundary(
            key: _repaintKey,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: widget.points.isNotEmpty
                    ? widget.points.first.position
                    : const LatLng(33.3617, 126.5292),
                zoom: 13,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              onMapCreated: (c) {
                _controller = c;
                Future.delayed(const Duration(milliseconds: 400), _fitBounds);
              },
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const Spacer(),
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: Icon(
                      _showMarkers ? Icons.location_on : Icons.location_off,
                      color: Colors.pinkAccent,
                    ),
                    onPressed: () =>
                        setState(() => _showMarkers = !_showMarkers),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(
                            Icons.save_alt,
                            color: Colors.pinkAccent,
                          ),
                          onPressed: _saveMapImage,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
