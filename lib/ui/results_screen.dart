import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../data/results.dart';
import 'components.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({
    super.key,
    required this.repository,
    required this.school,
  });
  final ElectionRepository repository;
  final School school;
  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  ElectionResults? result;
  bool finalResult = false, loading = false;
  int segment = 0;
  String? error;
  @override
  void initState() {
    super.initState();
    generate();
  }

  Future<void> generate() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
      result = null;
    });
    try {
      final next = await widget.repository.loadResults(
        finalResult: finalResult,
      );
      if (mounted) setState(() => result = next);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError
              ? e.message.toString()
              : 'Não foi possível consultar a apuração. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String percent(double value) =>
      '${(value * 100).toStringAsFixed(1).replaceAll('.', ',')}%';
  void changeMode(bool value) {
    if (loading || value == finalResult) return;
    setState(() {
      finalResult = value;
      result = null;
      error = null;
    });
  }

  Future<void> report() async {
    final text = result!.report(widget.school, demo: widget.repository.isDemo);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: .85,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: section('Relatório da eleição')),
                  IconButton(
                    tooltip: 'Fechar relatório',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    text,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ActionButton(
                'Copiar relatório',
                icon: 'cd636.svg',
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Relatório copiado.')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = result;
    final selected = data?.segments
        .where((s) => s.segment == segment)
        .firstOrNull;
    return ScreenFrame(
      title: 'Resultados',
      onBack: () => Navigator.pop(context),
      child: stack([
        heading('Resultado da eleição'),
        schoolCard(widget.school, demo: widget.repository.isDemo),
        stack([
          label('Tipo de apuração', size: 13, weight: FontWeight.w600),
          Row(
            children: [
              Expanded(child: mode('Parcial', false)),
              const SizedBox(width: 8),
              Expanded(child: mode('Final', true)),
            ],
          ),
          note(
            finalResult
                ? 'O resultado final considera a votação encerrada. A homologação segue o regulamento da eleição.'
                : 'A votação está em andamento. Os números podem mudar e não definem chapas eleitas.',
            warning: !finalResult,
            icon: finalResult ? 'f3a7f.svg' : '80f91.svg',
          ),
        ], gap: 12),
        ActionButton(
          finalResult ? 'Gerar resultado final' : 'Gerar resultado parcial',
          icon: 'cd636.svg',
          busy: loading,
          onTap: generate,
        ),
        if (error != null) note(error!, warning: true, icon: '80f91.svg'),
        if (data != null) ...[
          box(
            stack([
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  badge(
                    data.isFinal ? 'Apuração final' : 'Apuração parcial',
                    warning: !data.isFinal,
                  ),
                  if (widget.repository.isDemo) badge('Dados simulados'),
                ],
              ),
              section('Participação geral'),
              Row(
                children: [
                  metric(data.total.toString(), 'votos recebidos'),
                  metric(data.eligible.toString(), 'habilitados'),
                  metric(
                    percent(
                      data.eligible == 0 ? 0 : data.total / data.eligible,
                    ),
                    'participação',
                  ),
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: data.eligible == 0 ? 0 : data.total / data.eligible,
                  color: green,
                  backgroundColor: line,
                ),
              ),
              label(
                'Atualizado em ${timestamp(data.generatedAt)} • horário de Brasília',
                size: 11,
                color: muted,
              ),
            ]),
            padding: 20,
            radius: 16,
          ),
          stack([
            section('Resultado por segmento'),
            choices(segments, segment, (v) => setState(() => segment = v)),
          ], gap: 12),
          if (selected != null) ...[
            box(
              Row(
                children: [
                  metric(selected.valid.toString(), 'válidos'),
                  metric(selected.blank.toString(), 'em branco'),
                  metric(
                    selected.absent.toString(),
                    data.isFinal ? 'abstenções' : 'a votar',
                  ),
                ],
              ),
              color: surface,
              border: false,
            ),
            label(
              'Percentuais calculados sobre os votos válidos do segmento.',
              size: 12,
              color: muted,
            ),
            if (selected.total == 0)
              note('Nenhum voto recebido neste segmento.', icon: '95835.svg'),
            for (final entry in selected.ranked.indexed)
              resultCard(entry.$2, selected, data.isFinal),
            if (selected.tied)
              note(
                'Há empate na maior votação. O desempate depende dos critérios do regulamento.',
                warning: true,
                icon: '80f91.svg',
              ),
          ] else
            note(
              'Nenhum resultado disponível para este segmento.',
              icon: '95835.svg',
            ),
          ActionButton(
            'Ver relatório completo',
            secondary: true,
            icon: '1309f.svg',
            onTap: report,
          ),
          note(
            'Somente totais agregados são exibidos. Nenhum voto é associado ao nome ou CPF do eleitor.',
          ),
        ],
      ], gap: 24),
    );
  }

  Widget mode(String title, bool value) => OutlinedButton(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 48),
      backgroundColor: finalResult == value ? pale : Colors.white,
      side: BorderSide(color: finalResult == value ? green : line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    onPressed: loading ? null : () => changeMode(value),
    child: label(
      title,
      color: finalResult == value ? green : muted,
      weight: FontWeight.w600,
    ),
  );
  Widget metric(String value, String title) => Expanded(
    child: stack([
      label(value, size: 24, color: green, weight: FontWeight.w700),
      label(title, size: 11, color: muted),
    ], gap: 4),
  );
  Widget resultCard(SlateResult slate, SegmentResult totals, bool isFinal) {
    final leading =
        totals.valid > 0 && slate.votes == totals.ranked.first.votes;
    return box(
      stack([
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: pale,
                borderRadius: BorderRadius.circular(10),
              ),
              child: label(
                slate.number,
                size: 24,
                color: green,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: label(slate.name, size: 16, weight: FontWeight.w600),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: label(
                '${slate.votes} votos',
                size: 18,
                weight: FontWeight.w700,
              ),
            ),
            label(
              percent(totals.valid == 0 ? 0 : slate.votes / totals.valid),
              size: 18,
              color: green,
              weight: FontWeight.w700,
            ),
          ],
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: totals.valid == 0 ? 0 : slate.votes / totals.valid,
            backgroundColor: line,
            color: green,
          ),
        ),
        if (leading)
          badge(
            totals.tied
                ? 'Empate na maior votação'
                : isFinal
                ? 'Maior votação'
                : 'Liderança provisória',
          ),
      ], gap: 14),
      radius: 16,
      borderColor: leading ? green : line,
    );
  }

  String timestamp(DateTime date) {
    final brasilia = date.toUtc().subtract(const Duration(hours: 3));
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(brasilia.day)}/${two(brasilia.month)}/${brasilia.year} às ${two(brasilia.hour)}:${two(brasilia.minute)}';
  }
}
