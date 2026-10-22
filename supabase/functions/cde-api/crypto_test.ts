import {decode, encrypt, digestCpf, validCpf} from './crypto.ts';
const assert = (condition: boolean) => {if (!condition) throw new Error('Assertion failed');};
const key = btoa(String.fromCharCode(...new Uint8Array(32).fill(7)));
Deno.test('AES-GCM uses random IVs and authenticates contents and purpose', async () => {
  const a = await encrypt('synthetic-secret', key, 'cpf', 'test-v1');
  const b = await encrypt('synthetic-secret', key, 'cpf', 'test-v1');
  assert(a.iv !== b.iv && a.ciphertext !== b.ciphertext);
  const cryptoKey = await crypto.subtle.importKey('raw', decode(key), 'AES-GCM', false, ['decrypt']);
  const params = {name: 'AES-GCM', iv: decode(a.iv), additionalData: new TextEncoder().encode('cde:cpf:v1:test-v1')};
  const plain = await crypto.subtle.decrypt(params, cryptoKey, decode(a.ciphertext));
  assert(new TextDecoder().decode(plain) === 'synthetic-secret');
  const corrupt = decode(a.ciphertext); corrupt[0] ^= 1;
  let rejected = false;
  try { await crypto.subtle.decrypt(params, cryptoKey, corrupt); } catch { rejected = true; }
  assert(rejected);
  rejected = false;
  try { await crypto.subtle.decrypt({...params, additionalData: new TextEncoder().encode('cde:ballot:v1:test-v1')}, cryptoKey, decode(a.ciphertext)); } catch { rejected = true; }
  assert(rejected);
});
Deno.test('CPF validation and keyed digest', async () => {
  assert(validCpf('52998224725'));
  assert(!validCpf('00000000000'));
  assert(!validCpf('52998224724'));
  assert(await digestCpf('52998224725', key) === await digestCpf('52998224725', key));
  const otherKey = btoa(String.fromCharCode(...new Uint8Array(32).fill(8)));
  assert(await digestCpf('52998224725', key) !== await digestCpf('52998224725', otherKey));
});
