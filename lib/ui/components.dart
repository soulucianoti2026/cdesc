import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../data/models.dart';

const green = Color(0xff176347),
    ink = Color(0xff182c25),
    muted = Color(0xff62736b);
const pale = Color(0xffeaf4ee),
    surface = Color(0xfff5f8f6),
    line = Color(0xffdce5df);
Widget asset(String file, {double size = 20, double? width}) =>
    file.endsWith('.svg')
    ? SvgPicture.asset('assets/figma/$file', width: width ?? size, height: size)
    : Image.asset(
        'assets/figma/$file',
        width: width ?? size,
        height: size,
        fit: BoxFit.cover,
      );
Widget label(
  String value, {
  double size = 14,
  Color color = ink,
  FontWeight weight = FontWeight.w400,
  double height = 1.5,
  TextAlign? align,
}) => Text(
  value,
  textAlign: align,
  style: TextStyle(
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: height,
  ),
);
Widget heading(String value) =>
    label(value, size: 28, weight: FontWeight.w700, height: 1.18);
Widget section(String value) => label(value, size: 18, weight: FontWeight.w600);
Widget stack(
  List<Widget> children, {
  double gap = 16,
  CrossAxisAlignment align = CrossAxisAlignment.start,
}) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: align,
  children: [
    for (var i = 0; i < children.length; i++) ...[
      if (i > 0) SizedBox(height: gap),
      children[i],
    ],
  ],
);
Widget box(
  Widget child, {
  Color color = Colors.white,
  bool border = true,
  double padding = 16,
  double radius = 12,
  Color borderColor = line,
}) => Container(
  width: double.infinity,
  padding: EdgeInsets.all(padding),
  decoration: BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: border ? Border.all(color: borderColor) : null,
  ),
  child: child,
);
Widget note(String text, {String icon = 'f3a7f.svg', bool warning = false}) =>
    box(
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          asset(icon),
          const SizedBox(width: 12),
          Expanded(
            child: label(
              text,
              size: 13,
              color: warning ? const Color(0xff835c18) : green,
            ),
          ),
        ],
      ),
      color: warning ? const Color(0xfffbf5e8) : pale,
      border: false,
    );
Widget schoolCard(School school, {bool voter = false, bool demo = true}) => box(
  stack([
    label(school.name, weight: FontWeight.w600),
    label('${school.city} • Eleição CDE 2026', size: 12, color: muted),
    label(
      '${demo ? 'Ambiente demonstrativo' : 'Acesso autenticado'}${voter ? ' • Acesso do eleitor' : ''}',
      size: 11,
      color: muted,
    ),
  ], gap: 4),
  color: surface,
  border: false,
);
Widget progress(int index, {bool voting = false}) {
  final names = voting
      ? ['Escolher', 'Conferir', 'Concluir']
      : ['Escola', 'Chapas', 'Eleitores'];
  return Row(
    children: [
      for (var i = 0; i < 3; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: stack([
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: i <= index ? green : line,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            label(
              names[i],
              size: 11,
              color: i <= index ? green : muted,
              weight: i == index ? FontWeight.w700 : FontWeight.w400,
            ),
          ], gap: 8),
        ),
      ],
    ],
  );
}

class ActionButton extends StatelessWidget {
  const ActionButton(
    this.text, {
    super.key,
    required this.onTap,
    this.icon,
    this.secondary = false,
    this.busy = false,
  });
  final String text;
  final VoidCallback? onTap;
  final String? icon;
  final bool secondary, busy;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        backgroundColor: secondary ? Colors.white : green,
        foregroundColor: secondary ? green : Colors.white,
        side: BorderSide(color: secondary ? line : green),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: busy ? null : onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else if (icon != null)
            asset(icon!),
          if (busy || icon != null) const SizedBox(width: 10),
          Flexible(
            child: label(
              text,
              size: 15,
              color: secondary ? green : Colors.white,
              weight: FontWeight.w600,
              align: TextAlign.center,
            ),
          ),
        ],
      ),
    ),
  );
}

