import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/common_providers.dart';
import '../../core/providers/mission_provider.dart';
import '../../core/providers/route_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/utils/translation_service.dart';

class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  final _controller = TextEditingController();
  final _customDeadlineController = TextEditingController();
  final _missionFocusNode = FocusNode();
  bool _isLoading = false;
  XFile? _selectedImage;
  int _deadlineOption = 24;

  @override
  void dispose() {
    _controller.dispose();
    _customDeadlineController.dispose();
    _missionFocusNode.dispose();
    super.dispose();
  }

  Future<void> _startRouteTracking() async {
    await ref
        .read(routeTrackingProvider.notifier)
        .start(ref.read(currentUserProvider));
    if (!mounted) return;
    final error = ref.read(routeTrackingProvider).error;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _stopRouteTracking() async {
    await ref.read(routeTrackingProvider.notifier).stopAndSave();
    if (!mounted) return;
    final error = ref.read(routeTrackingProvider).error;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? '여행 기록이 저장되었습니다.')));
  }

  Future<void> _showMissionComposer() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MissionComposerSheet(
        initialDeadlineOption: _deadlineOption,
        onSubmit:
            ({
              required String content,
              required int deadlineOption,
              required String customDeadline,
              required XFile? image,
            }) async {
              final previousText = _controller.text;
              final previousDeadline = _deadlineOption;
              final previousCustomDeadline = _customDeadlineController.text;
              final previousImage = _selectedImage;

              _controller.text = content;
              _deadlineOption = deadlineOption;
              _customDeadlineController.text = customDeadline;
              _selectedImage = image;
              final success = await _addMission();

              if (!success) {
                _controller.text = previousText;
                _deadlineOption = previousDeadline;
                _customDeadlineController.text = previousCustomDeadline;
                _selectedImage = previousImage;
              }
              return success;
            },
      ),
    );

    if (created == true && mounted) {
      setState(() {
        _deadlineOption = 24;
        _customDeadlineController.clear();
        _selectedImage = null;
      });
    }
  }

  Future<bool> _addMission() async {
    if (_controller.text.trim().isEmpty) return false;

    final deadlineHours = _parseDeadlineHours(
      _deadlineOption,
      _customDeadlineController.text,
    );
    if (deadlineHours == _invalidDeadlineHours) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('제한 시간은 숫자로 입력해 주세요.')));
      return false;
    }

    setState(() => _isLoading = true);

    final currentUserId = ref.read(currentUserProvider);
    final firebaseService = ref.read(firebaseServiceProvider);
    final missionId = const Uuid().v4();

    String? imageUrl;
    if (_selectedImage != null) {
      try {
        imageUrl = await firebaseService.uploadImage(
          File(_selectedImage!.path),
          'missions/$missionId/${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('사진 업로드 실패: $e')));
          setState(() => _isLoading = false);
        }
        return false;
      }
    }

    final now = DateTime.now();
    final newMission = Mission(
      id: missionId,
      content: _controller.text.trim(),
      originalImageUrl: imageUrl,
      creatorId: currentUserId,
      timestamp: now,
      deadline: deadlineHours == null
          ? null
          : now.add(Duration(hours: deadlineHours)),
    );

    try {
      await firebaseService.addMission(newMission);
      _controller.clear();
      setState(() => _selectedImage = null);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('미션을 등록했어요.')));
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('등록 실패: $e')));
      }
      return false;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final missionsAsync = ref.watch(missionStreamProvider);
    final routeTracking = ref.watch(routeTrackingProvider);
    final tr = ref.watch(translationProvider);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MainActionButton(
                        onPressed: _showMissionComposer,
                        icon: Icons.flag_rounded,
                        label: tr.locale.languageCode == 'ko'
                            ? '미션시작'
                            : 'ミッション開始',
                        backgroundColor: const Color(0xFFFFE7EF),
                        foregroundColor: Colors.pinkAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MainActionButton(
                        onPressed:
                            routeTracking.isTracking || routeTracking.isSaving
                            ? null
                            : _startRouteTracking,
                        icon: Icons.map_rounded,
                        label: tr.locale.languageCode == 'ko' ? '여행기록' : '旅行記録',
                        backgroundColor: const Color(0xFFE8F4FF),
                        foregroundColor: Colors.blueAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _RouteTrackingStatus(
                  state: routeTracking,
                  onStop: routeTracking.isSaving ? null : _stopRouteTracking,
                ),
              ],
            ),
          ),
          if (_isLoading)
            _ProgressOverlay(locale: tr.locale)
          else
            const SizedBox.shrink(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tr.mainOngoingMissions,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          Expanded(
            child: missionsAsync.when(
              data: (missions) {
                final ongoing = missions
                    .where(
                      (mission) => !mission.isCompleted && !mission.isFailed,
                    )
                    .toList();

                if (ongoing.isEmpty) {
                  return Center(
                    child: Text(
                      tr.missionEmpty,
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: ongoing.length,
                  itemBuilder: (context, index) =>
                      MissionCard(mission: ongoing[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

class _MainActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback? onPressed;

  const _MainActionButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final effectiveForeground = enabled ? foregroundColor : Colors.grey;
    final effectiveBackground = enabled ? backgroundColor : Colors.grey[100]!;

    return AspectRatio(
      aspectRatio: 1.55,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: effectiveBackground,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: effectiveForeground.withValues(
                alpha: enabled ? 0.25 : 0.1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: effectiveForeground.withValues(
                  alpha: enabled ? 0.12 : 0,
                ),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: enabled ? 0.72 : 0.45,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: effectiveForeground, size: 25),
                  ),
                  const SizedBox(height: 7),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        color: enabled ? const Color(0xFF4A4A4A) : Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

typedef MissionSubmitCallback =
    Future<bool> Function({
      required String content,
      required int deadlineOption,
      required String customDeadline,
      required XFile? image,
    });

class _MissionComposerSheet extends ConsumerStatefulWidget {
  final int initialDeadlineOption;
  final MissionSubmitCallback onSubmit;

  const _MissionComposerSheet({
    required this.initialDeadlineOption,
    required this.onSubmit,
  });

  @override
  ConsumerState<_MissionComposerSheet> createState() =>
      _MissionComposerSheetState();
}

class _MissionComposerSheetState extends ConsumerState<_MissionComposerSheet> {
  final _contentController = TextEditingController();
  final _customDeadlineController = TextEditingController();
  XFile? _image;
  late int _deadlineOption;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _deadlineOption = widget.initialDeadlineOption;
  }

  @override
  void dispose() {
    _contentController.dispose();
    _customDeadlineController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() => _image = image);
    }
  }

  Future<void> _submit() async {
    if (_contentController.text.trim().isEmpty || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    final success = await widget.onSubmit(
      content: _contentController.text.trim(),
      deadlineOption: _deadlineOption,
      customDeadline: _customDeadlineController.text,
      image: _image,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (success) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(translationProvider);
    final theme = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
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
                  const SizedBox(height: 16),
                  TextField(
                    controller: _contentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: tr.missionPlaceholder,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DeadlinePicker(
                    option: _deadlineOption,
                    customController: _customDeadlineController,
                    tr: tr,
                    onOptionChanged: (value) =>
                        setState(() => _deadlineOption = value),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _pickImage,
                    icon: Icon(
                      _image == null
                          ? Icons.add_photo_alternate_outlined
                          : Icons.photo_library,
                    ),
                    label: Text(tr.attachPhoto),
                  ),
                  if (_image != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_image!.path),
                        height: 160,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.pop(context, false),
                        child: Text(tr.close),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.secondary,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(tr.sendMission),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_isSubmitting) _ProgressOverlay(locale: tr.locale),
          ],
        ),
      ),
    );
  }
}

class _ProgressOverlay extends StatelessWidget {
  final Locale locale;

  const _ProgressOverlay({required this.locale});

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

class MissionCard extends ConsumerStatefulWidget {
  final Mission mission;
  const MissionCard({super.key, required this.mission});

  @override
  ConsumerState<MissionCard> createState() => _MissionCardState();
}

class _MissionCardState extends ConsumerState<MissionCard> {
  Timer? _timer;
  late Duration _timeLeft;
  bool _isWorking = false;

  @override
  void initState() {
    super.initState();
    _calculateTimeLeft();
    if (!widget.mission.isCompleted && widget.mission.deadline != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(_calculateTimeLeft);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculateTimeLeft() {
    final deadline = widget.mission.deadline;
    if (deadline == null) {
      _timeLeft = Duration.zero;
      return;
    }
    final referenceTime = widget.mission.isCompleted
        ? widget.mission.completedAt ?? DateTime.now()
        : DateTime.now();
    _timeLeft = deadline.difference(referenceTime);
    if (_timeLeft.isNegative) {
      _timeLeft = Duration.zero;
      _timer?.cancel();
    }
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return '00:00:00';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}';
  }

  Future<void> _attachProofImage() async {
    final mission = widget.mission;
    final currentUserId = ref.read(currentUserProvider);
    final picker = ImagePicker();
    final proof = await picker.pickImage(source: ImageSource.gallery);
    if (proof == null) return;

    setState(() => _isWorking = true);
    final firebaseService = ref.read(firebaseServiceProvider);

    try {
      final url = await firebaseService.uploadImage(
        File(proof.path),
        'proofs/${mission.id}/$currentUserId-${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await firebaseService.completeMission(mission.id, url, currentUserId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('미션 사진이 첨부되었습니다.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('첨부 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _editMission() async {
    final tr = ref.read(translationProvider);
    final controller = TextEditingController(text: widget.mission.content);
    final customDeadlineController = TextEditingController();
    int selectedDeadlineOption = _deadlineOptionFromMission(
      widget.mission,
      customDeadlineController,
    );
    String? validationError;

    final result = await showDialog<({String content, DateTime? deadline})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(tr.editMission),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: tr.missionPlaceholder,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                _DeadlinePicker(
                  option: selectedDeadlineOption,
                  customController: customDeadlineController,
                  tr: tr,
                  onOptionChanged: (value) => setDialogState(() {
                    selectedDeadlineOption = value;
                    validationError = null;
                  }),
                ),
                if (validationError != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      validationError!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(tr.close),
              ),
              ElevatedButton(
                onPressed: () {
                  final content = controller.text.trim();
                  if (content.isEmpty) return;
                  final deadlineHours = _parseDeadlineHours(
                    selectedDeadlineOption,
                    customDeadlineController.text,
                  );
                  if (deadlineHours == _invalidDeadlineHours) {
                    setDialogState(
                      () => validationError = '제한 시간을 숫자로 입력해 주세요.',
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, (
                    content: content,
                    deadline: deadlineHours == null
                        ? null
                        : DateTime.now().add(Duration(hours: deadlineHours)),
                  ));
                },
                child: Text(tr.edit),
              ),
            ],
          );
        },
      ),
    );

    controller.dispose();
    customDeadlineController.dispose();
    if (result == null) return;

    try {
      await ref
          .read(firebaseServiceProvider)
          .updateMission(widget.mission.id, result.content, result.deadline);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('수정 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mission = widget.mission;
    final currentUserId = ref.watch(currentUserProvider);
    final tr = ref.watch(translationProvider);
    final theme = Theme.of(context);
    final canEdit = mission.creatorId == currentUserId;
    final canAttachProof = !mission.isCompleted && !mission.isFailed;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: isPartnerAUser(mission.creatorId)
                      ? Colors.pink[50]
                      : Colors.blue[50],
                  child: Text(
                    mission.creatorId.substring(0, 1),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isPartnerAUser(mission.creatorId)
                          ? Colors.pink
                          : Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  mission.creatorId,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (mission.deadline != null)
                  Text(
                    _formatDuration(_timeLeft),
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (mission.originalImageUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    mission.originalImageUrl!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(
                          height: 150,
                          child: Center(child: Icon(Icons.broken_image)),
                        ),
                  ),
                ),
              ),
            Text(
              mission.content,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            if (mission.deadline != null)
              Text(
                '${tr.timeLimit}: ${DateFormat('MM/dd HH:mm').format(mission.deadline!)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              runSpacing: 4,
              children: [
                if (canAttachProof)
                  ElevatedButton.icon(
                    onPressed: _isWorking ? null : _attachProofImage,
                    icon: const Icon(Icons.attach_file, size: 18),
                    label: Text(
                      tr.missionProofBtn,
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.tertiary,
                      foregroundColor: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                if (canEdit)
                  IconButton(
                    tooltip: tr.edit,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: _editMission,
                  ),
                if (canEdit)
                  IconButton(
                    tooltip: tr.delete,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.grey,
                      size: 20,
                    ),
                    onPressed: () => ref
                        .read(firebaseServiceProvider)
                        .deleteMission(mission.id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteTrackingStatus extends StatelessWidget {
  final RouteTrackingState state;
  final VoidCallback? onStop;

  const _RouteTrackingStatus({required this.state, required this.onStop});

  @override
  Widget build(BuildContext context) {
    final isTracking = state.isTracking;
    final text = isTracking
        ? '현재 여행 기록중 ${_formatRouteDuration(state.elapsed)}째 · ${_formatRouteDistance(state.totalDistanceMeters)} 이동중'
        : '현재 기록 중인 여행이 없어요.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isTracking ? Colors.pink[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTracking ? Colors.pinkAccent.shade100 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isTracking ? Icons.navigation : Icons.route_outlined,
            color: isTracking ? Colors.pinkAccent : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.isSaving ? '여행 기록을 처리하는 중입니다...' : text,
              style: TextStyle(
                fontSize: 12,
                color: isTracking ? Colors.pink[700] : Colors.grey[700],
                fontWeight: isTracking ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (isTracking)
            TextButton(onPressed: onStop, child: const Text('기록 중지')),
        ],
      ),
    );
  }
}

const int _deadlineNoLimit = -1;
const int _deadlineCustom = 0;
const int _invalidDeadlineHours = -999999;
const Set<int> _presetDeadlineHours = {6, 12, 24, 48};

int? _parseDeadlineHours(int option, String customText) {
  if (option == _deadlineNoLimit) {
    return null;
  }

  if (option == _deadlineCustom) {
    final hours = int.tryParse(customText.trim());
    if (hours == null || hours <= 0) {
      return _invalidDeadlineHours;
    }
    return hours.clamp(1, 720).toInt();
  }

  return option;
}

int _deadlineOptionFromMission(
  Mission mission,
  TextEditingController customController,
) {
  final deadline = mission.deadline;
  if (deadline == null) {
    return _deadlineNoLimit;
  }

  final minutesLeft = deadline.difference(DateTime.now()).inMinutes;
  final hoursLeft = minutesLeft <= 0 ? 1 : (minutesLeft / 60).ceil();
  if (_presetDeadlineHours.contains(hoursLeft)) {
    return hoursLeft;
  }

  customController.text = hoursLeft.toString();
  return _deadlineCustom;
}

class _DeadlinePicker extends StatelessWidget {
  final int option;
  final TextEditingController customController;
  final TranslationService tr;
  final ValueChanged<int> onOptionChanged;

  const _DeadlinePicker({
    required this.option,
    required this.customController,
    required this.tr,
    required this.onOptionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final customLabel = tr.locale.languageCode == 'ko' ? '직접 입력' : '直接入力';
    final hourLabel = tr.locale.languageCode == 'ko' ? '시간' : '時間';
    final dropdown = DropdownButtonFormField<int>(
      key: ValueKey(option),
      initialValue: option,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: tr.timeLimit,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      items: [
        DropdownMenuItem(value: _deadlineNoLimit, child: Text(tr.noLimit)),
        const DropdownMenuItem(value: 6, child: Text('6h')),
        const DropdownMenuItem(value: 12, child: Text('12h')),
        const DropdownMenuItem(value: 24, child: Text('24h')),
        const DropdownMenuItem(value: 48, child: Text('48h')),
        DropdownMenuItem(value: _deadlineCustom, child: Text(customLabel)),
      ],
      onChanged: (value) {
        if (value != null) {
          onOptionChanged(value);
        }
      },
    );

    if (option != _deadlineCustom) {
      return dropdown;
    }

    final customField = TextField(
      controller: customController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: hourLabel,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [dropdown, const SizedBox(height: 8), customField],
    );
  }
}

String _formatRouteDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return '$hours시간 $minutes분';
  }
  return '$minutes분';
}

String _formatRouteDistance(double meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }
  return '${meters.round()}m';
}
