import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';
import 'mock_repository.dart';
import 'results.dart';

abstract class ElectionRepository {
  bool get isDemo;
  Future<void> signIn({bool director = true});
  Future<void> signOut();
  Future<ElectionData> load();
  Future<List<Voter>> searchCpf(String cpf);
  Future<void> saveSchool(String email, String phone);
  Future<void> saveSlate(Slate slate, List<String> cpfs);
  Future<void> saveVoter(Voter voter, String cpf);
  Future<void> vote(String? slateId);
  Future<ElectionResults> loadResults({required bool finalResult});
}

Future<ElectionRepository> createRepository() async {
  const demo = bool.fromEnvironment('DEMO_MODE', defaultValue: true);
  if (demo) return MockRepository();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (Uri.tryParse(url)?.scheme != 'https' || key.isEmpty) {
    throw StateError(
      'Configure SUPABASE_URL HTTPS e SUPABASE_PUBLISHABLE_KEY.',
    );
  }
  await Supabase.initialize(
    url: url,
    publishableKey: key,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      persistSession: false,
    ),
  );
  return SupabaseRepository(Supabase.instance.client);
}

class SupabaseRepository implements ElectionRepository {
  SupabaseRepository(this.client);
  final SupabaseClient client;
  @override
  Future<ElectionResults> loadResults({required bool finalResult}) async =>
      ElectionResults.fromJson(
        await _call('results', {'final_result': finalResult}),
      );
  @override
  bool get isDemo => false;
  @override
  Future<void> signIn({bool director = true}) async {
    if (client.auth.currentSession != null) return;
    const redirect = String.fromEnvironment(
      'AUTH_REDIRECT_URL',
      defaultValue: 'br.sc.cde://login-callback',
    );
    const provider = String.fromEnvironment(
      'GOVBR_PROVIDER',
      defaultValue: 'custom:govbr',
    );
    // SDK 2.18 has an enum-only provider argument. Generate and retain the
    // SDK's PKCE verifier, then replace only the authorize provider identifier.
    final result = await client.auth.getOAuthSignInUrl(
      provider: OAuthProvider.keycloak,
      redirectTo: kIsWeb ? Uri.base.origin : redirect,
      scopes: 'openid profile email',
    );
    final uri = Uri.parse(result.url);
    final authorize = uri.replace(
      queryParameters: {...uri.queryParameters, 'provider': provider},
    );
    final signedIn = Completer<void>();
    final subscription = client.auth.onAuthStateChange.listen(
      (event) {
        if (event.session != null && !signedIn.isCompleted) signedIn.complete();
      },
      onError: (Object error) {
        if (!signedIn.isCompleted) signedIn.completeError(error);
      },
    );
    try {
      if (!await launchUrl(
        authorize,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_self',
      )) {
        throw StateError('Não foi possível abrir o acesso gov.br.');
      }
      await signedIn.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () =>
            throw StateError('Acesso não concluído. Tente novamente.'),
      );
    } finally {
      await subscription.cancel();
    }
  }

  Future<Map<String, dynamic>> _call(
    String action, [
    Map<String, dynamic> payload = const {},
  ]) async {
    if (client.auth.currentSession == null) {
      throw StateError('Sua sessão expirou. Entre novamente.');
    }
    try {
      final response = await client.functions.invoke(
        'cde-api',
        body: {'action': action, ...payload},
      );
      final value = Map<String, dynamic>.from(response.data as Map);
      if (value['error'] != null) throw StateError(value['error']);
      return value;
    } on FunctionException catch (e) {
      final details = e.details;
      throw StateError(
        details is Map && details['error'] is String
            ? details['error']
            : 'Não foi possível concluir a solicitação.',
      );
    }
  }

  @override
  Future<ElectionData> load() async {
    final j = await _call('bootstrap');
    return ElectionData(
      school: School.fromJson(j['school']),
      slates: (j['slates'] as List).map((s) => Slate.fromJson(s)).toList(),
      voters: (j['voters'] as List).map((v) => Voter.fromJson(v)).toList(),
      director: j['director'],
      userName: j['user_name'],
      segment: j['segment'],
      hasVoted: j['has_voted'],
      electionDate: j['election_date'],
      electionStatus: j['election_status'],
    );
  }

  @override
  Future<void> signOut() => client.auth.signOut();
  @override
  Future<List<Voter>> searchCpf(String cpf) async {
    final result = await _call('search_cpf', {'cpf': cpf});
    return (result['voters'] as List).map((v) => Voter.fromJson(v)).toList();
  }

  @override
  Future<void> saveSchool(String email, String phone) async {
    await _call('save_school', {'email': email, 'phone': phone});
  }

  @override
  Future<void> saveSlate(Slate slate, List<String> cpfs) async {
    await _call('save_slate', {'slate': slate.toJson(), 'cpfs': cpfs});
  }

  @override
  Future<void> saveVoter(Voter voter, String cpf) async {
    await _call('save_voter', {'voter': voter.toJson(), 'cpf': cpf});
  }

  @override
  Future<void> vote(String? slateId) async {
    await _call('vote', {'slate_id': slateId});
  }
}
