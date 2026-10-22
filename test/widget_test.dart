import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eleicao_cde/data/mock_repository.dart';
import 'package:eleicao_cde/data/models.dart';
import 'package:eleicao_cde/ui/app.dart';

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> screenshot(WidgetTester tester, GlobalKey key, String name) async {
  expect(tester.takeException(), isNull);
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/screenshots').create(recursive: true);
    await File(
      'build/screenshots/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets(
    'Ten Figma screens render and the voter flow protects the final choice',
    (tester) async {
      tester.view.physicalSize = const Size(414, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fonts = FontLoader('Inter')
        ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
      await tester.runAsync(fonts.load);
      final repo = MockRepository();
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: CdeApp(repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      final imageContext = tester.element(find.byType(ElectionHome));
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/figma/0d594.png'),
          imageContext,
        );
        await precacheImage(
          const AssetImage('assets/figma/84863.png'),
          imageContext,
        );
      });
      await tester.pumpAndSettle();
      await screenshot(tester, key, '01-login');
      await tapText(tester, 'Entrar com gov.br');
      await tapText(tester, 'Entrar como direção');
      expect(find.text('Olá, Mariana'), findsOneWidget);
      await screenshot(tester, key, '02-dashboard');
      await tapText(tester, 'Escola');
      tester.view.physicalSize = const Size(414, 1600);
      await tester.pumpAndSettle();
      await screenshot(tester, key, '03-school');
      await tapText(tester, 'Chapas');
      tester.view.physicalSize = const Size(414, 1200);
      await tester.pumpAndSettle();
      await screenshot(tester, key, '04-slates');
      await tapText(tester, 'Alunos');
      expect(find.text('Voz Estudantil'), findsOneWidget);
      expect(find.text('Comunidade Presente'), findsNothing);
      await tapText(tester, 'Pais e responsáveis');
      await tapText(tester, 'Editar');
      tester.view.physicalSize = const Size(414, 1900);
      await tester.pumpAndSettle();
      await screenshot(tester, key, '05-slate-form');
      Navigator.of(tester.element(find.text('Editar chapa').first)).pop();
      await tester.pumpAndSettle();
      await tapText(tester, 'Eleitores');
      tester.view.physicalSize = const Size(414, 1500);
      await tester.pumpAndSettle();
      await screenshot(tester, key, '06-voters');
      await tapText(tester, 'Fernanda Martins');
      tester.view.physicalSize = const Size(414, 2200);
      await tester.pumpAndSettle();
      await screenshot(tester, key, '07-voter-form');
      await tapText(tester, 'Salvar e habilitar eleitor');
      expect(find.text('Confirme os dados para habilitar.'), findsOneWidget);
      Navigator.of(tester.element(find.text('Editar eleitor'))).pop();
      await tester.pumpAndSettle();
      await tapText(tester, 'Painel');
      await tapText(tester, 'Sair com segurança');
      await tapText(tester, 'Entrar com gov.br');
      await tapText(tester, 'Entrar como eleitor');
      tester.view.physicalSize = const Size(414, 1200);
      await tester.pumpAndSettle();
      await screenshot(tester, key, '08-ballot');
      await tapText(tester, 'Conferir voto');
      await screenshot(tester, key, '09-review');
      await tapText(tester, 'Voltar e corrigir');
      await tapText(tester, 'Voto em branco');
      await tapText(tester, 'Conferir voto');
      expect(find.text('Voto em branco'), findsOneWidget);
      await tapText(tester, 'Confirmar voto');
      tester.view.physicalSize = const Size(414, 896);
      await tester.pumpAndSettle();
      await screenshot(tester, key, '10-complete');
      expect(find.text('Voto registrado'), findsOneWidget);
      expect(find.text('Comunidade Presente'), findsNothing);
      expect(find.text('Voto em branco'), findsNothing);
      await tapText(tester, 'Sair com segurança');
      await tapText(tester, 'Entrar com gov.br');
      await tapText(tester, 'Entrar como eleitor');
      expect(find.text('Voto registrado'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Login adapts to a narrow viewport and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(CdeApp(repository: MockRepository()));
    await tester.pumpAndSettle();
    await tapText(tester, 'Entrar com gov.br');
    expect(tester.takeException(), isNull);
  });
  test(
    'Mock enforces duplicate numbers, one guardian, roles and repeat voting',
    () async {
      final repo = MockRepository();
      await repo.signIn();
      await expectLater(
        repo.saveSlate(
          const Slate(
            id: '',
            number: '01',
            name: 'Duplicada',
            segment: 0,
            members: ['A', 'B'],
          ),
          [],
        ),
        throwsStateError,
      );
      await expectLater(
        repo.saveVoter(
          const Voter(
            id: '',
            name: 'Outro responsável',
            category: 2,
            link: 'Lucas',
            studentId: 'v2',
          ),
          '',
        ),
        throwsStateError,
      );
      await expectLater(repo.vote(null), throwsStateError);
      await repo.signIn(director: false);
      await expectLater(
        repo.saveSchool('test@example.com', '48999999999'),
        throwsStateError,
      );
      await expectLater(repo.vote('slate-2'), throwsStateError);
      await repo.vote(null);
      await expectLater(repo.vote('slate-0'), throwsStateError);
      expect((await repo.load()).hasVoted, isTrue);
      expect((await repo.load()).voters, isEmpty);
    },
  );
  test('CPF check digits reject malformed and repeated values', () {
    expect(validateCpf('000.000.000-00'), isNotNull);
    expect(validateCpf('123'), isNotNull);
    expect(validateCpf('529.982.247-25'), isNull);
    expect(validateCpf('529.982.247-24'), isNotNull);
  });
  test(
    'Mock saves independent records and finds CPF without returning it',
    () async {
      final repo = MockRepository();
      await repo.signIn();
      for (final number in ['03', '04']) {
        await repo.saveSlate(
          Slate(
            id: '',
            number: number,
            name: 'Chapa $number',
            segment: 0,
            members: ['Titular', 'Suplente'],
          ),
          [],
        );
      }
      final data = await repo.load();
      expect(data.slates.length, 8);
      expect(data.slates.map((s) => s.id).toSet().length, 8);
      await repo.saveSchool('contato@example.com', '48999999999');
      expect((await repo.load()).school.email, 'contato@example.com');
      final found = await repo.searchCpf('52998224725');
      expect(found.single.name, 'Fernanda Martins');
      expect(found.single.toJson().containsKey('cpf'), isFalse);
      await repo.signIn(director: false);
      await expectLater(repo.searchCpf('52998224725'), throwsStateError);
    },
  );
}
