import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:gal/gal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/album_provider.dart';
import '../../core/providers/common_providers.dart';
import '../../core/providers/route_models.dart';
import '../../core/providers/map_provider.dart';
import '../../core/providers/mission_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/providers/user_profile_provider.dart';
import '../../core/utils/places_service.dart';
import '../../core/utils/translation_service.dart';

class AlbumScreen extends ConsumerStatefulWidget {
  const AlbumScreen({super.key});

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  final _placesService = GooglePlacesService();
  bool _isCreating = false;

  Future<void> _showCreateAlbumDialog() async {
    final tr = ref.read(translationProvider);
    final titleController = TextEditingController();
    final placeController = TextEditingController();
    List<XFile> selectedImages = [];
    NearbyPlace? selectedPlace;
    List<NearbyPlace> placeResults = [];
    bool isSearching = false;
    String? error;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickImages() async {
            final picker = ImagePicker();
            final images = await picker.pickMultiImage();
            if (images.isNotEmpty) {
              setDialogState(() => selectedImages = images);
            }
          }

          Future<void> searchPlace() async {
            if (placeController.text.trim().isEmpty) return;
            setDialogState(() {
              isSearching = true;
              error = null;
            });
            try {
              final places = await _placesService.searchText(
                query: placeController.text,
                isKorean: ref.read(localeProvider).languageCode == 'ko',
                locationBias: ref.read(currentMapLocationProvider),
              );
              if (!dialogContext.mounted) return;
              setDialogState(() {
                placeResults = places;
                isSearching = false;
              });
            } catch (e) {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                error = e.toString();
                isSearching = false;
              });
            }
          }

          Future<void> saveAlbum() async {
            final title = titleController.text.trim();
            if (selectedImages.isEmpty || title.isEmpty) return;

            setDialogState(() => _isCreating = true);
            final firebaseService = ref.read(firebaseServiceProvider);
            final currentUser = ref.read(currentUserProvider);

            try {
              final id = const Uuid().v4();
              final imageUrls = <String>[];
              for (var index = 0; index < selectedImages.length; index++) {
                final image = selectedImages[index];
                final imageUrl = await firebaseService.uploadImage(
                  File(image.path),
                  'albums/$id/${DateTime.now().millisecondsSinceEpoch}_$index.jpg',
                );
                imageUrls.add(imageUrl);
              }
              await firebaseService.addAlbumEntry(
                AlbumEntry(
                  id: id,
                  title: title,
                  imageUrls: imageUrls,
                  creatorId: currentUser,
                  placeName: selectedPlace?.name,
                  address: selectedPlace?.address,
                  position: selectedPlace?.position,
                  timestamp: DateTime.now(),
                ),
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            } catch (e) {
              setDialogState(() {
                error = e.toString();
                _isCreating = false;
              });
            }
          }

          return AlertDialog(
            title: Text(tr.createAlbum),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: tr.albumTitle,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isCreating ? null : pickImages,
                    icon: Icon(
                      selectedImages.isEmpty
                          ? Icons.photo_library_outlined
                          : Icons.photo_library,
                    ),
                    label: Text(
                      selectedImages.isEmpty
                          ? tr.albumPhoto
                          : '${selectedImages.length}장 선택됨',
                    ),
                  ),
                  if (selectedImages.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: selectedImages.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final image = selectedImages[index];
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(image.path),
                                  height: 110,
                                  width: 110,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: IconButton.filled(
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black54,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(28, 28),
                                  ),
                                  onPressed: _isCreating
                                      ? null
                                      : () {
                                          final next = [...selectedImages]
                                            ..removeAt(index);
                                          setDialogState(
                                            () => selectedImages = next,
                                          );
                                        },
                                  icon: const Icon(Icons.close, size: 14),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: placeController,
                    decoration: InputDecoration(
                      labelText: tr.placeSearch,
                      hintText: tr.searchByPlace,
                      suffixIcon: IconButton(
                        onPressed: isSearching ? null : searchPlace,
                        icon: const Icon(Icons.search),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => searchPlace(),
                  ),
                  if (selectedPlace != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(
                          label: Text(selectedPlace!.name),
                          onDeleted: () =>
                              setDialogState(() => selectedPlace = null),
                        ),
                      ),
                    ),
                  if (isSearching)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    )
                  else
                    ...placeResults.map(
                      (place) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(place.name),
                        subtitle: Text(place.address),
                        onTap: () {
                          setDialogState(() {
                            selectedPlace = place;
                            placeResults = [];
                            placeController.text = place.name;
                          });
                        },
                      ),
                    ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        error!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isCreating
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: Text(tr.close),
              ),
              ElevatedButton(
                onPressed: _isCreating ? null : saveAlbum,
                child: Text(tr.saveAlbum),
              ),
            ],
          );
        },
      ),
    );

    titleController.dispose();
    placeController.dispose();
    if (mounted) setState(() => _isCreating = false);

    if (created == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('?⑤쾾????λ릺?덉뒿?덈떎.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(translationProvider);
    final missionsAsync = ref.watch(missionStreamProvider);
    final albumsAsync = ref.watch(albumStreamProvider);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  tr.tabAlbum,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _showCreateAlbumDialog,
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 18,
                  ),
                  label: Text(tr.createAlbum),
                ),
              ],
            ),
          ),
          Expanded(
            child: missionsAsync.when(
              data: (missions) => albumsAsync.when(
                data: (albums) {
                  final albumItems = albums.map(_AlbumItem.fromAlbum).toList()
                    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
                  final missionItems =
                      missions
                          .where(
                            (m) => m.isCompleted && m.proofImageUrl != null,
                          )
                          .map(_AlbumItem.fromMission)
                          .toList()
                        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

                  if (albumItems.isEmpty && missionItems.isEmpty) {
                    return Center(child: Text(tr.missionEmpty));
                  }

                  return DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        const TabBar(
                          tabs: [
                            Tab(text: '?⑤쾾'),
                            Tab(text: '誘몄뀡'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildAlbumGrid(albumItems),
                              _buildAlbumGrid(missionItems),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumGrid(List<_AlbumItem> items) {
    if (items.isEmpty) {
      return const Center(child: Text('아직 사진이 없어요'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: () => _showAlbumDetail(context, item),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  item.imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.black54,
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAlbumDetail(BuildContext context, _AlbumItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AlbumDetailSheet(item: item),
    );
  }
}

class _AlbumItem {
  final String id;
  final String title;
  final List<String> imageUrls;
  final String subtitle;
  final DateTime timestamp;
  final bool isMission;
  final String creatorId;
  final String? placeName;
  final String? address;
  final String? proposerId;
  final String? challengerId;

  _AlbumItem({
    required this.id,
    required this.title,
    required this.imageUrls,
    required this.subtitle,
    required this.timestamp,
    required this.isMission,
    required this.creatorId,
    this.placeName,
    this.address,
    this.proposerId,
    this.challengerId,
  });

  String get imageUrl => imageUrls.isEmpty ? '' : imageUrls.first;

  factory _AlbumItem.fromAlbum(AlbumEntry entry) {
    final place = entry.placeName ?? entry.address;
    return _AlbumItem(
      id: entry.id,
      title: entry.title,
      imageUrls: entry.imageUrls,
      subtitle: [
        entry.creatorId,
        if (place != null && place.isNotEmpty) place,
      ].join(' / '),
      timestamp: entry.timestamp,
      isMission: false,
      creatorId: entry.creatorId,
      placeName: entry.placeName,
      address: entry.address,
    );
  }

  factory _AlbumItem.fromMission(Mission mission) {
    return _AlbumItem(
      id: 'mission_${mission.id}',
      title: mission.content,
      imageUrls: [mission.proofImageUrl!],
      subtitle: [
        'Proposer ${mission.creatorId}',
        if (mission.winnerId != null) 'Challenger ${mission.winnerId}',
      ].join(' / '),
      timestamp: mission.completedAt ?? mission.timestamp,
      isMission: true,
      creatorId: mission.winnerId ?? mission.creatorId,
      proposerId: mission.creatorId,
      challengerId: mission.winnerId,
    );
  }
}

class _AlbumDetailSheet extends ConsumerStatefulWidget {
  final _AlbumItem item;

  const _AlbumDetailSheet({required this.item});

  @override
  ConsumerState<_AlbumDetailSheet> createState() => _AlbumDetailSheetState();
}

class _AlbumDetailSheetState extends ConsumerState<_AlbumDetailSheet> {
  final _pageController = PageController();
  final _commentController = TextEditingController();
  bool _isSaving = false;
  bool _isSendingComment = false;
  int _photoIndex = 0;

  _AlbumItem get item => widget.item;
  String get _currentImageUrl => item.imageUrls.isEmpty
      ? ''
      : item.imageUrls[_photoIndex.clamp(0, item.imageUrls.length - 1).toInt()];

  @override
  void dispose() {
    _pageController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final placeLabel = _placeLabel(item);
    final currentUserId = ref.watch(currentUserProvider);
    final commentsAsync = item.isMission
        ? const AsyncValue<List<AlbumComment>>.data([])
        : ref.watch(albumCommentsProvider(item.id));
    final creatorProfile = ref
        .watch(userProfileProvider(item.creatorId))
        .maybeWhen(data: (profile) => profile, orElse: () => null);
    final proposerProfile = item.proposerId == null
        ? null
        : ref
              .watch(userProfileProvider(item.proposerId!))
              .maybeWhen(data: (profile) => profile, orElse: () => null);
    final challengerProfile = item.challengerId == null
        ? null
        : ref
              .watch(userProfileProvider(item.challengerId!))
              .maybeWhen(data: (profile) => profile, orElse: () => null);
    final creatorName = creatorProfile?.displayName ?? item.creatorId;
    final proposerName =
        proposerProfile?.displayName ?? item.proposerId ?? item.creatorId;
    final challengerName =
        challengerProfile?.displayName ?? item.challengerId ?? '';

    return Container(
      height: size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat('yyyy.MM.dd HH:mm').format(item.timestamp),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 4),
                if (item.isMission)
                  Text(
                    [
                      if (item.proposerId != null) '?쒖븞??$proposerName',
                      if (item.challengerId != null) '?꾩쟾??$challengerName',
                    ].join(' / '),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  )
                else
                  Text(
                    ['올린 사람 $creatorName', ?placeLabel].join(' / '),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    Container(
                      color: Colors.grey[100],
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: item.imageUrls.length,
                        onPageChanged: (index) =>
                            setState(() => _photoIndex = index),
                        itemBuilder: (context, index) => Image.network(
                          item.imageUrls[index],
                          fit: BoxFit.contain,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                                child: Icon(Icons.broken_image, size: 48),
                              ),
                        ),
                      ),
                    ),
                    if (item.imageUrls.length > 1)
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            child: Text(
                              '${_photoIndex + 1} / ${item.imageUrls.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (!item.isMission)
            _AlbumCommentPanel(
              commentsAsync: commentsAsync,
              currentUserId: currentUserId,
              controller: _commentController,
              isSending: _isSendingComment,
              onSend: _sendAlbumComment,
              onDelete: _deleteAlbumComment,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _showSaveOptions,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_alt),
                label: Text(_isSaving ? '저장 중' : '저장'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendAlbumComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _isSendingComment || item.isMission) {
      return;
    }
    setState(() => _isSendingComment = true);
    _commentController.clear();
    final currentUserId = ref.read(currentUserProvider);
    final profile = ref
        .read(userProfileProvider(currentUserId))
        .maybeWhen(data: (profile) => profile, orElse: () => null);
    final comment = AlbumComment(
      id: const Uuid().v4(),
      albumId: item.id,
      authorId: currentUserId,
      authorNickname: profile?.displayName ?? currentUserId,
      authorPhotoUrl: profile?.photoUrl,
      content: content,
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(firebaseServiceProvider).addAlbumComment(item.id, comment);
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      _commentController.text = content;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('?볤? ????ㅽ뙣: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingComment = false);
      }
    }
  }

  Future<void> _deleteAlbumComment(AlbumComment comment) async {
    await ref
        .read(firebaseServiceProvider)
        .deleteAlbumComment(item.id, comment.id);
  }

  Future<void> _showSaveOptions() async {
    var decorated = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('???諛⑹떇'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('?쇰컲')),
                  ButtonSegment(value: true, label: Text('?뚮쭏 1')),
                ],
                selected: {decorated},
                onSelectionChanged: (value) =>
                    setDialogState(() => decorated = value.first),
              ),
              if (decorated) ...[
                const SizedBox(height: 12),
                Text(
                  '?ъ쭊 諛⑺뼢???곕씪 Hmode/Wmode 諛곌꼍???먮룞 ?곸슜?⑸땲??',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('닫기'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await _saveImage(decorated: decorated);
    }
  }

  Future<void> _saveImage({required bool decorated}) async {
    setState(() => _isSaving = true);
    try {
      if (!await Gal.hasAccess()) {
        await Gal.requestAccess();
      }
      final bytes = await _downloadImageBytes(_currentImageUrl);
      final output = decorated ? await _buildDecoratedImage(bytes) : bytes;
      await Gal.putImageBytes(output, album: 'Our Spring Days');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('?ъ쭊????ν뻽?댁슂.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('????ㅽ뙣: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<Uint8List> _downloadImageBytes(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw 'image download failed (${response.statusCode})';
    }
    return response.bodyBytes;
  }

  Future<Uint8List> _buildDecoratedImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final portrait = image.height >= image.width;
    final background = await _loadThemeBackground(
      portrait ? 'images/Hmode.png' : 'images/Wmode.png',
    );
    final canvasWidth = background.width.toDouble();
    final canvasHeight = background.height.toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(canvasWidth, canvasHeight);

    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: background,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
    );

    final photoRect = _themePhotoRect(size, portrait);
    canvas.drawRRect(
      RRect.fromRectAndRadius(photoRect.inflate(8), const Radius.circular(24)),
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
    paintImage(
      canvas: canvas,
      rect: photoRect,
      image: image,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    final rendered = await recorder.endRecording().toImage(
      canvasWidth.toInt(),
      canvasHeight.toInt(),
    );
    final byteData = await rendered.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<ui.Image> _loadThemeBackground(String assetPath) async {
    final data = await DefaultAssetBundle.of(context).load(assetPath);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(data.buffer.asUint8List(), completer.complete);
    return completer.future;
  }

  Rect _themePhotoRect(Size size, bool portrait) {
    if (portrait) {
      return Rect.fromLTWH(
        size.width * 0.14,
        size.height * 0.16,
        size.width * 0.72,
        size.height * 0.58,
      );
    }
    return Rect.fromLTWH(
      size.width * 0.12,
      size.height * 0.18,
      size.width * 0.76,
      size.height * 0.58,
    );
  }

  String? _placeLabel(_AlbumItem item) {
    final place = item.placeName?.trim();
    final address = item.address?.trim();
    if (place != null &&
        place.isNotEmpty &&
        address != null &&
        address.isNotEmpty) {
      return '$place / $address';
    }
    if (address != null && address.isNotEmpty) return address;
    if (place != null && place.isNotEmpty) return place;
    return null;
  }
}

class _AlbumCommentPanel extends StatelessWidget {
  final AsyncValue<List<AlbumComment>> commentsAsync;
  final String currentUserId;
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final ValueChanged<AlbumComment> onDelete;

  const _AlbumCommentPanel({
    required this.commentsAsync,
    required this.currentUserId,
    required this.controller,
    required this.isSending,
    required this.onSend,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      child: Column(
        children: [
          Expanded(
            child: commentsAsync.when(
              data: (comments) => comments.isEmpty
                  ? Center(
                      child: Text(
                        '?꾩쭅 肄붾찘?멸? ?놁뼱??',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: comments.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _AlbumCommentTile(
                        comment: comments[index],
                        isMine: comments[index].authorId == currentUserId,
                        onDelete: () => onDelete(comments[index]),
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('?볤? ?ㅻ쪟: $error')),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: '코멘트를 남겨보세요',
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
          ),
        ],
      ),
    );
  }
}

class _AlbumCommentTile extends ConsumerWidget {
  final AlbumComment comment;
  final bool isMine;
  final VoidCallback onDelete;

  const _AlbumCommentTile({
    required this.comment,
    required this.isMine,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref
        .watch(userProfileProvider(comment.authorId))
        .maybeWhen(data: (profile) => profile, orElse: () => null);
    final authorName = profile?.displayName ?? comment.authorNickname;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: isMine
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        Flexible(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isMine ? const Color(0xFFFFE7EF) : Colors.grey[100],
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    authorName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(comment.content),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('MM.dd HH:mm').format(comment.createdAt),
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onDelete,
                          child: Text(
                            '??젣',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
