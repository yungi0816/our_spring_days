import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/common_providers.dart';

class TranslationService {
  final Locale locale;
  TranslationService(this.locale);

  static final Map<String, Map<String, String>> _localizedValues = {
    'ko': {
      'appName': '비비랑 우리',
      'tabRecord': '메인',
      'tabMap': '지도',
      'tabMission': '미션',
      'tabAlbum': '앨범',
      'tabRoute': '루트',
      'tabChat': 'AI 비서',
      'chatIntro': 'AI 비서는 OpenAI API Key 입력 후 사용할 수 있습니다.\n상단의 버튼을 눌러주세요.',
      'chatLoginBtn': 'API Key',
      'chatInputHint': 'AI에게 무엇이든 물어보세요...',
      'chatAuthTitle': 'OpenAI API Key 입력',
      'chatAuthDesc':
          'OpenAI API는 앱에서 바로 OAuth 로그인을 제공하지 않습니다.\n발급받은 API Key를 입력해 주세요.',
      'missionTitle': '오늘의 미션',
      'sendMission': '미션 보내기',
      'jointMission': '공동 미션',
      'missionPlaceholder': '미션을 입력하세요...',
      'missionSent': '미션이 전달되었습니다!',
      'aiMissionRecommendation': 'AI 미션 추천',
      'missionStatus': '우리의 미션 현황',
      'missionEmpty': '아직 진행 중인 미션이 없어요.',
      'missionInProgress': '진행 중',
      'missionCompleted': '인증 완료!',
      'missionProofBtn': '미션 사진 첨부하기',
      'attachPhoto': '사진 첨부',
      'editMission': '미션 수정',
      'mainOngoingMissions': '진행 중인 미션',
      'missionDetail': '📜 전달받은 미션',
      'missionOriginalPhoto': '🖼 참고 사진',
      'missionSuccessTitle': '🎉 미션 성공!',
      'missionSuccessMsg': '앨범에 새로운 추억이 저장되었습니다.',
      'showMission': '미션보기',
      'close': '닫기',
      'edit': '수정',
      'delete': '삭제',
      'success': '성공! ✨',
      'failure': '실패... ☁️',
      'timeLimit': '제한 시간',
      'noLimit': '제한 없음',
      'timeLeft': '남은 시간',
      'timeOver': '시간 초과',
      'firstOneWins': '먼저 성공하는 사람이 승리!',
      'missionDeleted': '미션이 삭제되었습니다.',
      'missionUpdated': '미션이 수정되었습니다.',
      'creator': '작성자',
      'totalMissions': '전체',
      'successCount': '성공',
      'failureCount': '실패',
      'missionSummary': '미션 요약',
      'createAlbum': '앨범 만들기',
      'albumTitle': '앨범 제목',
      'albumPhoto': '앨범 사진',
      'placeSearch': '장소 검색',
      'searchByPlace': '주소나 명칭으로 검색',
      'saveAlbum': '앨범 저장',
      'changePhoto': '사진변경',
      'resetDefaultImage': '기본이미지 설정',
    },
    'ja': {
      'appName': 'ビビと私たち',
      'tabRecord': 'メイン',
      'tabMap': '地図',
      'tabMission': 'ミッション',
      'tabAlbum': 'アルバム',
      'tabRoute': 'ルート',
      'tabChat': 'AI 秘書',
      'chatIntro': 'AI秘書は OpenAI API Key 入力後に使用できます。\n上部のボタンを押してください。',
      'chatLoginBtn': 'API Key',
      'chatInputHint': 'AIになんでも聞いてください...',
      'chatAuthTitle': 'OpenAI API Key 入力',
      'chatAuthDesc':
          'OpenAI APIはアプリ内の直接OAuthログインを提供していません。\n発行済みのAPI Keyを入力してください。',
      'missionTitle': '今日のミッション',
      'sendMission': 'ミッションを送る',
      'jointMission': '共同ミッション',
      'missionPlaceholder': 'ミッションを入力してください...',
      'missionSent': 'ミッションが送信されました！',
      'aiMissionRecommendation': 'AIミッション推薦',
      'missionStatus': '私たちのミッション状況',
      'missionEmpty': 'まだ進行中のミッションがありません。',
      'missionInProgress': '進行中',
      'missionCompleted': '認証完了！',
      'missionProofBtn': 'ミッション写真を添付',
      'attachPhoto': '写真を添付',
      'editMission': 'ミッションを編集',
      'mainOngoingMissions': '進行中のミッション',
      'missionDetail': '📜 届いたミッション',
      'missionOriginalPhoto': '🖼 参考写真',
      'missionSuccessTitle': '🎉 ミッション成功！',
      'missionSuccessMsg': 'アルバムに新しい思い出が保存されました。',
      'showMission': 'ミッションを見る',
      'close': '閉じる',
      'edit': '修正',
      'delete': '削除',
      'success': '成功! ✨',
      'failure': '失敗... ☁️',
      'timeLimit': '制限時間',
      'noLimit': '制限なし',
      'timeLeft': '残り時間',
      'timeOver': '時間切れ',
      'firstOneWins': '先に成功した方が勝利！',
      'missionDeleted': 'ミッションが削除されました。',
      'missionUpdated': 'ミッションが修正されました。',
      'creator': '作成者',
      'totalMissions': '全体',
      'successCount': '成功',
      'failureCount': '失敗',
      'missionSummary': 'ミッション要約',
      'createAlbum': 'アルバム作成',
      'albumTitle': 'アルバムタイトル',
      'albumPhoto': 'アルバム写真',
      'placeSearch': '場所検索',
      'searchByPlace': '住所または名称で検索',
      'saveAlbum': 'アルバム保存',
      'changePhoto': '写真変更',
      'resetDefaultImage': '基本画像に戻す',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }

  // 자주 사용하는 항목들 getter
  String get appName => translate('appName');
  String get tabRecord => translate('tabRecord');
  String get tabMap => translate('tabMap');
  String get tabMission => translate('tabMission');
  String get tabAlbum => translate('tabAlbum');
  String get tabRoute => translate('tabRoute');
  String get tabChat => translate('tabChat');
  String get chatIntro => translate('chatIntro');
  String get chatLoginBtn => translate('chatLoginBtn');
  String get chatInputHint => translate('chatInputHint');
  String get chatAuthTitle => translate('chatAuthTitle');
  String get chatAuthDesc => translate('chatAuthDesc');
  String get missionTitle => translate('missionTitle');
  String get sendMission => translate('sendMission');
  String get jointMission => translate('jointMission');
  String get missionPlaceholder => translate('missionPlaceholder');
  String get missionSent => translate('missionSent');
  String get aiMissionRecommendation => translate('aiMissionRecommendation');
  String get missionStatus => translate('missionStatus');
  String get missionEmpty => translate('missionEmpty');
  String get missionInProgress => translate('missionInProgress');
  String get missionCompleted => translate('missionCompleted');
  String get missionProofBtn => translate('missionProofBtn');
  String get attachPhoto => translate('attachPhoto');
  String get editMission => translate('editMission');
  String get mainOngoingMissions => translate('mainOngoingMissions');
  String get missionDetail => translate('missionDetail');
  String get missionOriginalPhoto => translate('missionOriginalPhoto');
  String get missionSuccessTitle => translate('missionSuccessTitle');
  String get missionSuccessMsg => translate('missionSuccessMsg');
  String get showMission => translate('showMission');
  String get close => translate('close');
  String get edit => translate('edit');
  String get delete => translate('delete');
  String get success => translate('success');
  String get failure => translate('failure');
  String get timeLimit => translate('timeLimit');
  String get noLimit => translate('noLimit');
  String get timeLeft => translate('timeLeft');
  String get timeOver => translate('timeOver');
  String get firstOneWins => translate('firstOneWins');
  String get missionDeleted => translate('missionDeleted');
  String get missionUpdated => translate('missionUpdated');
  String get totalMissions => translate('totalMissions');
  String get successCount => translate('successCount');
  String get failureCount => translate('failureCount');
  String get missionSummary => translate('missionSummary');
  String get createAlbum => translate('createAlbum');
  String get albumTitle => translate('albumTitle');
  String get albumPhoto => translate('albumPhoto');
  String get placeSearch => translate('placeSearch');
  String get searchByPlace => translate('searchByPlace');
  String get saveAlbum => translate('saveAlbum');
  String get changePhoto => translate('changePhoto');
  String get resetDefaultImage => translate('resetDefaultImage');
  String get translating => 'Uploading...';
}

// 언어 설정을 관리하는 Notifier
class LocaleNotifier extends Notifier<Locale> {
  static const _key = 'selected_language';

  @override
  Locale build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final languageCode = prefs.getString(_key) ?? 'ko';
    return Locale(languageCode);
  }

  void setLocale(Locale locale) {
    state = locale;
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString(_key, locale.languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

// TranslationService를 제공하는 Provider
final translationProvider = Provider((ref) {
  final locale = ref.watch(localeProvider);
  return TranslationService(locale);
});
