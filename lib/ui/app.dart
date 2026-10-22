import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/repository.dart';
import 'components.dart';
import 'forms.dart';
import 'results_screen.dart';

class CdeApp extends StatelessWidget {
  const CdeApp({super.key, required this.repository});
  final ElectionRepository repository;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Eleição CDE • Santa Catarina',
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: green,
        primary: green,
        surface: Colors.white,
      ),
      textTheme: const TextTheme(bodyMedium: TextStyle(color: ink)),
    ),
    home: ElectionHome(repository: repository),
  );
}

class ElectionHome extends StatefulWidget {
  const ElectionHome({super.key, required this.repository});
  final ElectionRepository repository;
  @override
  State<ElectionHome> createState() => _ElectionHomeState();
}

class _ElectionHomeState extends State<ElectionHome> {
  ElectionData? data;
  int page = 0, segment = 0, category = -1;
  String query = '';
  List<Voter>? cpfResults;
  Future<void> searchVoters(String value) async {
    setState(() {
      query = value;
      cpfResults = null;
    });
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11) return;
    try {
      final result = await repo.searchCpf(digits);
      if (mounted && query == value) setState(() => cpfResults = result);
    } catch (_) {
      if (mounted && query == value) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível buscar o CPF. Tente novamente.'),
          ),
        );
      }
    }
  }

  String? selected;
  bool blank = false, busy = false;
  ElectionRepository get repo => widget.repository;
  Future<void> run(Future<void> Function() work) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await work();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message.toString()
                  : 'Não foi possível concluir. Verifique sua conexão e tente novamente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> login() async {
    bool? director = true;
    if (repo.isDemo) {
      director = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: stack([
              section('Explorar demonstração'),
              label(
                'Escolha um perfil fictício. Nenhuma autenticação gov.br será realizada.',
                color: muted,
              ),
              ActionButton(
                'Entrar como direção',
                onTap: () => Navigator.pop(context, true),
              ),
              ActionButton(
                'Entrar como eleitor',
                secondary: true,
                onTap: () => Navigator.pop(context, false),
              ),
            ]),
          ),
        ),
      );
      if (director == null) return;
    }
    await run(() async {
      await repo.signIn(director: director!);
      final result = await repo.load();
      if (!mounted) return;
      setState(() {
        data = result;
        query = '';
        cpfResults = null;
        category = -1;
        page = result.director
            ? 1
            : result.hasVoted
            ? 9
            : 7;
        selected = result.slates
            .where((s) => s.segment == result.segment)
            .firstOrNull
            ?.id;
        blank = false;
      });
    });
  }

  Future<void> logout() => run(() async {
    try {
      await repo.signOut();
    } finally {
      if (mounted) {
        setState(() {
          data = null;
          page = 0;
          selected = null;
          blank = false;
          query = '';
          cpfResults = null;
        });
      }
    }
  });
  Future<void> refresh() async {
    final result = await repo.load();
    if (mounted) setState(() => data = result);
  }

  Future<void> editSlate([Slate? slate]) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            SlateForm(repo: repo, data: data!, slate: slate, segment: segment),
      ),
    );
    await run(refresh);
  }

  Future<void> editVoter([Voter? voter]) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => VoterForm(repo: repo, data: data!, voter: voter),
      ),
    );
    await run(refresh);
  }

  @override
  Widget build(BuildContext context) {
    if (page == 0 || data == null) {
      return ScreenFrame(
        title: 'Acesso',
        login: true,
        child: stack([
          Center(
            child: stack(
              [
                asset('0d594.png', size: 108, width: 144),
                label(
                  'Eleição CDE',
                  size: 30,
                  weight: FontWeight.w700,
                  height: 1.2,
                ),
                label('Santa Catarina', size: 16, color: green),
                label('Conselho Deliberativo Escolar', size: 13, color: muted),
              ],
              gap: 8,
              align: CrossAxisAlignment.center,
            ),
          ),
          stack([
            heading('Entre com gov.br'),
            label(
              'Você será direcionado ao portal gov.br para autenticar com seu CPF e retornará ao app.',
              color: muted,
            ),
          ], gap: 8),
          stack([
            label('Autenticação', size: 13, weight: FontWeight.w600),
            box(
              Row(
                children: [
                  Expanded(child: label('gov.br', color: muted)),
                  asset('ee8ee.svg'),
                ],
              ),
              padding: 16,
            ),
          ], gap: 8),
          ActionButton(
            'Entrar com gov.br',
            icon: 'b6576.svg',
            busy: busy,
            onTap: login,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              asset('f3a7f.svg'),
              const SizedBox(width: 12),
              Expanded(
                child: label(
                  'Acesso somente para CPFs habilitados pela escola. Seu perfil é identificado pelo CPF.',
                  size: 12,
                  color: muted,
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              asset('b99f9.svg'),
              const SizedBox(width: 12),
              Expanded(
                child: label(
                  'O perfil administrador é restrito ao CPF cadastrado do diretor.',
                  size: 12,
                  color: muted,
                ),
              ),
            ],
          ),
          Center(
            child: stack(
              [
                label(
                  'Precisa de ajuda? Procure sua escola',
                  size: 13,
                  color: green,
                ),
                label(
                  repo.isDemo ? 'Ambiente demonstrativo' : 'Ambiente conectado',
                  size: 11,
                  color: muted,
                ),
              ],
              gap: 4,
              align: CrossAxisAlignment.center,
            ),
          ),
        ], gap: 24),
      );
    }
    if (page == 2) {
      return SchoolForm(
        repo: repo,
        data: data!,
        onNav: navigate,
        onSaved: refresh,
      );
    }
    final titles = {
      1: 'Painel',
      3: 'Chapas',
      5: 'Eleitores',
      7: 'Cédula de votação',
      8: 'Conferir voto',
      9: 'Votação concluída',
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && page != 9) back();
      },
      child: ScreenFrame(
        title: titles[page]!,
        voting: page >= 7,
        onBack: page == 1 ? null : back,
        navIndex: page <= 5 ? {1: 0, 3: 2, 5: 3}[page] : null,
        onNav: navigate,
        child: switch (page) {
          1 => dashboard(),
          3 => slates(),
          5 => voters(),
          7 => ballot(),
          8 => review(),
          _ => complete(),
        },
      ),
    );
  }

  void navigate(int tab) => setState(() => page = [1, 2, 3, 5][tab]);
  void back() {
    if (busy) return;
    if (page == 9 || page == 7 || page == 1) {
      logout();
    } else {
      setState(() => page = page == 8 ? 7 : 1);
    }
  }

  Widget contextCard({bool voter = false}) =>
      schoolCard(data!.school, voter: voter, demo: repo.isDemo);
  Widget dashboard() => stack([
    stack([
      label('ÁREA DO DIRETOR', size: 12, color: green),
      heading('Olá, ${data!.userName.split(' ').first}'),
      label(
        '${data!.userName} • Diretora escolar\nCPF: ***.***.***-**',
        color: muted,
      ),
    ], gap: 8),
    contextCard(),
    box(
      stack([
        Row(
          children: [
            Expanded(child: label('CDE 2026', size: 17)),
            badge(data!.electionStatus),
          ],
        ),
        label(
          'Votação prevista: ${data!.electionDate}${repo.isDemo ? '\nDados e datas ilustrativos' : ''}',
          size: 12,
          color: muted,
        ),
        Row(
          children: [
            stat(data!.slates.length.toString().padLeft(2, '0'), 'chapas'),
            stat(data!.enabledCount.toString(), 'habilitados'),
            stat(data!.pendingCount.toString().padLeft(2, '0'), 'pendentes'),
          ],
        ),
      ], gap: 16),
      padding: 20,
      radius: 16,
    ),
    stack([
      section('Gerenciar eleição'),
      for (var i = 0; i < 3; i++)
        InkWell(
          onTap: () => navigate(i + 1),
          child: box(
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: pale,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: asset(['f4fd8.svg', 'cc7a1.svg', 'ec740.svg'][i]),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: stack([
                    label(['Escola', 'Chapas', 'Eleitores'][i], size: 15),
                    label(
                      [
                        'Vinculação e dados de contato',
                        'Cadastros dos três segmentos',
                        'Cadastre e habilite os CPFs',
                      ][i],
                      size: 12,
                      color: muted,
                    ),
                  ], gap: 3),
                ),
                asset('b1d1f.svg', size: 18),
              ],
            ),
            padding: 14,
          ),
        ),
    ], gap: 12),
    note(
      'Administração restrita ao CPF do diretor cadastrado para esta escola.',
    ),
    ActionButton(
      'Resultados da eleição',
      secondary: true,
      icon: '05691.svg',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ResultsScreen(repository: repo, school: data!.school),
        ),
      ),
    ),
    TextButton(onPressed: logout, child: const Text('Sair com segurança')),
  ], gap: 24);
  Widget stat(String count, String title) => Expanded(
    child: stack([
      label(count, size: 28, color: green, weight: FontWeight.w700),
      label(title, size: 11, color: muted),
    ], gap: 0),
  );
  Widget slates() {
    final filtered = data!.slates.where((s) => s.segment == segment).toList();
    return stack([
      heading('Chapas da eleição'),
      contextCard(),
      ActionButton(
        'Cadastrar chapa',
        icon: 'ce9e3.svg',
        onTap: () => editSlate(),
      ),
      stack([
        label('Segmento'),
        choices(segments, segment, (v) => setState(() => segment = v)),
      ], gap: 8),
      Row(
        children: [
          Expanded(child: label('${filtered.length} chapas neste segmento')),
          label('${data!.slates.length} no total', size: 12, color: muted),
        ],
      ),
      for (final s in filtered) slateCard(s, edit: true),
      if (filtered.isEmpty)
        label('Nenhuma chapa cadastrada neste segmento.', color: muted),
      label(
        'Cadastros demonstrativos. Os outros segmentos podem ser consultados pelos filtros acima.',
        size: 12,
        color: muted,
      ),
    ], gap: 24);
  }

  Widget slateCard(Slate s, {bool edit = false, bool selectable = false}) {
    final active = selectable && !blank && selected == s.id;
    final card = box(
      stack([
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: active ? Colors.white : surface,
                borderRadius: BorderRadius.circular(10),
                border: active ? Border.all(color: line) : null,
              ),
              child: label(
                s.number,
                size: 24,
                weight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: label(s.name, size: 16)),
            if (selectable) ...[
              const SizedBox(width: 8),
              asset(active ? '28f4d.svg' : '06dfb.svg', size: 24),
            ],
          ],
        ),
        label(
          s.members.indexed
              .map((e) => '${e.$2} • ${e.$1.isEven ? 'titular' : 'suplente'}')
              .join('\n'),
          color: muted,
        ),
        if (active) label('Selecionada', size: 12, color: green),
        if (edit)
          Row(
            children: [
              badge('Cadastrada'),
              const Spacer(),
              TextButton(
                onPressed: () => editSlate(s),
                child: Row(
                  children: [
                    label('Editar', size: 13, color: green),
                    const SizedBox(width: 6),
                    asset('07d5a.svg', size: 18),
                  ],
                ),
              ),
            ],
          ),
      ], gap: 16),
      color: active ? pale : Colors.white,
      borderColor: active ? green : line,
      radius: 16,
    );
    return selectable
        ? Semantics(
            selected: active,
            button: true,
            child: InkWell(
              onTap: () => setState(() {
                selected = s.id;
                blank = false;
              }),
              child: card,
            ),
          )
        : card;
  }

  Widget voters() {
    final filtered = (cpfResults ?? data!.voters)
        .where(
          (v) =>
              (category < 0 || v.category == category) &&
              (cpfResults != null ||
                  v.name.toLowerCase().contains(query.toLowerCase())),
        )
        .toList();
    return stack([
      heading('Eleitores da escola'),
      contextCard(),
      ActionButton(
        'Cadastrar eleitor',
        icon: 'ce9e3.svg',
        onTap: () => editVoter(),
      ),
      Entry(
        'Buscar eleitor',
        hint: 'Nome ou CPF',
        value: query,
        icon: '45a4d.svg',
        onChanged: searchVoters,
      ),
      Wrap(
        spacing: 6,
        runSpacing: 8,
        children: [
          for (var i = -1; i < 4; i++)
            ChoiceChip(
              label: Text(
                i == -1 ? 'Todos' : categories[i],
                style: TextStyle(
                  fontSize: 11,
                  color: category == i ? Colors.white : ink,
                ),
              ),
              selected: category == i,
              showCheckmark: false,
              selectedColor: green,
              backgroundColor: surface,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
              onSelected: (_) => setState(() => category = i),
            ),
        ],
      ),
      Row(
        children: [
          Expanded(child: label('${data!.voterCount} eleitores', size: 13)),
          label(
            '${data!.enabledCount} habilitados • ${data!.pendingCount} pendentes',
            size: 11,
            color: muted,
          ),
        ],
      ),
      stack([
        for (final v in filtered)
          InkWell(
            onTap: () => editVoter(v),
            child: box(
              stack([
                Row(
                  children: [
                    Expanded(child: label(v.name, size: 15)),
                    asset('b1d1f.svg', size: 18),
                  ],
                ),
                label('CPF: ***.***.***-**', size: 12, color: muted),
                Row(
                  children: [
                    Expanded(child: label(categories[v.category], size: 11)),
                    badge(
                      v.enabled ? 'Habilitado' : 'Pendente',
                      warning: !v.enabled,
                    ),
                  ],
                ),
                label('Vínculo: ${v.link}', size: 12, color: muted),
                if (v.category == 2)
                  label(
                    'Um responsável habilitado por aluno',
                    size: 11,
                    color: green,
                  ),
              ], gap: 8),
              radius: 16,
            ),
          ),
      ], gap: 12),
      if (filtered.isEmpty) label('Nenhum eleitor encontrado.', color: muted),
      label(
        'Exibindo ${filtered.length} de ${data!.voterCount} • ${repo.isDemo ? 'dados demonstrativos. ' : ''}A lista não apresenta escolhas de voto.',
        size: 12,
        color: muted,
      ),
    ], gap: 24);
  }

  Widget ballot() => stack([
    heading('Escolha seu voto'),
    progress(0, voting: true),
    contextCard(voter: true),
    stack([
      label('${data!.userName} • CPF: ***.***.***-**', size: 12, color: muted),
      box(
        Row(
          children: [
            asset('f18f4.svg', size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: stack([
                label('SEU SEGMENTO', size: 11, color: muted),
                label(segments[data!.segment]),
              ], gap: 0),
            ),
          ],
        ),
        color: surface,
        border: false,
      ),
      label(
        'Selecione uma chapa ou vote em branco. Você poderá conferir antes de confirmar.',
        color: muted,
      ),
    ], gap: 12),
    stack([
      for (final s in data!.slates.where((s) => s.segment == data!.segment))
        slateCard(s, selectable: true),
      InkWell(
        onTap: () => setState(() {
          blank = true;
          selected = null;
        }),
        child: box(
          Row(
            children: [
              Expanded(
                child: stack([
                  label('Voto em branco', size: 16),
                  label('Não selecionar nenhuma chapa', size: 12, color: muted),
                ], gap: 3),
              ),
              asset(blank ? '28f4d.svg' : 'bbb03.svg', size: 24),
            ],
          ),
          color: blank ? pale : Colors.white,
          borderColor: blank ? green : line,
          radius: 16,
        ),
      ),
    ], gap: 12),
    note('Seu voto é sigiloso. A escolha não aparece nas listas de eleitores.'),
    ActionButton(
      'Conferir voto',
      icon: 'b6576.svg',
      onTap: selected != null || blank ? () => setState(() => page = 8) : null,
    ),
  ], gap: 24);
  Widget review() {
    final slate = data!.slates.where((s) => s.id == selected).firstOrNull;
    return stack([
      heading('Confira sua escolha'),
      progress(1, voting: true),
      contextCard(voter: true),
      label(
        'Seu voto ainda não foi enviado. Confira os dados abaixo para continuar.',
        color: muted,
      ),
      box(
        stack([
          stack([
            label('Segmento', size: 12, color: muted),
            label(segments[data!.segment], size: 16),
          ], gap: 6),
          if (slate != null) ...[
            Row(
              children: [
                Container(
                  width: 60,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: pale,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: label(
                    slate.number,
                    size: 32,
                    color: green,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: stack([
                    label('Chapa selecionada', size: 12, color: muted),
                    label(
                      slate.name,
                      size: 20,
                      weight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ], gap: 6),
                ),
              ],
            ),
            label(
              slate.members.indexed
                  .map(
                    (e) => '${e.$2} • ${e.$1.isEven ? 'titular' : 'suplente'}',
                  )
                  .join('\n'),
              color: muted,
              height: 1.7,
            ),
          ] else
            label('Voto em branco', size: 20, weight: FontWeight.w700),
        ], gap: 20),
        padding: 24,
        radius: 16,
      ),
      note(
        'Ao tocar em “Confirmar voto”, sua escolha será enviada. Depois da confirmação, não será possível alterá-la neste aplicativo.',
        icon: '80f91.svg',
        warning: true,
      ),
      stack([
        ActionButton(
          'Confirmar voto',
          icon: 'cd636.svg',
          busy: busy,
          onTap: () => run(() async {
            await repo.vote(selected);
            if (mounted) {
              setState(() {
                selected = null;
                blank = false;
                data!.hasVoted = true;
                page = 9;
              });
            }
          }),
        ),
        ActionButton(
          'Voltar e corrigir',
          icon: '59e99.svg',
          secondary: true,
          onTap: busy ? null : () => setState(() => page = 7),
        ),
      ], gap: 12),
      Row(
        children: [
          asset('c007d.svg', size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: label(
              'A confirmação final não exibirá a chapa escolhida.',
              size: 12,
              color: muted,
            ),
          ),
        ],
      ),
    ], gap: 24);
  }

  Widget complete() => stack([
    progress(2, voting: true),
    Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: stack(
        [
          Center(
            child: Container(
              width: 104,
              height: 104,
              decoration: const BoxDecoration(
                color: pale,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: green,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: asset('b6f62.svg', size: 36),
              ),
            ),
          ),
          Center(
            child: label('Voto registrado', size: 30, weight: FontWeight.w700),
          ),
          label(
            'Sua participação foi concluída.\nObrigado por participar da eleição do Conselho Deliberativo Escolar.',
            size: 15,
            color: muted,
            height: 1.6,
            align: TextAlign.center,
          ),
        ],
        gap: 20,
        align: CrossAxisAlignment.center,
      ),
    ),
    contextCard(voter: true),
    note(
      'Para preservar o sigilo, esta confirmação não mostra sua escolha de voto.',
    ),
    stack([
      ActionButton(
        'Sair com segurança',
        icon: '109f0.svg',
        busy: busy,
        onTap: logout,
      ),
      label(
        'Ao sair, sua sessão será encerrada. Se estiver em um aparelho compartilhado, não salve sua senha.',
        size: 12,
        color: muted,
      ),
    ], gap: 16),
  ], gap: 24);
}