class Entry extends StatelessWidget {
  const Entry(
    this.title, {
    super.key,
    this.controller,
    this.value,
    this.hint,
    this.help,
    this.readOnly = false,
    this.icon,
    this.validator,
    this.onChanged,
    this.keyboard,
    this.required = false,
  });
  final String title;
  final TextEditingController? controller;
  final String? value, hint, help, icon;
  final bool readOnly, required;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboard;
  @override
  Widget build(BuildContext context) => stack([
    label(title, size: 13, weight: FontWeight.w600),
    TextFormField(
      controller: controller,
      initialValue: controller == null ? value : null,
      readOnly: readOnly,
      keyboardType: keyboard,
      onChanged: onChanged,
      style: TextStyle(fontSize: 14, color: readOnly ? muted : ink),
      validator:
          validator ??
          (required
              ? (v) =>
                    v == null || v.trim().isEmpty ? 'Campo obrigatório.' : null
              : null),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: readOnly ? const Color(0xffedf1ee) : Colors.white,
        suffixIcon: icon == null && !readOnly
            ? null
            : Padding(
                padding: const EdgeInsets.all(17),
                child: asset(icon ?? '207fb.svg', size: 19),
              ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
      ),
    ),
    if (help != null) label(help!, size: 12, color: muted),
  ], gap: 8);
}

Widget choices(
  List<String> values,
  int selected,
  ValueChanged<int> change, {
  String circle = '0767a.svg',
  double iconSize = 18,
}) => stack([
  for (var i = 0; i < values.length; i++)
    Semantics(
      selected: selected == i,
      button: true,
      child: InkWell(
        onTap: () => change(i),
        borderRadius: BorderRadius.circular(12),
        child: box(
          Row(
            children: [
              asset(selected == i ? 'a38c8.svg' : circle, size: iconSize),
              const SizedBox(width: 12),
              Expanded(
                child: label(
                  values[i],
                  size: 13,
                  color: selected == i ? green : ink,
                ),
              ),
            ],
          ),
          padding: 14,
          color: selected == i ? pale : Colors.white,
          borderColor: selected == i ? green : line,
        ),
      ),
    ),
], gap: 8);
Widget badge(String text, {bool warning = false}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(
    color: warning ? const Color(0xfffbf5e8) : pale,
    borderRadius: BorderRadius.circular(100),
  ),
  child: label(
    text,
    size: 11,
    color: warning ? const Color(0xff835c18) : green,
    height: 1.2,
  ),
);

class ScreenFrame extends StatelessWidget {
  const ScreenFrame({
    super.key,
    required this.title,
    required this.child,
    this.onBack,
    this.navIndex,
    this.onNav,
    this.voting = false,
    this.login = false,
    this.onLogout,
  });
  final String title;
  final Widget child;
  final VoidCallback? onBack, onLogout;
  final int? navIndex;
  final ValueChanged<int>? onNav;
  final bool voting, login;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: surface,
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ColoredBox(
          color: Colors.white,
          child: SafeArea(
            child: Column(
              children: [
                if (login)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 4,
                          color: const Color(0xffb63743),
                        ),
                      ),
                      const Spacer(),
                      Expanded(child: Container(height: 4, color: green)),
                    ],
                  ),
                if (!login)
                  Container(
                    height: 66,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: line)),
                    ),
                    child: Row(
                      children: [
                        if (onBack != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: InkWell(
                              onTap: onBack,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: asset('873b8.svg', size: 22),
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: asset('f4fd8.svg', size: 22),
                          ),
                        Expanded(
                          child: stack([
                            label(
                              title,
                              size: 17,
                              weight: FontWeight.w700,
                              height: 1.2,
                            ),
                            label(
                              '${voting ? 'VOTAÇÃO' : 'GESTÃO ESCOLAR'} • CDE 2026',
                              size: 12,
                              color: muted,
                              height: 1.2,
                            ),
                          ], gap: 3),
                        ),
                        Semantics(
                          label: 'Bandeira de Santa Catarina',
                          child: asset('84863.png', size: 30, width: 40),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    key: ValueKey(title),
                    padding: EdgeInsets.fromLTRB(
                      login ? 28 : 24,
                      24,
                      login ? 28 : 24,
                      28,
                    ),
                    child: child,
                  ),
                ),
                if (navIndex != null)
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: line)),
                    ),
                    child: Row(
                      children: [
                        for (var i = 0; i < 4; i++)
                          Expanded(
                            child: InkWell(
                              onTap: () => onNav!(i),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 60,
                                decoration: BoxDecoration(
                                  color: navIndex == i ? pale : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    asset(
                                      (navIndex == i
                                          ? [
                                              '05691.svg',
                                              '3ab60.svg',
                                              '54753.svg',
                                              'f34d6.svg',
                                            ]
                                          : [
                                              'ba318.svg',
                                              '2ad5c.svg',
                                              '60d05.svg',
                                              'a839b.svg',
                                            ])[i],
                                      size: 21,
                                    ),
                                    const SizedBox(height: 6),
                                    label(
                                      [
                                        'Painel',
                                        'Escola',
                                        'Chapas',
                                        'Eleitores',
                                      ][i],
                                      size: 11,
                                      color: navIndex == i ? green : muted,
                                      weight: navIndex == i
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
