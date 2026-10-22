const segments = [
  'Pais e responsáveis',
  'Alunos',
  'Professores e colaboradores',
];
const categories = [
  'Aluno',
  'Professor',
  'Responsável pelo aluno',
  'Funcionário (não docente)',
];

class Slate {
  const Slate({
    required this.id,
    required this.number,
    required this.name,
    required this.segment,
    required this.members,
  });
  final String id, number, name;
  final int segment;
  final List<String> members;
  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'name': name,
    'segment': segment,
    'members': members,
  };
  factory Slate.fromJson(Map<String, dynamic> j) => Slate(
    id: j['id'],
    number: j['number'],
    name: j['name'],
    segment: j['segment'],
    members: List<String>.from(j['members']),
  );
}

class Voter {
  const Voter({
    required this.id,
    required this.name,
    required this.category,
    required this.link,
    this.enabled = true,
    this.studentId,
  });
  final String id, name, link;
  final int category;
  final bool enabled;
  final String? studentId;
  int get segment => category == 0
      ? 1
      : category == 2
      ? 0
      : 2;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'link': link,
    'enabled': enabled,
    'student_id': studentId,
  };
  factory Voter.fromJson(Map<String, dynamic> j) => Voter(
    id: j['id'],
    name: j['name'],
    category: j['category'],
    link: j['link'],
    enabled: j['enabled'],
    studentId: j['student_id'],
  );
}

class School {
  const School({
    this.name = 'EEB Caminhos do Vale',
    this.city = 'Florianópolis',
    this.director = 'Mariana Costa',
    this.email = 'direcao@escola.exemplo.br',
    this.phone = '(48) 0000-0000',
  });
  final String name, city, director, email, phone;
  factory School.fromJson(Map<String, dynamic> j) => School(
    name: j['name'],
    city: j['city'],
    director: j['director'],
    email: j['email'],
    phone: j['phone'],
  );
}

class ElectionData {
  ElectionData({
    required this.school,
    required this.slates,
    required this.voters,
    required this.director,
    required this.userName,
    this.segment = 0,
    this.hasVoted = false,
    this.hiddenEnabled = 0,
    this.hiddenPending = 0,
    this.electionDate = '10/11/2026',
    this.electionStatus = 'Em preparação',
  });
  School school;
  final List<Slate> slates;
  final List<Voter> voters;
  final bool director;
  final String userName;
  final int segment;
  bool hasVoted;
  final int hiddenEnabled, hiddenPending;
  final String electionDate, electionStatus;
  int get enabledCount => voters.where((v) => v.enabled).length + hiddenEnabled;
  int get pendingCount =>
      voters.where((v) => !v.enabled).length + hiddenPending;
  int get voterCount => enabledCount + pendingCount;
}

String? validateCpf(String? input) {
  final cpf = (input ?? '').replaceAll(RegExp(r'\D'), '');
  if (cpf.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) {
    return 'Informe um CPF válido.';
  }
  final digits = cpf.split('').map(int.parse).toList();
  for (var length = 9; length <= 10; length++) {
    var sum = 0;
    for (var i = 0; i < length; i++) {
      sum += digits[i] * (length + 1 - i);
    }
    final check = (sum * 10) % 11;
    if ((check == 10 ? 0 : check) != digits[length]) {
      return 'Informe um CPF válido.';
    }
  }
  return null;
}
