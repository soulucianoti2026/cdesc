import { createClient } from 'npm:@supabase/supabase-js@2.99.1';
import { encrypt, digestCpf, validCpf } from './crypto.ts';

const required = (key: string): string => {
  const value = Deno.env.get(key);
  if (!value) throw new Error('Missing server configuration');
  return value;
};
const db = createClient(required('SUPABASE_URL'), required('SUPABASE_SERVICE_ROLE_KEY'), {
  auth: {persistSession: false, autoRefreshToken: false},
});
const allowedOrigins = (Deno.env.get('ALLOWED_ORIGINS') ?? '').split(',').filter(Boolean);
function text(value: unknown, max = 150): string {
  if (typeof value !== 'string' || !value.trim() || value.length > max) throw new Error('Invalid input');
  return value.trim();
}
function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Invalid input');
  return value as Record<string, unknown>;
}
function id(value: unknown, nullable = false): string | null {
  if (nullable && (value === null || value === '' || value === undefined)) return null;
  if (typeof value !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)) throw new Error('Invalid input');
  return value;
}
function integer(value: unknown, max: number): number {
  if (typeof value !== 'number' || !Number.isInteger(value) || value < 0 || value > max) throw new Error('Invalid input');
  return value;
}
async function protectCpf(value: unknown) {
  if (value === '') return null; // DB permits preserving an existing value only.
  if (typeof value !== 'string') throw new Error('Invalid input');
  const cpf = value.replace(/\D/g, '');
  if (!validCpf(cpf)) throw new Error('Invalid CPF');
  return {
    ...await encrypt(cpf, required('PII_ENCRYPTION_KEY'), 'cpf', required('PII_KEY_ID')),
    digest: await digestCpf(cpf, required('CPF_HMAC_KEY')),
  };
}
async function readBody(req: Request) {
  const reader = req.body?.getReader();
  if (!reader) throw new Error('Invalid input');
  const chunks: Uint8Array[] = [];
  let length = 0;
  while (true) {
    const {done, value} = await reader.read();
    if (done) break;
    length += value.length;
    if (length > 32768) { await reader.cancel(); throw new Error('Invalid input'); }
    chunks.push(value);
  }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  return object(JSON.parse(new TextDecoder().decode(bytes)));
}
Deno.serve(async (req) => {
  const origin = req.headers.get('origin');
  const headers: Record<string, string> = {
    'Content-Type': 'application/json', 'Cache-Control': 'no-store',
    'Vary': 'Origin', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };
  const reply = (data: unknown, status = 200) => new Response(JSON.stringify(data), {status, headers});
  if (origin && !allowedOrigins.includes(origin)) return reply({error: 'Origem não autorizada.'}, 403);
  if (origin) headers['Access-Control-Allow-Origin'] = origin;
  if (req.method === 'OPTIONS') return new Response(null, {status: 204, headers});
  if (req.method !== 'POST') return reply({error: 'Método não permitido.'}, 405);
  const token = req.headers.get('authorization')?.match(/^Bearer (.+)$/i)?.[1];
  if (!token) return reply({error: 'Autenticação necessária.'}, 401);
  try {
    const {data: {user}, error} = await db.auth.getUser(token);
    if (error || !user) return reply({error: 'Sessão inválida.'}, 401);
    // Provider identities are supplied by Auth, never user-editable metadata.
    const provider = Deno.env.get('GOVBR_PROVIDER') ?? 'custom:govbr';
    if (!user.identities?.some((identity) => identity.provider === provider)) {
      return reply({error: 'Entre com sua conta gov.br.'}, 403);
    }
    const body = await readBody(req);
    let rpc: string;
    let args: Record<string, unknown> = {actor: user.id};
    switch (body.action) {
      case 'bootstrap': rpc = 'cde_bootstrap'; break;
      case 'results':
        if (typeof body.final_result !== 'boolean') throw new Error('Invalid input');
        rpc = 'cde_results';
        args = {...args, final_result: body.final_result};
        break;
      case 'search_cpf': {
        rpc = 'cde_search_cpf';
        const cpf = text(body.cpf, 14).replace(/\D/g, '');
        if (!validCpf(cpf)) throw new Error('Invalid CPF');
        args = {...args, digest: await digestCpf(cpf, required('CPF_HMAC_KEY'))};
        break;
      }
      case 'save_school':
        rpc = 'cde_save_school';
        args = {...args, contact_email: text(body.email, 254), contact_phone: text(body.phone, 30)};
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(args.contact_email as string) || !/^\d{10,11}$/.test((args.contact_phone as string).replace(/\D/g, ''))) throw new Error('Invalid input');
        break;
      case 'save_slate': {
        rpc = 'cde_save_slate';
        const slate = object(body.slate);
        if (!Array.isArray(slate.members) || slate.members.length < 2 || slate.members.length > 20 ||
          !Array.isArray(body.cpfs) || body.cpfs.length !== slate.members.length) throw new Error('Invalid input');
        const number = text(slate.number, 3);
        if (!/^\d{2,3}$/.test(number)) throw new Error('Invalid input');
        args = {...args, payload: {id: id(slate.id, true), number, name: text(slate.name),
          segment: integer(slate.segment, 2), members: slate.members.map((member) => text(member))},
          encrypted_cpfs: await Promise.all(body.cpfs.map(protectCpf))};
        break;
      }
      case 'save_voter': {
        rpc = 'cde_save_voter';
        const voter = object(body.voter);
        const protectedCpf = await protectCpf(body.cpf);
        args = {...args, payload: {id: id(voter.id, true), name: text(voter.name), category: integer(voter.category, 3),
          link: text(voter.link, 300), student_id: id(voter.student_id, true)}, encrypted_cpf: protectedCpf, digest: protectedCpf?.digest ?? null};
        break;
      }
      case 'vote': {
        rpc = 'cde_vote';
        const slate = id(body.slate_id, true);
        const encrypted = await encrypt(JSON.stringify({slate_id: slate}), required('BALLOT_ENCRYPTION_KEY'), 'ballot', required('BALLOT_KEY_ID'));
        args = {...args, slate_id: slate, encrypted_ballot: encrypted};
        break;
      }
      default: return reply({error: 'Operação inválida.'}, 400);
    }
    const {data, error: rpcError} = await db.rpc(rpc, args);
    if (rpcError) {
      // Do not return database details, CPF values, keys, or ballot contents.
      const messages: Record<string, string> = {
        'Election is not open': 'A votação não está aberta.',
        'Final result unavailable': 'O resultado final só estará disponível após o encerramento da votação.',
        'Result not published': 'A apuração ainda não foi publicada pela comissão eleitoral.',
        'Election is locked': 'Os cadastros estão encerrados para esta eleição.',
        'Access denied': 'Seu acesso não está habilitado para esta escola.',
        'Invalid student': 'Selecione um aluno desta escola.',
        'CPF required': 'Informe o CPF de todos os integrantes.',
        'Duplicate CPF': 'Não repita o mesmo CPF na chapa.',
      };
      return reply({error: rpcError.code === '23505' ? 'Cadastro duplicado ou aluno já possui responsável habilitado.' : messages[rpcError.message] ?? 'Não foi possível concluir a operação.'}, 409);
    }
    return reply(['bootstrap', 'search_cpf', 'results'].includes(body.action as string) ? data : {ok: true});
  } catch (error) {
    const invalid = error instanceof Error && ['Invalid input', 'Invalid CPF'].includes(error.message);
    return reply({error: invalid ? 'Confira os campos informados e o CPF.' : 'Serviço indisponível. Tente novamente.'}, invalid ? 400 : 503);
  }
});
