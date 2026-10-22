import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eleicao_cde/data/mock_repository.dart';
import 'package:eleicao_cde/data/models.dart';
import 'package:eleicao_cde/data/results.dart';
import 'package:eleicao_cde/ui/app.dart';
import 'widget_test.dart' show tapText, screenshot;

void main() {
  testWidgets(
    'Director generates partial and final reports and filters segments',
    (tester) async {
      tester.view.physicalSize = const Size(414, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fonts = FontLoader('Inter')
        ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
      await tester.runAsync(fonts.load);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: CdeApp(repository: MockRepository()),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(ElectionHome));
      await tester.runAsync(
        () =>
            precacheImage(const AssetImage('assets/figma/84863.png'), context),
      );
      await tapText(tester, 'Entrar com gov.br');
      await tapText(tester, 'Entrar como direção');
      await tapText(tester, 'Resultados da eleição');
      expect(find.text('Apuração parcial'), findsOneWidget);
      expect(find.text('67'), findsOneWidget);
      expect(find.text('18 votos'), findsOneWidget);
      await screenshot(tester, key, '11-results-partial');
      await tapText(tester, 'Alunos');
      expect(find.text('Voz Estudantil'), findsOneWidget);
      expect(find.text('Comunidade Presente'), findsNothing);
      await tapText(tester, 'Final');
      expect(find.text('Apuração parcial'), findsNothing);
      await tapText(tester, 'Gerar resultado final');
      expect(find.text('Apuração final'), findsOneWidget);
      expect(find.text('115'), findsOneWidget);
      expect(find.text('22 votos'), findsOneWidget);
      expect(find.text('Liderança provisória'), findsNothing);
      await tester.ensureVisible(find.text('Resultado da eleição'));
      await tester.pumpAndSettle();
      await screenshot(tester, key, '12-results-final');
      await tapText(tester, 'Ver relatório completo');
      expect(find.byType(SelectableText), findsOneWidget);
      final report = tester
          .widget<SelectableText>(find.byType(SelectableText))
          .data!;
      expect(report, contains('DEMONSTRAÇÃO'));
      expect(report, contains('RESULTADO FINAL'));
      expect(report, contains('Pais e responsáveis'));
      expect(report, contains('Professores e colaboradores'));
      expect(report, isNot(contains('Fernanda Martins')));
      expect(tester.takeException(), isNull);
    },
  );
  test('Aggregates are consistent and access is director-only', () async {
    final repo = MockRepository();
    for (final finalResult in [false, true]) {
      final results = await repo.loadResults(finalResult: finalResult);
      expect(results.isFinal, finalResult);
      expect(results.eligible, 128);
      expect(results.total, finalResult ? 115 : 67);
      for (final segment in results.segments) {
        expect(segment.total, segment.valid + segment.blank);
        expect(segment.absent, greaterThanOrEqualTo(0));
      }
    }
    await repo.signIn(director: false);
    await expectLater(repo.loadResults(finalResult: true), throwsStateError);
  });
  test('Empty results and tied rankings do not invent a winner', () {
    const empty = SegmentResult(segment: 0, eligible: 0, blank: 0, slates: []);
    expect(empty.turnout, 0);
    expect(empty.tied, false);
    const tied = SegmentResult(
      segment: 1,
      eligible: 10,
      blank: 2,
      slates: [
        SlateResult(id: 'a', number: '02', name: 'B', votes: 4),
        SlateResult(id: 'b', number: '01', name: 'A', votes: 4),
      ],
    );
    expect(tied.tied, true);
    expect(tied.ranked.first.number, '01');
    expect(tied.absent, 0);
    final results = ElectionResults(
      isFinal: true,
      generatedAt: DateTime.utc(2026),
      segments: [tied],
    );
    expect(results.report(const School(), demo: true), contains('Empate'));
  });
}
