import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movie_calendar/main.dart';

void main() {
  Widget testApp() {
    return MaterialApp(
      home: ReleaseCalendarPage(repository: MockMovieRepository()),
    );
  }

  testWidgets('moves between months without hiding the calendar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(testApp());
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('영화 개봉 캘린더'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(PageView), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('shows info stack and iPhone home shortcut guide', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(testApp());

    expect(find.text('영화 개봉 캘린더'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('정보'), findsOneWidget);
    expect(find.text('홈 화면에 바로가기 추가하기'), findsOneWidget);

    await tester.tap(find.text('홈 화면에 바로가기 추가하기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('iPhone에서 Safari로 이 페이지를 엽니다.'), findsOneWidget);
    expect(find.text('"홈 화면에 추가"를 선택합니다.'), findsOneWidget);
  });
}
