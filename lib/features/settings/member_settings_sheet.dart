import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/common_providers.dart';
import '../../core/providers/user_profile_provider.dart';
import '../../core/providers/user_provider.dart';

class MemberSettingsScreen extends StatelessWidget {
  const MemberSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: const MemberSettingsSheet(showHeader: false),
    );
  }
}

class MemberSettingsSheet extends ConsumerStatefulWidget {
  final bool showHeader;

  const MemberSettingsSheet({super.key, this.showHeader = true});

  @override
  ConsumerState<MemberSettingsSheet> createState() =>
      _MemberSettingsSheetState();
}

class _MemberSettingsSheetState extends ConsumerState<MemberSettingsSheet> {
  final _nicknameController = TextEditingController();
  final _loginIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _partnerCodeController = TextEditingController();
  String _gender = '여성';
  bool _isBusy = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _loginIdController.dispose();
    _passwordController.dispose();
    _partnerCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(userProfileProvider(currentUser));

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: profileAsync.when(
          data: (profile) => SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showHeader) ...[
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '회원 설정',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (!profile.isRegistered)
                  _buildRegisterForm(currentUser)
                else
                  _buildRegisteredProfile(profile, currentUser),
              ],
            ),
          ),
          loading: () => const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => SizedBox(
            height: 160,
            child: Center(child: Text('회원 정보를 불러오지 못했어요: $error')),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterForm(String currentUser) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '회원가입을 하면 개인 커플 코드가 발급됩니다.',
          style: TextStyle(color: Colors.grey[700], fontSize: 13),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nicknameController,
          decoration: const InputDecoration(
            labelText: '닉네임',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _loginIdController,
          decoration: const InputDecoration(
            labelText: '아이디',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: '비밀번호',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _gender,
          decoration: const InputDecoration(
            labelText: '성별',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: '여성', child: Text('여성')),
            DropdownMenuItem(value: '남성', child: Text('남성')),
            DropdownMenuItem(value: '기타', child: Text('기타')),
          ],
          onChanged: _isBusy
              ? null
              : (value) => setState(() => _gender = value!),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isBusy ? null : () => _register(currentUser),
            icon: _isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_add_alt_1),
            label: const Text('회원가입'),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisteredProfile(UserProfile profile, String currentUser) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(label: '닉네임', value: profile.displayName),
        _InfoRow(label: '아이디', value: profile.loginId ?? '-'),
        _InfoRow(label: '성별', value: profile.gender ?? '-'),
        Row(
          children: [
            Expanded(
              child: _InfoRow(
                label: '내 커플 코드',
                value: profile.coupleCode ?? '-',
              ),
            ),
            IconButton(
              tooltip: '복사',
              onPressed: profile.coupleCode == null
                  ? null
                  : () async {
                      await Clipboard.setData(
                        ClipboardData(text: profile.coupleCode!),
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('커플 코드를 복사했어요.')),
                        );
                      }
                    },
              icon: const Icon(Icons.copy),
            ),
          ],
        ),
        const Divider(height: 28),
        if (profile.coupleActive)
          _buildUnlinkSection(currentUser)
        else
          _buildLinkSection(),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _isBusy ? null : _logout,
            icon: const Icon(Icons.logout),
            label: const Text('로그아웃'),
          ),
        ),
      ],
    );
  }

  Widget _buildLinkSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '상대방 커플 코드 등록',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _partnerCodeController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: '상대방 커플 코드',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isBusy ? null : _linkCouple,
            icon: const Icon(Icons.favorite),
            label: const Text('커플 등록'),
          ),
        ),
      ],
    );
  }

  Widget _buildUnlinkSection(String currentUser) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isBusy ? null : () => _unlinkCouple(currentUser),
        icon: const Icon(Icons.heart_broken_outlined),
        label: const Text('커플 해제'),
      ),
    );
  }

  Future<void> _register(String currentUser) async {
    setState(() => _isBusy = true);
    try {
      final code = await ref
          .read(firebaseServiceProvider)
          .registerMember(
            userId: currentUser,
            nickname: _nicknameController.text,
            loginId: _loginIdController.text,
            password: _passwordController.text,
            gender: _gender,
          );
      _passwordController.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('회원가입이 완료되었습니다. 커플 코드: $code')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('현재 계정에서 로그아웃할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    ref.read(currentUserProvider.notifier).signOut();
    context.go('/auth');
  }

  Future<void> _linkCouple() async {
    final code = _partnerCodeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('상대방 커플 코드를 입력해 주세요.')));
      return;
    }

    setState(() => _isBusy = true);
    try {
      final partner = await ref
          .read(firebaseServiceProvider)
          .getMemberByCoupleCode(code);
      if (!mounted) return;
      if (partner == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('존재하지 않는 커플 코드입니다.')));
        return;
      }

      final nickname =
          partner['nickname']?.toString() ?? partner['id'].toString();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('커플 등록'),
          content: Text('$nickname님과 커플 등록을 진행하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('등록'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }

      final linkedNickname = await ref
          .read(firebaseServiceProvider)
          .linkCouple(
            currentUserId: ref.read(currentUserProvider),
            partnerCoupleCode: code,
          );
      _partnerCodeController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$linkedNickname"님과 커플 등록이 완료되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _unlinkCouple(String currentUser) async {
    final deleteRecords = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('커플 해제'),
        content: const Text('커플 기록을 삭제하시겠습니까?\n상대방의 커플 기록도 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('기록 유지'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('기록 삭제'),
          ),
        ],
      ),
    );
    if (deleteRecords == null) {
      return;
    }

    setState(() => _isBusy = true);
    try {
      await ref
          .read(firebaseServiceProvider)
          .unlinkCouple(
            currentUserId: currentUser,
            deleteRecords: deleteRecords,
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('커플 해제가 완료되었습니다.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('커플 해제 실패: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(label, style: TextStyle(color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
