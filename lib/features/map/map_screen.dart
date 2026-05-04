import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/common_providers.dart';
import '../../core/providers/map_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/utils/places_service.dart';
import '../../core/utils/translation_service.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const _allCategory = '전체';
  static const _defaultCategories = ['데이트', '맛집', '카페', '산책'];

  GoogleMapController? _mapController;
  final _placesService = GooglePlacesService();
  final _uuid = const Uuid();
  Timer? _locationShareTimer;
  LatLng _mapCenter = const LatLng(33.3617, 126.5292);
  List<NearbyPlace> _nearbyPlaces = [];
  bool _placesLoading = false;
  bool _locationLoading = false;
  String? _placesError;
  String _placeType = 'restaurant';
  String _selectedSpotCategory = _allCategory;
  bool _mapGuideVisible = true;
  BitmapDescriptor? _partnerASpotIcon;
  BitmapDescriptor? _partnerBSpotIcon;
  BitmapDescriptor? _partnerALocationIcon;
  BitmapDescriptor? _partnerBLocationIcon;
  final Map<String, BitmapDescriptor> _photoSpotIcons = {};

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(33.3617, 126.5292),
    zoom: 10.0,
  );

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNearbyPlaces();
      _shareCurrentLocationSilently();
      _startLocationSharing();
    });
  }

  @override
  void dispose() {
    _locationShareTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMarkerIcons() async {
    final partnerA = await _createHeartMarker(Colors.redAccent);
    final partnerB = await _createHeartMarker(Colors.blueAccent);
    final partnerALocation = await _createUserLocationMarker(
      'images/girl.png',
      Colors.redAccent,
    );
    final partnerBLocation = await _createUserLocationMarker(
      'images/boy.png',
      Colors.blueAccent,
    );
    if (!mounted) return;
    setState(() {
      _partnerASpotIcon = partnerA;
      _partnerBSpotIcon = partnerB;
      _partnerALocationIcon = partnerALocation;
      _partnerBLocationIcon = partnerBLocation;
    });
  }

  Future<void> _loadNearbyPlaces({String? type, LatLng? location}) async {
    final nextType = type ?? _placeType;
    final searchLocation = location ?? _mapCenter;

    setState(() {
      _placeType = nextType;
      _placesLoading = true;
      _placesError = null;
    });

    try {
      final places = await _placesService
          .searchPetFriendlyNearby(
            location: searchLocation,
            includedPrimaryType: nextType,
            isKorean: ref.read(localeProvider).languageCode == 'ko',
          )
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;
      setState(() {
        _nearbyPlaces = places;
        _placesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _nearbyPlaces = [];
        _placesError = e.toString();
        _placesLoading = false;
      });
    }
  }

  void _startLocationSharing() {
    _locationShareTimer?.cancel();
    _locationShareTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      _shareCurrentLocationSilently();
    });
  }

  Future<void> _shareCurrentLocationSilently() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await _saveSharedLocation(position);
    } catch (_) {
      // Silent refresh should never interrupt map use.
    }
  }

  Future<void> _saveSharedLocation(Position position) {
    final currentUser = ref.read(currentUserProvider);
    return ref
        .read(firebaseServiceProvider)
        .updateSharedUserLocation(
          currentUser,
          LatLng(position.latitude, position.longitude),
        );
  }

  Future<void> _addSpotDialog(LatLng position) async {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final customCategoryController = TextEditingController();
    final tr = ref.read(translationProvider);
    String selectedCategory = _defaultCategories.first;
    XFile? selectedImage;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          String categoryToSave() {
            final custom = customCategoryController.text.trim();
            return custom.isNotEmpty ? custom : selectedCategory;
          }

          Future<void> pickImage() async {
            final picker = ImagePicker();
            final image = await picker.pickImage(source: ImageSource.gallery);
            if (image != null) {
              setDialogState(() => selectedImage = image);
            }
          }

          Future<void> saveSpot() async {
            final name = nameController.text.trim();
            if (name.isEmpty || isSaving) return;
            setDialogState(() => isSaving = true);

            try {
              String? imageUrl;
              if (selectedImage != null) {
                imageUrl = await ref
                    .read(firebaseServiceProvider)
                    .uploadImage(
                      File(selectedImage!.path),
                      'spots/${DateTime.now().millisecondsSinceEpoch}.jpg',
                    );
              }

              final newSpot = DateSpot(
                id: _uuid.v4(),
                name: name,
                category: categoryToSave(),
                address: addressController.text.trim().isEmpty
                    ? null
                    : addressController.text.trim(),
                imageUrl: imageUrl,
                position: position,
                creatorId: ref.read(currentUserProvider),
                timestamp: DateTime.now(),
              );

              await ref.read(firebaseServiceProvider).addDateSpot(newSpot);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            } catch (e) {
              if (dialogContext.mounted) {
                setDialogState(() => isSaving = false);
                ScaffoldMessenger.of(
                  dialogContext,
                ).showSnackBar(SnackBar(content: Text('장소 저장 실패: $e')));
              }
            }
          }

          return Stack(
            children: [
              AlertDialog(
                title: const Text('장소 추가'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: '장소 이름',
                          border: OutlineInputBorder(),
                        ),
                        autofocus: true,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: addressController,
                        decoration: const InputDecoration(
                          labelText: '주소',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: '카테고리',
                          border: OutlineInputBorder(),
                        ),
                        items: _defaultCategories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                        onChanged: isSaving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setDialogState(
                                    () => selectedCategory = value,
                                  );
                                }
                              },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: customCategoryController,
                        enabled: !isSaving,
                        decoration: const InputDecoration(
                          labelText: '카테고리 직접 입력',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: isSaving ? null : pickImage,
                        icon: Icon(
                          selectedImage == null
                              ? Icons.add_photo_alternate_outlined
                              : Icons.photo_library,
                        ),
                        label: const Text('사진 추가'),
                      ),
                      if (selectedImage != null) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(selectedImage!.path),
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.pop(dialogContext),
                    child: Text(tr.close),
                  ),
                  ElevatedButton(
                    onPressed: isSaving ? null : saveSpot,
                    child: const Text('저장'),
                  ),
                ],
              ),
              if (isSaving)
                _MapProgressOverlay(locale: ref.read(localeProvider)),
            ],
          );
        },
      ),
    );

    nameController.dispose();
    addressController.dispose();
    customCategoryController.dispose();
  }

  Future<void> _showPlaceSearchDialog() async {
    final tr = ref.read(translationProvider);
    final controller = TextEditingController();
    List<NearbyPlace> results = [];
    bool isSearching = false;
    String? error;

    final selectedPlace = await showDialog<NearbyPlace>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> search() async {
            if (controller.text.trim().isEmpty) return;
            setDialogState(() {
              isSearching = true;
              error = null;
            });
            try {
              final places = await _placesService.searchText(
                query: controller.text,
                isKorean: ref.read(localeProvider).languageCode == 'ko',
                locationBias: _mapCenter,
              );
              if (!dialogContext.mounted) return;
              setDialogState(() {
                results = places;
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

          return AlertDialog(
            title: Text(tr.placeSearch),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: tr.searchByPlace,
                      suffixIcon: IconButton(
                        onPressed: isSearching ? null : search,
                        icon: const Icon(Icons.search),
                      ),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => search(),
                  ),
                  if (isSearching)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    )
                  else if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final place = results[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(place.name),
                            subtitle: Text(place.address),
                            onTap: () => Navigator.pop(dialogContext, place),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(tr.close),
              ),
            ],
          );
        },
      ),
    );

    controller.dispose();
    if (selectedPlace != null) {
      await _saveSearchedPlace(selectedPlace);
    }
  }

  Future<void> _saveSearchedPlace(NearbyPlace place) async {
    _showBlockingProgress();
    final spot = DateSpot(
      id: _uuid.v4(),
      name: place.name,
      category: _categoryForPlace(place),
      address: place.address,
      position: place.position,
      creatorId: ref.read(currentUserProvider),
      timestamp: DateTime.now(),
    );

    try {
      await ref.read(firebaseServiceProvider).addDateSpot(spot);
      if (!mounted) return;
      _mapCenter = place.position;
      ref.read(currentMapLocationProvider.notifier).setLocation(place.position);
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(place.position, 15),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('장소 저장 실패: $e')));
      }
    } finally {
      _hideBlockingProgress();
    }
  }

  void _showBlockingProgress() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MapProgressOverlay(locale: ref.read(localeProvider)),
    );
  }

  void _hideBlockingProgress() {
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _openNaverMapForPlace(NearbyPlace place) async {
    final query = Uri.encodeComponent(
      [place.name, place.address].where((part) => part.isNotEmpty).join(' '),
    );
    final name = Uri.encodeComponent(place.name);
    final appName = Uri.encodeComponent('com.bibiandus.ourspringdays');
    final naverUrl = Uri.parse(
      'nmap://place?lat=${place.position.latitude}&lng=${place.position.longitude}&name=$name&appname=$appName',
    );
    final naverWebUrl = Uri.parse('https://map.naver.com/p/search/$query');
    final playStoreUrl = Uri.parse('market://details?id=com.nhn.android.nmap');
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;

    try {
      if (await launchUrl(naverUrl, mode: LaunchMode.externalApplication)) {
        return;
      }

      if (isAndroid &&
          await launchUrl(playStoreUrl, mode: LaunchMode.externalApplication)) {
        return;
      }

      await launchUrl(naverWebUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      try {
        await launchUrl(naverWebUrl, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('네이버지도 열기 실패: $e')));
      }
    }
  }

  void _showSpotDetailSheet(DateSpot spot) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomPadding = MediaQuery.of(sheetContext).viewPadding.bottom;
        return Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomPadding),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                spot.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                [
                  spot.category,
                  if (spot.address != null && spot.address!.isNotEmpty)
                    spot.address!,
                  'By ${spot.creatorId}',
                ].join(' / '),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              if (spot.imageUrl != null && spot.imageUrl!.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    spot.imageUrl!,
                    height: 180,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(
                          height: 120,
                          child: Center(child: Icon(Icons.broken_image)),
                        ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _editSpotDialog(spot);
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('수정'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _confirmDeleteSpot(spot);
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('삭제'),
                  ),
                  if (spot.imageUrl != null && spot.imageUrl!.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () => _showSpotPhoto(spot),
                      icon: const Icon(Icons.photo_outlined, size: 18),
                      label: const Text('사진 보기'),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editSpotDialog(DateSpot spot) async {
    final nameController = TextEditingController(text: spot.name);
    final addressController = TextEditingController(text: spot.address ?? '');
    final customCategoryController = TextEditingController();
    String selectedCategory = _defaultCategories.contains(spot.category)
        ? spot.category
        : _defaultCategories.first;
    if (!_defaultCategories.contains(spot.category)) {
      customCategoryController.text = spot.category;
    }
    XFile? selectedImage;
    var currentImageUrl = spot.imageUrl;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          String categoryToSave() {
            final custom = customCategoryController.text.trim();
            return custom.isNotEmpty ? custom : selectedCategory;
          }

          Future<void> pickImage() async {
            final picker = ImagePicker();
            final image = await picker.pickImage(source: ImageSource.gallery);
            if (image != null) {
              setDialogState(() => selectedImage = image);
            }
          }

          Future<void> saveSpot() async {
            final name = nameController.text.trim();
            if (name.isEmpty || isSaving) return;
            setDialogState(() => isSaving = true);

            try {
              if (selectedImage != null) {
                currentImageUrl = await ref
                    .read(firebaseServiceProvider)
                    .uploadImage(
                      File(selectedImage!.path),
                      'spots/${spot.id}/${DateTime.now().millisecondsSinceEpoch}.jpg',
                    );
              }

              final updatedSpot = DateSpot(
                id: spot.id,
                name: name,
                category: categoryToSave(),
                address: addressController.text.trim().isEmpty
                    ? null
                    : addressController.text.trim(),
                imageUrl: currentImageUrl,
                position: spot.position,
                creatorId: spot.creatorId,
                timestamp: spot.timestamp,
              );

              await ref
                  .read(firebaseServiceProvider)
                  .updateDateSpot(updatedSpot);
              _photoSpotIcons.remove(spot.id);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            } catch (e) {
              if (dialogContext.mounted) {
                setDialogState(() => isSaving = false);
                ScaffoldMessenger.of(
                  dialogContext,
                ).showSnackBar(SnackBar(content: Text('장소 수정 실패: $e')));
              }
            }
          }

          return Stack(
            children: [
              AlertDialog(
                title: const Text('장소 수정'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        enabled: !isSaving,
                        decoration: const InputDecoration(
                          labelText: '마커명',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: addressController,
                        enabled: !isSaving,
                        decoration: const InputDecoration(
                          labelText: '주소',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: '카테고리',
                          border: OutlineInputBorder(),
                        ),
                        items: _defaultCategories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                        onChanged: isSaving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setDialogState(
                                    () => selectedCategory = value,
                                  );
                                }
                              },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: customCategoryController,
                        enabled: !isSaving,
                        decoration: const InputDecoration(
                          labelText: '카테고리 직접 입력',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: isSaving ? null : pickImage,
                        icon: Icon(
                          selectedImage == null
                              ? Icons.add_photo_alternate_outlined
                              : Icons.photo_library,
                        ),
                        label: Text(
                          currentImageUrl == null ? '사진 추가' : '사진 변경',
                        ),
                      ),
                      if (selectedImage != null) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(selectedImage!.path),
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ] else if (currentImageUrl != null &&
                          currentImageUrl!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            currentImageUrl!,
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.pop(dialogContext),
                    child: const Text('닫기'),
                  ),
                  ElevatedButton(
                    onPressed: isSaving ? null : saveSpot,
                    child: const Text('저장'),
                  ),
                ],
              ),
              if (isSaving)
                _MapProgressOverlay(locale: ref.read(localeProvider)),
            ],
          );
        },
      ),
    );

    nameController.dispose();
    addressController.dispose();
    customCategoryController.dispose();
  }

  Future<void> _confirmDeleteSpot(DateSpot spot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('마커 삭제'),
        content: Text('${spot.name} 마커를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('닫기'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    _showBlockingProgress();
    try {
      await ref.read(firebaseServiceProvider).deleteDateSpot(spot.id);
      _photoSpotIcons.remove(spot.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('마커 삭제 실패: $e')));
      }
    } finally {
      _hideBlockingProgress();
    }
  }

  Future<void> _moveToCurrentLocation() async {
    final tr = ref.read(translationProvider);
    setState(() => _locationLoading = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw tr.locale.languageCode == 'ko'
            ? '기기의 위치 서비스를 켜 주세요.'
            : '端末の位置情報サービスをオンにしてください。';
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw tr.locale.languageCode == 'ko'
            ? '위치 권한이 필요합니다.'
            : '位置情報の権限が必要です。';
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        ).timeout(const Duration(seconds: 10));
      } on TimeoutException {
        position = await Geolocator.getLastKnownPosition();
      }
      if (position == null) {
        throw '현재 위치를 가져오지 못했어요. 잠시 후 다시 시도해 주세요.';
      }
      final target = LatLng(position.latitude, position.longitude);
      await _saveSharedLocation(position);

      if (!mounted) return;
      setState(() => _mapCenter = target);
      ref.read(currentMapLocationProvider.notifier).setLocation(target);
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(target, 15),
      );
      unawaited(_loadNearbyPlaces(location: target));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(translationProvider);
    final spotsAsync = ref.watch(dateSpotsStreamProvider);
    final locationsAsync = ref.watch(sharedUserLocationsProvider);
    final spotCategories = spotsAsync.maybeWhen(
      data: _categoriesForSpots,
      orElse: () => const [_allCategory],
    );

    final Set<Marker> savedSpotMarkers = spotsAsync.maybeWhen(
      data: (spots) {
        for (final spot in spots) {
          unawaited(_ensurePhotoSpotIcon(spot));
        }
        return spots
            .where(
              (spot) =>
                  _selectedSpotCategory == _allCategory ||
                  spot.category == _selectedSpotCategory,
            )
            .map(
              (spot) => Marker(
                markerId: MarkerId(spot.id),
                position: spot.position,
                infoWindow: InfoWindow(
                  title: spot.name,
                  snippet: [
                    spot.category,
                    if (spot.address != null && spot.address!.isNotEmpty)
                      spot.address!,
                    'By ${spot.creatorId}',
                  ].join(' / '),
                ),
                icon:
                    _photoSpotIcons[spot.id] ??
                    _savedSpotIconFor(spot.creatorId),
                onTap: () => _showSpotDetailSheet(spot),
              ),
            )
            .toSet();
      },
      orElse: () => <Marker>{},
    );
    final Set<Marker> nearbyPlaceMarkers = _nearbyPlaces
        .map(
          (place) => Marker(
            markerId: MarkerId('place_${place.id}'),
            position: place.position,
            infoWindow: InfoWindow(title: place.name, snippet: place.address),
            icon: BitmapDescriptor.defaultMarker,
            onTap: () => _openNaverMapForPlace(place),
          ),
        )
        .toSet();
    final Set<Marker> userLocationMarkers = locationsAsync.maybeWhen(
      data: (locations) => locations
          .where(_hasUsableLocation)
          .map(
            (location) => Marker(
              markerId: MarkerId('shared_location_${location.userId}'),
              position: location.position,
              zIndexInt: 3,
              infoWindow: InfoWindow(
                title: '${_displayUserName(location.userId)} 현재 위치',
                snippet: _formatSharedLocationTime(location.updatedAt),
              ),
              icon: _locationIconFor(location.userId),
            ),
          )
          .toSet(),
      orElse: () => <Marker>{},
    );
    final Set<Marker> markers = {
      ...nearbyPlaceMarkers,
      ...savedSpotMarkers,
      ...userLocationMarkers,
    };

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onMapCreated: (controller) => _mapController = controller,
            markers: markers,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            onCameraMove: (position) {
              _mapCenter = position.target;
              ref
                  .read(currentMapLocationProvider.notifier)
                  .setLocation(position.target);
            },
            onLongPress: _addSpotDialog,
          ),
          if (spotsAsync.isLoading)
            const Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          if (spotsAsync.hasError)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.redAccent.withValues(alpha: 0.8),
                child: Text(
                  'Map Error: ${spotsAsync.error}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          if (_mapGuideVisible)
            Positioned(
              top: 20,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 10),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.touch_app,
                          color: Colors.pinkAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tr.locale.languageCode == 'ko'
                                ? '지도를 꾹 눌러 장소를 저장하고, 애견 동반 주변 추천을 확인하세요.'
                                : '地図を長押しして保存し、ペット可の周辺おすすめを確認しましょう。',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.pink[300],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: tr.close,
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              setState(() => _mapGuideVisible = false),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _PlaceTypeButton(
                          label: tr.locale.languageCode == 'ko'
                              ? '애견 맛집'
                              : 'ペット可レストラン',
                          selected: _placeType == 'restaurant',
                          onPressed: _placesLoading
                              ? null
                              : () => _loadNearbyPlaces(type: 'restaurant'),
                        ),
                        const SizedBox(width: 8),
                        _PlaceTypeButton(
                          label: tr.locale.languageCode == 'ko'
                              ? '애견 카페'
                              : 'ペット可カフェ',
                          selected: _placeType == 'cafe',
                          onPressed: _placesLoading
                              ? null
                              : () => _loadNearbyPlaces(type: 'cafe'),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: tr.locale.languageCode == 'ko'
                              ? '현재 화면 주변 검색'
                              : 'この画面の周辺を検索',
                          onPressed: _placesLoading
                              ? null
                              : () => _loadNearbyPlaces(),
                          icon: _placesLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh, size: 20),
                        ),
                      ],
                    ),
                    if (spotCategories.length > 1) ...[
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: spotCategories
                              .map(
                                (category) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: _CategoryChip(
                                    label: category,
                                    selected: category == _selectedSpotCategory,
                                    onSelected: () => setState(
                                      () => _selectedSpotCategory = category,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                    if (_placesError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _placesError!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (!_mapGuideVisible)
            Positioned(
              top: 20,
              right: 16,
              child: IconButton.filledTonal(
                tooltip: tr.locale.languageCode == 'ko'
                    ? '지도 도구 열기'
                    : '地図ツールを開く',
                onPressed: () => setState(() => _mapGuideVisible = true),
                icon: const Icon(Icons.tune, size: 20),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'placeSearch',
            onPressed: _showPlaceSearchDialog,
            backgroundColor: Colors.white,
            foregroundColor: Colors.pinkAccent,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: Text(tr.placeSearch),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'currentLocation',
            onPressed: _locationLoading ? null : _moveToCurrentLocation,
            backgroundColor: Colors.white,
            child: _locationLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location, color: Colors.pinkAccent),
          ),
        ],
      ),
    );
  }

  List<String> _categoriesForSpots(List<DateSpot> spots) {
    final categories = <String>{};
    for (final spot in spots) {
      final category = spot.category.trim();
      if (category.isNotEmpty) {
        categories.add(category);
      }
    }

    if (_selectedSpotCategory != _allCategory &&
        !categories.contains(_selectedSpotCategory)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedSpotCategory = _allCategory);
      });
    }

    return [_allCategory, ...categories.toList()..sort()];
  }

  String _categoryForPlace(NearbyPlace place) {
    if (place.primaryType == 'cafe') return '카페';
    if (place.primaryType == 'restaurant') return '맛집';
    return '장소검색';
  }

  BitmapDescriptor _savedSpotIconFor(String creatorId) {
    if (_isPartnerB(creatorId)) {
      return _partnerBSpotIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
    return _partnerASpotIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose);
  }

  BitmapDescriptor _locationIconFor(String userId) {
    if (_isPartnerB(userId)) {
      return _partnerBLocationIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
    return _partnerALocationIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose);
  }

  bool _hasUsableLocation(SharedUserLocation location) {
    return location.position.latitude != 0 || location.position.longitude != 0;
  }

  String _displayUserName(String userId) {
    return _isPartnerB(userId)
        ? AppConstants.partnerBId
        : AppConstants.partnerAId;
  }

  String _formatSharedLocationTime(DateTime updatedAt) {
    final elapsed = DateTime.now().difference(updatedAt);
    if (elapsed.inMinutes < 1) return '방금 업데이트';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes}분 전 업데이트';
    if (elapsed.inHours < 24) return '${elapsed.inHours}시간 전 업데이트';
    return '${elapsed.inDays}일 전 업데이트';
  }

  void _showSpotPhoto(DateSpot spot) {
    final imageUrl = spot.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                spot.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (spot.address != null && spot.address!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  spot.address!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    height: 220,
                    child: Icon(Icons.broken_image),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<BitmapDescriptor> _createHeartMarker(Color color) async {
    const size = 80.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final textPainter = TextPainter(
      text: TextSpan(
        text: '♥',
        style: TextStyle(
          color: color,
          fontSize: 58,
          fontWeight: FontWeight.w800,
          shadows: const [
            Shadow(color: Colors.white, blurRadius: 5),
            Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    final image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData?.buffer.asUint8List() ?? Uint8List(0);
    return BitmapDescriptor.bytes(bytes, imagePixelRatio: 2.5);
  }

  Future<void> _ensurePhotoSpotIcon(DateSpot spot) async {
    final imageUrl = spot.imageUrl;
    if (imageUrl == null ||
        imageUrl.isEmpty ||
        _photoSpotIcons.containsKey(spot.id)) {
      return;
    }

    try {
      final icon = await _createPhotoHeartMarker(
        imageUrl,
        _spotColorFor(spot.creatorId),
      );
      if (!mounted) return;
      setState(() => _photoSpotIcons[spot.id] = icon);
    } catch (_) {
      // Fallback to the regular heart marker if a remote image cannot be decoded.
    }
  }

  Color _spotColorFor(String creatorId) {
    return _isPartnerB(creatorId) ? Colors.blueAccent : Colors.redAccent;
  }

  bool _isPartnerB(String userId) {
    return normalizeMapUserId(userId) == AppConstants.partnerBId;
  }

  Future<BitmapDescriptor> _createPhotoHeartMarker(
    String imageUrl,
    Color color,
  ) async {
    const size = 96.0;
    final response = await NetworkAssetBundle(Uri.parse(imageUrl)).load('');
    final image = await _decodeUiImage(response.buffer.asUint8List());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);
    final heartPainter = TextPainter(
      text: TextSpan(
        text: '♥',
        style: TextStyle(
          color: color,
          fontSize: 82,
          fontWeight: FontWeight.w900,
          shadows: const [
            Shadow(color: Colors.white, blurRadius: 5),
            Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    heartPainter.paint(canvas, Offset((size - heartPainter.width) / 2, -2));

    final photoRect = Rect.fromCenter(center: center, width: 42, height: 42);
    canvas.drawCircle(center, 25, Paint()..color = Colors.white);
    canvas.save();
    canvas.clipPath(Path()..addOval(photoRect));
    paintImage(
      canvas: canvas,
      rect: photoRect,
      image: image,
      fit: BoxFit.cover,
    );
    canvas.restore();
    canvas.drawCircle(
      center,
      22,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    final markerImage = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final byteData = await markerImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
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

  Future<BitmapDescriptor> _createUserLocationMarker(
    String assetPath,
    Color color,
  ) async {
    const size = 96.0;
    const avatarSize = 66.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);
    final image = await _loadUiImage(assetPath);

    canvas.drawCircle(
      center,
      41,
      Paint()..color = color.withValues(alpha: 0.22),
    );
    canvas.drawCircle(center, 35, Paint()..color = Colors.white);

    final avatarRect = Rect.fromCenter(
      center: center,
      width: avatarSize,
      height: avatarSize,
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(avatarRect));
    paintImage(
      canvas: canvas,
      rect: avatarRect,
      image: image,
      fit: BoxFit.cover,
    );
    canvas.restore();

    canvas.drawCircle(
      center,
      35,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawCircle(const Offset(72, 73), 10, Paint()..color = color);
    canvas.drawCircle(const Offset(72, 73), 4, Paint()..color = Colors.white);

    final markerImage = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final byteData = await markerImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final bytes = byteData?.buffer.asUint8List() ?? Uint8List(0);
    return BitmapDescriptor.bytes(bytes, imagePixelRatio: 2.5);
  }

  Future<ui.Image> _loadUiImage(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }
}

class _MapProgressOverlay extends StatelessWidget {
  final Locale locale;

  const _MapProgressOverlay({required this.locale});

  @override
  Widget build(BuildContext context) {
    final asset = locale.languageCode == 'ja'
        ? 'images/ing_jp.png'
        : 'images/ing_kor.png';
    return Positioned.fill(
      child: Container(
        color: Colors.white.withValues(alpha: 0.82),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(asset, height: 92, fit: BoxFit.contain),
              const SizedBox(height: 12),
              const SizedBox(width: 180, child: LinearProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceTypeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  const _PlaceTypeButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: selected ? Colors.pinkAccent : Colors.white,
        foregroundColor: selected ? Colors.white : Colors.pinkAccent,
        side: BorderSide(
          color: selected ? Colors.pinkAccent : Colors.pinkAccent.shade100,
        ),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      visualDensity: VisualDensity.compact,
      selectedColor: Colors.pinkAccent.withValues(alpha: 0.18),
      labelStyle: TextStyle(
        fontSize: 12,
        color: selected ? Colors.pinkAccent : Colors.black87,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: selected ? Colors.pinkAccent : Colors.pinkAccent.shade100,
      ),
    );
  }
}
