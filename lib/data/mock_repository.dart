import 'models.dart';
import 'repository.dart';
import 'results.dart';

class MockRepository implements ElectionRepository {
  bool _director = true, _voted = false;
  int _sequence = 100;
  @override
  Future<ElectionResults> loadResults({required bool finalResult}) async {
    _admin();
    // Independent illustrative aggregates, never reconstruct the demo user's vote.
    return ElectionResults(
      isFinal: finalResult,
      generatedAt: DateTime.utc(2026, 11, 10, finalResult ? 21 : 15, 30),
      segments: [
        for (var segment = 0; segment < 3; segment++)
          SegmentResult(
            segment: segment,
            eligible: [60, 40, 28][segment],
            blank: (finalResult ? [3, 2, 1] : [2, 1, 1])[segment],
            slates: _slates
                .where((s) => s.segment == segment)
                .toList()
                .indexed
                .map(
                  (entry) => SlateResult(
                    id: entry.$2.id,
                    number: entry.$2.number,
                    name: entry.$2.name,
                    votes: entry.$1 > 1
                        ? 0
                        : (finalResult
                              ? [
                                  [31, 20],
                                  [22, 12],
                                  [14, 10],
                                ]
                              : [
                                  [18, 12],
                                  [12, 8],
                                  [7, 6],
                                ])[segment][entry.$1],
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  School _school = const School();
  final Map<String, String> _cpfIndex = {'52998224725': 'v1'};
  @override
  Future<List<Voter>> searchCpf(String cpf) async {
    _admin();
    return _voters.where((v) => v.id == _cpfIndex[cpf]).toList();
  }

  final List<Slate> _slates = List.generate(
    6,
    (i) => Slate(
      id: 'slate-$i',
      number: i.isEven ? '01' : '02',
      segment: i ~/ 2,
      name: [
        'Comunidade Presente',
        'Juntos pela Escola',
        'Voz Estudantil',
        'Construindo o Futuro',
        'Educar em União',
        'Escola Participativa',
      ][i],
      members: [
        ['Ana Souza', 'Paulo Lima'],
        ['Carla Alves', 'Renato Dias'],
        ['Lucas Martins', 'Júlia Silva'],
        ['Pedro Costa', 'Laura Melo'],
        ['Beatriz Santos', 'Carlos Rocha'],
        ['Maria Oliveira', 'Roberto Nunes'],
      ][i],
    ),
  );
  final List<Voter> _voters = [
    const Voter(
      id: 'v1',
      name: 'Fernanda Martins',
      category: 2,
      link: 'Lucas Martins • 7º ano A',
      studentId: 'v2',
    ),
    const Voter(
      id: 'v2',
      name: 'Lucas Martins',
      category: 0,
      link: '7º ano A • Matutino',
    ),
    const Voter(
      id: 'v3',
      name: 'Beatriz Santos',
      category: 1,
      link: 'docente da escola',
    ),
    const Voter(
      id: 'v4',
      name: 'Roberto Nunes',
      category: 3,
      link: 'equipe administrativa',
      enabled: false,
    ),
  ];
  @override
  bool get isDemo => true;
  @override
  Future<void> signIn({bool director = true}) async {
    _director = director;
  }

  @override
  Future<void> signOut() async {}
  @override
  Future<ElectionData> load() async => ElectionData(
    school: _school,
    slates: List.of(_slates),
    voters: _director ? List.of(_voters) : [],
    director: _director,
    userName: _director ? 'Mariana Costa' : 'Fernanda Martins',
    hasVoted: _voted,
    hiddenEnabled: 125,
    hiddenPending: 3,
  );
  void _admin() {
    if (!_director) throw StateError('Acesso restrito à direção.');
  }

  @override
  Future<void> saveSchool(String email, String phone) async {
    _admin();
    _school = School(email: email, phone: phone);
  }

  @override
  Future<void> saveSlate(Slate slate, List<String> cpfs) async {
    _admin();
    if (_slates.any(
      (s) =>
          s.id != slate.id &&
          s.segment == slate.segment &&
          s.number == slate.number,
    )) {
      throw StateError('Número já cadastrado neste segmento.');
    }
    _slates.removeWhere((s) => s.id == slate.id);
    _slates.add(
      Slate(
        id: slate.id.isEmpty ? 'slate-${_sequence++}' : slate.id,
        number: slate.number,
        name: slate.name,
        segment: slate.segment,
        members: List.of(slate.members),
      ),
    );
  }

  @override
  Future<void> saveVoter(Voter voter, String cpf) async {
    _admin();
    if (voter.category == 2 &&
        _voters.any(
          (v) =>
              v.id != voter.id && v.enabled && v.studentId == voter.studentId,
        )) {
      throw StateError('Este aluno já tem um responsável habilitado.');
    }
    _voters.removeWhere((v) => v.id == voter.id);
    _voters.add(
      Voter(
        id: voter.id.isEmpty ? 'voter-${_sequence++}' : voter.id,
        name: voter.name,
        category: voter.category,
        link: voter.link,
        enabled: voter.enabled,
        studentId: voter.studentId,
      ),
    );
    if (cpf.isNotEmpty) {
      _cpfIndex.removeWhere((key, value) => value == _voters.last.id);
      _cpfIndex[cpf] = _voters.last.id;
    }
  }

  @override
  Future<void> vote(String? slateId) async {
    if (_director) throw StateError('Entre como eleitor para votar.');
    if (_voted) throw StateError('Seu voto já foi registrado.');
    if (slateId != null &&
        !_slates.any((s) => s.id == slateId && s.segment == 0)) {
      throw StateError('Chapa inválida para seu segmento.');
    }
    _voted = true;
  }
}
