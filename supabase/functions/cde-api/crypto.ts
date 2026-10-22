const enc = new TextEncoder();
export function decode(value: string): Uint8Array<ArrayBuffer> {
  return Uint8Array.from(atob(value), (c) => c.charCodeAt(0));
}
function base64(value: ArrayBuffer | Uint8Array): string {
  return btoa(String.fromCharCode(...new Uint8Array(value)));
}
export function validCpf(value: string): boolean {
  if (!/^\d{11}$/.test(value) || /^(\d)\1{10}$/.test(value)) return false;
  const digits = [...value].map(Number);
  for (let size = 9; size <= 10; size++) {
    const sum = digits.slice(0, size).reduce((n, digit, i) => n + digit * (size + 1 - i), 0);
    if (((sum * 10) % 11) % 10 !== digits[size]) return false;
  }
  return true;
}
export async function encrypt(value: string, secret: string, purpose: string, kid: string) {
  const raw = decode(secret);
  if (raw.length !== 32) throw new Error('Invalid encryption key');
  const key = await crypto.subtle.importKey('raw', raw, 'AES-GCM', false, ['encrypt']);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const aad = 'cde:' + purpose + ':v1:' + kid;
  const ciphertext = await crypto.subtle.encrypt({name: 'AES-GCM', iv, additionalData: enc.encode(aad), tagLength: 128}, key, enc.encode(value));
  return {v: 1, kid, alg: 'A256GCM', iv: base64(iv), ciphertext: base64(ciphertext)};
}
export async function digestCpf(cpf: string, secret: string) {
  const raw = decode(secret);
  if (raw.length !== 32) throw new Error('Invalid HMAC key');
  const key = await crypto.subtle.importKey('raw', raw, {name: 'HMAC', hash: 'SHA-256'}, false, ['sign']);
  return base64(await crypto.subtle.sign('HMAC', key, enc.encode('cde:cpf:v1:' + cpf)));
}
