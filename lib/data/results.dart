import 'models.dart';

class SlateResult {
  const SlateResult({
    required this.id,
    required this.number,
    required this.name,
    required this.votes,
  });
  final String id, number, name;
  final int votes;
  factory SlateResult.fromJson(Map<String, dynamic> j) => SlateResult(
    id: j['id'],
    number: j['number'],
    name: j['name'],
    votes: j['votes'],
  );
}

class SegmentResult {
  const SegmentResult({
    required this.segment,
    required this.eligible,
    required this.blank,
    required this.slates,
  });
  final int segment, eligible, blank;
  final List<SlateResult> slates;
  int get valid => slates.fold(0, (sum, s) => sum + s.votes);
  int get total => valid + blank;
  int get absent => eligible - total;
  double get turnout => eligible == 0 ? 0 : total / eligible;
  List<SlateResult> get ranked => List.of(slates)
    ..sort((a, b) {
      final comparison = b.votes.compareTo(a.votes);
      return comparison == 0 ? a.number.compareTo(b.number) : comparison;
    });
  bool get tied =>
      ranked.length > 1 && ranked[0].votes == ranked[1].votes && valid > 0;
  factory SegmentResult.fromJson(Map<String, dynamic> j) => SegmentResult(
    segment: j['segment'],
    eligible: j['eligible'],
    blank: j['blank'],
    slates: (j['slates'] as List).map((s) => SlateResult.fromJson(s)).toList(),
  );
}

class ElectionResults {
  const ElectionResults({
    required this.isFinal,
    required this.generatedAt,
    required this.segments,
  });
  final bool isFinal;
  final DateTime generatedAt;
  final List<SegmentResult> segments;
  int get eligible => segments.fold(0, (n, s) => n + s.eligible);
  int get total => segments.fold(0, (n, s) => n + s.total);
  int get blank => segments.fold(0, (n, s) => n + s.blank);
  factory ElectionResults.fromJson(Map<String, dynamic> j) => ElectionResults(
    isFinal: j['is_final'],
    generatedAt: DateTime.parse(j['generated_at']),
    segments: (j['segments'] as List)
        .map((s) => SegmentResult.fromJson(s))
        .toList(),
  );
  String report(School school, {required bool demo}) => [
    'ELEIÇÃO CDE 2026 — RESULTADO ${isFinal ? 'FINAL' : 'PARCIAL'}',
    school.name,
    school.city,
    if (demo) 'DEMONSTRAÇÃO — dados fictícios, sem validade oficial.',
    'Atualização (UTC): ${generatedAt.toUtc().toIso8601String()}',
    'Participação: $total de $eligible habilitados • Brancos: $blank',
    for (final s in segments) ...[
      '',
      segmentsNames(s.segment),
      'Recebidos: ${s.total} • Válidos: ${s.valid} • Brancos: ${s.blank} • ${isFinal ? 'Abstenções' : 'Ainda não votaram'}: ${s.absent}',
      for (final slate in s.ranked)
        '${slate.number} — ${slate.name}: ${slate.votes} votos (${s.valid == 0 ? '0,0' : (slate.votes * 100 / s.valid).toStringAsFixed(1).replaceAll('.', ',')}% dos válidos)',
      if (s.tied) 'Empate: depende dos critérios do regulamento.',
    ],
    '',
    isFinal
        ? 'Totais finais. Homologação e critérios de eleição seguem o regulamento.'
        : 'Apuração em andamento. Este resultado não define eleitos.',
    'Relatório agregado, sem identificação dos votos individuais.',
  ].join('\n');
}

String segmentsNames(int index) => segments[index];
