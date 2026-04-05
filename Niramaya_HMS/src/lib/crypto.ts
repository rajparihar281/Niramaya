/**
 * AES-256-GCM Client-Side Encryption Utilities
 * Uses the Web Crypto API for HIPAA-grade data protection.
 */

// ─── Key Management ──────────────────────────────────────────────

/** Generate a new AES-256-GCM key */
export async function generateEncryptionKey(): Promise<CryptoKey> {
  return window.crypto.subtle.generateKey(
    { name: 'AES-GCM', length: 256 },
    true,  // extractable
    ['encrypt', 'decrypt']
  );
}

/** Export a CryptoKey to a base64-encoded string for storage */
export async function exportKey(key: CryptoKey): Promise<string> {
  const raw = await window.crypto.subtle.exportKey('raw', key);
  return arrayBufferToBase64(raw);
}

/** Import a base64-encoded key string back into a CryptoKey */
export async function importKey(base64Key: string): Promise<CryptoKey> {
  const raw = base64ToArrayBuffer(base64Key);
  return window.crypto.subtle.importKey(
    'raw',
    raw,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt', 'decrypt']
  );
}

// ─── Encrypt / Decrypt ───────────────────────────────────────────

/** Encrypt arbitrary data with AES-256-GCM. Returns base64 cipher + iv. */
export async function encrypt(
  data: unknown,
  key: CryptoKey
): Promise<{ cipher: string; iv: string }> {
  const encoded = new TextEncoder().encode(JSON.stringify(data));
  const iv = window.crypto.getRandomValues(new Uint8Array(12));

  const encrypted = await window.crypto.subtle.encrypt(
    { name: 'AES-GCM', iv },
    key,
    encoded
  );

  return {
    cipher: arrayBufferToBase64(encrypted),
    iv: arrayBufferToBase64(iv.buffer),
  };
}

/** Decrypt a base64 cipher + iv back into the original object */
export async function decrypt<T = unknown>(
  cipherBase64: string,
  ivBase64: string,
  key: CryptoKey
): Promise<T> {
  const cipherBuffer = base64ToArrayBuffer(cipherBase64);
  const ivBuffer = base64ToArrayBuffer(ivBase64);

  const decrypted = await window.crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: new Uint8Array(ivBuffer) },
    key,
    cipherBuffer
  );

  const text = new TextDecoder().decode(decrypted);
  return JSON.parse(text) as T;
}

// ─── Helpers ─────────────────────────────────────────────────────

function arrayBufferToBase64(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let binary = '';
  bytes.forEach((b) => (binary += String.fromCharCode(b)));
  return btoa(binary);
}

function base64ToArrayBuffer(base64: string): ArrayBuffer {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}
