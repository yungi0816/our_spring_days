# iOS 일본어 앱 이름 메모

iOS 일본어 버전을 준비할 때 앱 표시 이름은 아래 값으로 넣는다.

```text
ビビと私たち
```

한국어/기본 앱 표시 이름은 아래 값으로 유지한다.

```text
비비랑 우리
```

## iOS 적용 방법

iOS Runner 타깃에 일본어 `InfoPlist.strings` 파일을 추가한다.

```text
ios/Runner/ja.lproj/InfoPlist.strings
```

파일 내용은 아래처럼 둔다.

```text
CFBundleDisplayName = "ビビと私たち";
CFBundleName = "ビビと私たち";
```

Xcode에서 해당 파일이 Runner 타깃에 포함되어 있는지 확인한다. 추가 후 기기 언어를 일본어로 바꿔 실행하고, 홈 화면 앱 이름이 `ビビと私たち`로 표시되는지 확인한다.
