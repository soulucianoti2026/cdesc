import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/repository.dart';
import 'components.dart';

mixin Saving<T extends StatefulWidget> on State<T> {
  bool busy = false;
  final form = GlobalKey<FormState>();
  Future<void> save(Future<void> Function() action, {bool pop = true}) async {
    if (busy || !form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dados salvos com sucesso.')),
      );
      if (pop) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message.toString()
                  : 'Não foi possível salvar. Tente novamente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class SchoolForm extends StatefulWidget {
  const SchoolForm({
    super.key,
    required this.repo,
    required this.data,
    required this.onNav,
    required this.onSaved,
  });
  final ElectionRepository repo;
  final ElectionData data;
  final ValueChanged<int> onNav;
  final Future<void> Function() onSaved;
  @override
  State<SchoolForm> createState() => _SchoolFormState();
}

class _SchoolFormState extends State<SchoolForm> with Saving {
  late final email = TextEditingController(text: widget.data.school.email);
  late final phone = TextEditingController(text: widget.data.school.phone);
  late final search = TextEditingController(text: widget.data.school.name);
  @override
  void dispose() {
    email.dispose();
    phone.dispose();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScreenFrame(
    title: 'Escola',
    onBack: () => widget.onNav(0),
    navIndex: 1,
    onNav: widget.onNav,
    child: Form(
      key: form,
      child: stack([
        heading('Vincular sua escola'),
        progress(0),
        note(
          'A escola já existe na base. Localize o registro e atualize apenas os contatos permitidos.',
          icon: '95835.svg',
        ),
        Entry(
          'Buscar escola na base *',
          controller: search,
          icon: '45a4d.svg',
          help: 'Escola encontrada e selecionada • ${widget.data.school.city}',
          validator: (v) =>
              v?.trim().toLowerCase() == widget.data.school.name.toLowerCase()
              ? null
              : 'Selecione a escola vinculada ao seu perfil.',
        ),
        stack([
          section('Dados da escola'),
          label('Identificação da base • somente leitura', color: muted),
          Entry(
            'Nome da escola',
            value: widget.data.school.name,
            readOnly: true,
          ),
          const Entry(
            'Código INEP',
            value: '42•••••• • demonstrativo',
            readOnly: true,
          ),
          Entry(
            'Município',
            value: '${widget.data.school.city} / SC',
            readOnly: true,
          ),
        ]),
        stack([
          section('Direção e contato'),
          Entry(
            'Diretora cadastrada',
            value: widget.data.school.director,
            readOnly: true,
          ),
          const Entry(
            'CPF da diretora',
            value: '***.***.***-**',
            readOnly: true,
          ),
          Entry(
            'E-mail de contato *',
            controller: email,
            keyboard: TextInputType.emailAddress,
            validator: (v) =>
                RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v ?? '')
                ? null
                : 'Informe um e-mail válido.',
          ),
          Entry(
            'Telefone de contato *',
            controller: phone,
            keyboard: TextInputType.phone,
            validator: (v) =>
                [
                  10,
                  11,
                ].contains((v ?? '').replaceAll(RegExp(r'\D'), '').length)
                ? null
                : 'Informe DDD e telefone.',
          ),
        ]),
        label(
          '* Campos obrigatórios. Dados de exemplo; não representam uma escola real.',
          size: 12,
          color: muted,
        ),
        ActionButton(
          'Salvar vinculação',
          icon: 'cd636.svg',
          busy: busy,
          onTap: () => save(() async {
            await widget.repo.saveSchool(email.text.trim(), phone.text.trim());
            await widget.onSaved();
          }, pop: false),
        ),
      ], gap: 24),
    ),
  );
}

class SlateForm extends StatefulWidget {
  const SlateForm({
    super.key,
    required this.repo,
    required this.data,
    this.slate,
    this.segment = 0,
  });
  final ElectionRepository repo;
  final ElectionData data;
  final Slate? slate;
  final int segment;
  @override
  State<SlateForm> createState() => _SlateFormState();
}

class _SlateFormState extends State<SlateForm> with Saving {
  late int segment = widget.slate?.segment ?? widget.segment;
  late final number = TextEditingController(text: widget.slate?.number ?? '');
  late final name = TextEditingController(text: widget.slate?.name ?? '');
  late final names = (widget.slate?.members ?? ['', ''])
      .map((s) => TextEditingController(text: s))
      .toList();
  late final cpfs = List.generate(names.length, (_) => TextEditingController());
  @override
  void dispose() {
    number.dispose();
    name.dispose();
    for (final c in [...names, ...cpfs]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScreenFrame(
    title: widget.slate == null ? 'Nova chapa' : 'Editar chapa',
    onBack: () => Navigator.pop(context),
    child: Form(
      key: form,
      child: stack([
        heading(widget.slate == null ? 'Cadastrar chapa' : 'Editar chapa'),
        progress(1),
        schoolCard(widget.data.school, demo: widget.repo.isDemo),
        stack([
          section('Dados da chapa'),
          label('* Campos obrigatórios', size: 12, color: muted),
          label('Segmento *', size: 13, weight: FontWeight.w600),
          choices(segments, segment, (i) => setState(() => segment = i)),
          Entry(
            'Número da chapa *',
            controller: number,
            hint: '01',
            keyboard: TextInputType.number,
            help: 'Use um número ainda não cadastrado no segmento.',
            validator: (v) => RegExp(r'^\d{1,3}$').hasMatch(v ?? '')
                ? null
                : 'Informe de 1 a 3 dígitos.',
          ),
          Entry(
            'Nome da chapa *',
            controller: name,
            hint: 'Comunidade Presente',
            required: true,
          ),
        ]),
        stack([
          section('Integrantes'),
          label(
            'Identifique titulares e suplentes e confira os CPFs antes de salvar.',
            color: muted,
          ),
        ], gap: 6),
        for (var i = 0; i < names.length; i++)
          box(
            stack([
              Row(
                children: [
                  Expanded(child: label(i.isEven ? 'Titular' : 'Suplente')),
                  Flexible(child: badge(segments[segment])),
                ],
              ),
              Entry(
                'Nome completo *',
                controller: names[i],
                hint: i == 0 ? 'Ana Souza' : 'Paulo Lima',
                required: true,
              ),
              Entry(
                'CPF *',
                controller: cpfs[i],
                hint: '***.***.***-**',
                keyboard: TextInputType.number,
                help: widget.slate == null
                    ? 'Informe o CPF completo no cadastro real.'
                    : 'Deixe vazio para manter o CPF protegido.',
                validator: (v) =>
                    (v ?? '').isEmpty &&
                        (widget.repo.isDemo || widget.slate != null)
                    ? null
                    : validateCpf(v),
              ),
            ]),
            color: surface,
            border: false,
            radius: 16,
          ),
        ActionButton(
          'Adicionar integrante',
          secondary: true,
          icon: '1309f.svg',
          onTap: () => setState(() {
            names.add(TextEditingController());
            cpfs.add(TextEditingController());
          }),
        ),
        note(
          'Confira o vínculo dos integrantes com a escola. Evite repetir o mesmo CPF nesta chapa.',
          icon: '95835.svg',
        ),
        ActionButton(
          'Salvar chapa',
          icon: 'cd636.svg',
          busy: busy,
          onTap: () => save(() async {
            final values = cpfs
                .map((c) => c.text.replaceAll(RegExp(r'\D'), ''))
                .toList();
            final nonempty = values.where((v) => v.isNotEmpty).toList();
            if (nonempty.toSet().length != nonempty.length) {
              throw StateError('Não repita o mesmo CPF na chapa.');
            }
            await widget.repo.saveSlate(
              Slate(
                id: widget.slate?.id ?? '',
                number: number.text.padLeft(2, '0'),
                name: name.text.trim(),
                segment: segment,
                members: names.map((c) => c.text.trim()).toList(),
              ),
              values,
            );
          }),
        ),
        label(
          widget.repo.isDemo
              ? 'Ambiente demonstrativo • CPFs protegidos'
              : 'CPFs protegidos',
          size: 12,
          color: muted,
        ),
      ], gap: 24),
    ),
  );
}

class VoterForm extends StatefulWidget {
  const VoterForm({
    super.key,
    required this.repo,
    required this.data,
    this.voter,
  });
  final ElectionRepository repo;
  final ElectionData data;
  final Voter? voter;
  @override
  State<VoterForm> createState() => _VoterFormState();
}

class _VoterFormState extends State<VoterForm> with Saving {
  late int category = widget.voter?.category ?? 2;
  late final name = TextEditingController(text: widget.voter?.name ?? '');
  final cpf = TextEditingController();
  late String? studentId = widget.voter?.studentId;
  bool checked = false;
  @override
  void dispose() {
    name.dispose();
    cpf.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final students = widget.data.voters.where((v) => v.category == 0).toList();
    final student = students.where((v) => v.id == studentId).firstOrNull;
    final occupied =
        student != null &&
        widget.data.voters.any(
          (v) =>
              v.id != widget.voter?.id &&
              v.category == 2 &&
              v.enabled &&
              v.studentId == student.id,
        );
    return ScreenFrame(
      title: widget.voter == null ? 'Novo eleitor' : 'Editar eleitor',
      onBack: () => Navigator.pop(context),
      child: Form(
        key: form,
        child: stack([
          heading('Habilitar eleitor'),
          progress(2),
          schoolCard(widget.data.school, demo: widget.repo.isDemo),
          label(
            'Cadastro realizado pela direção da escola. O eleitor acessará com sua conta gov.br. * Campos obrigatórios.',
            color: muted,
          ),
          stack([
            label('Categoria *', size: 13, weight: FontWeight.w600),
            choices(
              categories,
              category,
              (v) => setState(() => category = v),
              circle: 'ad873.svg',
              iconSize: 16,
            ),
          ], gap: 8),
          Entry(
            'Nome completo *',
            controller: name,
            hint: 'Fernanda Martins',
            required: true,
          ),
          Entry(
            'CPF *',
            controller: cpf,
            hint: '000.000.000-00',
            keyboard: TextInputType.number,
            help: widget.voter == null
                ? 'O CPF informado deve corresponder ao CPF autenticado na conta gov.br do eleitor.'
                : 'Deixe vazio para manter o CPF protegido.',
            validator: (v) =>
                (v ?? '').isEmpty &&
                    (widget.repo.isDemo || widget.voter != null)
                ? null
                : validateCpf(v),
          ),
          Entry(
            'Vínculo com a escola *',
            key: ValueKey(category),
            value: [
              'Aluno matriculado',
              'Docente da escola',
              'Responsável por aluno matriculado',
              'Equipe administrativa',
            ][category],
            readOnly: true,
          ),
          if (category == 2)
            stack([
              section('Aluno vinculado'),
              label('Localizar aluno *', size: 13, weight: FontWeight.w600),
              DropdownButtonFormField<String>(
                initialValue: studentId,
                isExpanded: true,
                icon: asset('45a4d.svg', size: 19),
                style: const TextStyle(fontSize: 14, color: ink),
                hint: const Text('Selecione o aluno'),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: line),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: students
                    .map(
                      (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => studentId = v),
                validator: (v) => v == null
                    ? 'Selecione um aluno.'
                    : occupied
                    ? 'Aluno já possui responsável habilitado.'
                    : null,
              ),
              if (student != null)
                box(
                  stack([
                    label(student.name, size: 13),
                    label(
                      '${student.link} • CPF: ***.***.***-**',
                      size: 12,
                      color: muted,
                    ),
                    label(
                      occupied
                          ? 'Já possui responsável habilitado'
                          : 'Sem outro responsável habilitado',
                      size: 12,
                      color: occupied ? Colors.brown : green,
                    ),
                  ], gap: 4),
                  color: surface,
                  border: false,
                ),
              note(
                'Um responsável habilitado por aluno. Confira o vínculo antes de salvar.',
                icon: '07db0.svg',
              ),
            ]),
          stack([
            section('Acesso com gov.br'),
            label(
              'O eleitor acessará com sua conta gov.br. O CPF autenticado deve corresponder ao CPF habilitado pela escola.',
              color: muted,
            ),
          ], gap: 6),
          note(
            'A autenticação é feita pela conta gov.br e o CPF informado aqui deve ser o mesmo CPF autenticado.',
            icon: '51419.svg',
          ),
          box(
            stack([
              Row(
                children: [
                  Expanded(child: label('Situação do cadastro', size: 13)),
                  badge('Em conferência', warning: true),
                ],
              ),
              FormField<bool>(
                initialValue: false,
                validator: (_) =>
                    checked ? null : 'Confirme os dados para habilitar.',
                builder: (field) => stack([
                  InkWell(
                    onTap: () {
                      setState(() => checked = !checked);
                      field.didChange(checked);
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        checked
                            ? asset('322b9.svg')
                            : const Icon(
                                Icons.check_box_outline_blank,
                                color: green,
                                size: 20,
                              ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: label(
                            'Conferi os dados e o vínculo deste eleitor com a escola.',
                            size: 13,
                            color: green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (field.hasError)
                    label(
                      field.errorText!,
                      size: 12,
                      color: Theme.of(context).colorScheme.error,
                    ),
                ], gap: 6),
              ),
            ]),
            color: pale,
            border: false,
          ),
          ActionButton(
            'Salvar e habilitar eleitor',
            icon: '98ef7.svg',
            busy: busy,
            onTap: () => save(() async {
              await widget.repo.saveVoter(
                Voter(
                  id: widget.voter?.id ?? '',
                  name: name.text.trim(),
                  category: category,
                  link: category == 2
                      ? '${student!.name} • ${student.link}'
                      : [
                          'Aluno matriculado',
                          'docente da escola',
                          '',
                          'equipe administrativa',
                        ][category],
                  studentId: category == 2 ? studentId : null,
                ),
                cpf.text.replaceAll(RegExp(r'\D'), ''),
              );
            }),
          ),
          label(
            'Ao salvar, o eleitor poderá acessar com sua conta gov.br e votar no segmento correspondente ao cadastro.',
            size: 12,
            color: muted,
          ),
        ], gap: 24),
      ),
    );
  }
}
