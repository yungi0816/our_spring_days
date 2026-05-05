import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/common_providers.dart';
import '../../core/providers/user_provider.dart';

enum _AuthMode { login, signup, findId, resetPassword }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _loginIdController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _signupNicknameController = TextEditingController();
  final _signupLoginIdController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _signupPasswordConfirmController = TextEditingController();
  final _findIdPartnerCodeController = TextEditingController();
  final _resetLoginIdController = TextEditingController();
  final _resetPartnerCodeController = TextEditingController();
  final _resetPasswordController = TextEditingController();
  final _resetPasswordConfirmController = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  String _gender = '여성';
  bool _isBusy = false;
  String? _message;

  @override
  void dispose() {
    _loginIdController.dispose();
    _loginPasswordController.dispose();
    _signupNicknameController.dispose();
    _signupLoginIdController.dispose();
    _signupPasswordController.dispose();
    _signupPasswordConfirmController.dispose();
    _findIdPartnerCodeController.dispose();
    _resetLoginIdController.dispose();
    _resetPartnerCodeController.dispose();
    _resetPasswordController.dispose();
    _resetPasswordConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset('images/title_kor.png', height: 156),
                  const SizedBox(height: 18),
                  Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _buildBody(),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.pinkAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _title {
    return switch (_mode) {
      _AuthMode.login => '로그인',
      _AuthMode.signup => '회원가입',
      _AuthMode.findId => '아이디 찾기',
      _AuthMode.resetPassword => '비밀번호 찾기',
    };
  }

  Widget _buildBody() {
    return switch (_mode) {
      _AuthMode.login => _buildLogin(),
      _AuthMode.signup => _buildSignup(),
      _AuthMode.findId => _buildFindId(),
      _AuthMode.resetPassword => _buildResetPassword(),
    };
  }

  Widget _buildLogin() {
    return Column(
      key: const ValueKey('login'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _loginIdController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: '아이디',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _loginPasswordController,
          obscureText: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: '비밀번호',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _login(),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _isBusy ? null : _login,
          child: _buttonChild('로그인'),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            TextButton(
              onPressed: _isBusy ? null : () => _switchMode(_AuthMode.findId),
              child: const Text('아이디 찾기'),
            ),
            TextButton(
              onPressed: _isBusy
                  ? null
                  : () => _switchMode(_AuthMode.resetPassword),
              child: const Text('비밀번호 찾기'),
            ),
            TextButton(
              onPressed: _isBusy ? null : () => _switchMode(_AuthMode.signup),
              child: const Text('회원가입'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignup() {
    final mismatch =
        _signupPasswordConfirmController.text.isNotEmpty &&
        _signupPasswordController.text != _signupPasswordConfirmController.text;

    return Column(
      key: const ValueKey('signup'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _signupNicknameController,
          decoration: const InputDecoration(
            labelText: '닉네임',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _signupLoginIdController,
          decoration: const InputDecoration(
            labelText: '아이디',
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
              : (value) => setState(() => _gender = value ?? '여성'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _signupPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: '비밀번호',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _signupPasswordConfirmController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: '비밀번호 확인',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (mismatch) _passwordMismatchText(),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _isBusy || mismatch ? null : _signup,
          child: _buttonChild('회원가입'),
        ),
        TextButton(
          onPressed: _isBusy ? null : () => _switchMode(_AuthMode.login),
          child: const Text('로그인으로 돌아가기'),
        ),
      ],
    );
  }

  Widget _buildFindId() {
    return Column(
      key: const ValueKey('findId'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _findIdPartnerCodeController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: '상대방 커플 코드',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _isBusy ? null : _findLoginId,
          child: _buttonChild('아이디 확인'),
        ),
        TextButton(
          onPressed: _isBusy ? null : () => _switchMode(_AuthMode.login),
          child: const Text('로그인으로 돌아가기'),
        ),
      ],
    );
  }

  Widget _buildResetPassword() {
    final mismatch =
        _resetPasswordConfirmController.text.isNotEmpty &&
        _resetPasswordController.text != _resetPasswordConfirmController.text;

    return Column(
      key: const ValueKey('resetPassword'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _resetLoginIdController,
          decoration: const InputDecoration(
            labelText: '아이디',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _resetPartnerCodeController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: '상대방 커플 코드',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _resetPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: '새 비밀번호',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _resetPasswordConfirmController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: '새 비밀번호 확인',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (mismatch) _passwordMismatchText(),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _isBusy || mismatch ? null : _resetPassword,
          child: _buttonChild('비밀번호 재설정'),
        ),
        TextButton(
          onPressed: _isBusy ? null : () => _switchMode(_AuthMode.login),
          child: const Text('로그인으로 돌아가기'),
        ),
      ],
    );
  }

  Widget _buttonChild(String label) {
    if (!_isBusy) {
      return Text(label);
    }
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }

  Widget _passwordMismatchText() {
    return const Padding(
      padding: EdgeInsets.only(top: 6, left: 4),
      child: Text(
        '비밀번호가 서로 다릅니다.',
        style: TextStyle(color: Colors.redAccent, fontSize: 12),
      ),
    );
  }

  void _switchMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _message = null;
    });
  }

  Future<void> _login() async {
    await _runBusy(() async {
      final result = await ref
          .read(firebaseServiceProvider)
          .loginMember(
            loginId: _loginIdController.text,
            password: _loginPasswordController.text,
            deviceKey: ref.read(deviceKeyProvider),
          );
      _loginPasswordController.clear();
      ref.read(currentUserProvider.notifier).signIn(result.userId);
      if (mounted) {
        context.go('/main');
      }
    });
  }

  Future<void> _signup() async {
    await _runBusy(() async {
      if (_signupPasswordController.text !=
          _signupPasswordConfirmController.text) {
        setState(() => _message = '비밀번호가 서로 다릅니다.');
        return;
      }

      final result = await ref
          .read(firebaseServiceProvider)
          .signUpMember(
            nickname: _signupNicknameController.text,
            loginId: _signupLoginIdController.text,
            password: _signupPasswordController.text,
            gender: _gender,
            deviceKey: ref.read(deviceKeyProvider),
          );
      ref.read(currentUserProvider.notifier).signIn(result.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('회원가입이 완료되었습니다. 커플 코드: ${result.coupleCode}')),
      );
      context.go('/main');
    });
  }

  Future<void> _findLoginId() async {
    await _runBusy(() async {
      final loginId = await ref
          .read(firebaseServiceProvider)
          .findLoginIdByPartnerCoupleCode(_findIdPartnerCodeController.text);
      _loginIdController.text = loginId;
      _switchMode(_AuthMode.login);
      setState(() => _message = '가입된 아이디는 $loginId 입니다.');
    });
  }

  Future<void> _resetPassword() async {
    await _runBusy(() async {
      if (_resetPasswordController.text !=
          _resetPasswordConfirmController.text) {
        setState(() => _message = '비밀번호가 서로 다릅니다.');
        return;
      }

      await ref
          .read(firebaseServiceProvider)
          .resetPasswordWithPartnerCoupleCode(
            loginId: _resetLoginIdController.text,
            partnerCoupleCode: _resetPartnerCodeController.text,
            newPassword: _resetPasswordController.text,
          );
      _loginIdController.text = _resetLoginIdController.text.trim();
      _resetPasswordController.clear();
      _resetPasswordConfirmController.clear();
      _switchMode(_AuthMode.login);
      setState(() => _message = '비밀번호가 변경되었습니다.');
    });
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
      _message = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() => _message = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }
}
