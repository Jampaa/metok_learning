// Security rules tests (spec §7, §10: "the security rules block
// cross-user access"). Run from firebase/tests with `npm test`, which
// starts the Firestore and Storage emulators.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';
import { ref, uploadBytes, getBytes } from 'firebase/storage';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-yonten',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 8085,
    },
    storage: {
      rules: readFileSync(new URL('../storage.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 9199,
    },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'curriculum/unit1'), { order: 1, title: 'The Alphabet' });
    await setDoc(doc(db, 'vocab/apple'), { english: 'apple', verified: false });
    await setDoc(doc(db, 'users/alice'), {
      xp: 10,
      progress: { currentLessonId: 'unit1-kha', completedLessonIds: ['unit1-ka'] },
    });
    await setDoc(doc(db, 'users/alice/words/apple'), { english: 'apple' });
  });
});

const alice = () => env.authenticatedContext('alice').firestore();
const bob = () => env.authenticatedContext('bob').firestore();
const nobody = () => env.unauthenticatedContext().firestore();

describe('global content', () => {
  test('signed-in users can read curriculum and vocab', async () => {
    await assertSucceeds(getDoc(doc(alice(), 'curriculum/unit1')));
    await assertSucceeds(getDoc(doc(alice(), 'vocab/apple')));
  });

  test('nobody can read without signing in', async () => {
    await assertFails(getDoc(doc(nobody(), 'curriculum/unit1')));
  });

  test('clients can never write curriculum or vocab', async () => {
    await assertFails(setDoc(doc(alice(), 'curriculum/unit1'), { title: 'x' }));
    await assertFails(setDoc(doc(alice(), 'vocab/apple'), { verified: true }));
  });
});

describe('users/{uid}', () => {
  test('owner reads and writes their own data', async () => {
    await assertSucceeds(getDoc(doc(alice(), 'users/alice')));
    await assertSucceeds(getDoc(doc(alice(), 'users/alice/words/apple')));
    await assertSucceeds(setDoc(doc(alice(), 'users/alice/stickers/chorten'), { fromLessonId: 'unit1-chest-1' }));
    await assertSucceeds(setDoc(doc(alice(), 'users/alice/quests/2026-10-09'), { quests: [] }));
    await assertSucceeds(setDoc(doc(alice(), 'users/alice/photos/p1'), { status: 'found' }));
  });

  test('another user cannot read or write it', async () => {
    await assertFails(getDoc(doc(bob(), 'users/alice')));
    await assertFails(getDoc(doc(bob(), 'users/alice/words/apple')));
    await assertFails(setDoc(doc(bob(), 'users/alice'), { xp: 999 }));
    await assertFails(setDoc(doc(bob(), 'users/alice/words/pear'), { english: 'pear' }));
    await assertFails(getDoc(doc(bob(), 'users/alice/photos/p1')));
    await assertFails(deleteDoc(doc(bob(), 'users/alice')));
  });

  test('a new child can create their own doc', async () => {
    await assertSucceeds(setDoc(doc(bob(), 'users/bob'), { xp: 0 }));
  });

  test('progress can grow', async () => {
    await assertSucceeds(updateDoc(doc(alice(), 'users/alice'), {
      'progress.completedLessonIds': ['unit1-ka', 'unit1-kha'],
      'progress.currentLessonId': 'unit1-ga',
    }));
  });

  test('progress can never shrink', async () => {
    await assertFails(updateDoc(doc(alice(), 'users/alice'), {
      'progress.completedLessonIds': [],
    }));
    await assertFails(setDoc(doc(alice(), 'users/alice'), { xp: 0 }));
  });

  test('other fields can change without touching progress', async () => {
    await assertSucceeds(setDoc(doc(alice(), 'users/alice'),
      { xp: 20 }, { merge: true }));
  });

  test('legacy discoveries stay admin-only even for the owner', async () => {
    await assertFails(setDoc(doc(alice(), 'users/alice/discoveries/apple'), { x: 1 }));
  });
});

describe('storage', () => {
  const png = new Uint8Array([137, 80, 78, 71]);

  test('audio is public to read, never client-writable', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      uploadBytes(ref(ctx.storage(), 'audio/apple.mp3'), png, { contentType: 'audio/mpeg' }));
    await assertSucceeds(getBytes(ref(env.unauthenticatedContext().storage(), 'audio/apple.mp3')));
    await assertFails(uploadBytes(ref(env.authenticatedContext('alice').storage(), 'audio/x.mp3'), png, { contentType: 'audio/mpeg' }));
  });

  test('owner can upload a small image to their own folder', async () => {
    await assertSucceeds(uploadBytes(
      ref(env.authenticatedContext('alice').storage(), 'users/alice/thumbs/apple.png'),
      png, { contentType: 'image/png' }));
  });

  test('no uploads to someone else, no non-images, nothing over 2 MB', async () => {
    const s = env.authenticatedContext('alice').storage();
    await assertFails(uploadBytes(ref(env.authenticatedContext('bob').storage(), 'users/alice/x.png'), png, { contentType: 'image/png' }));
    await assertFails(uploadBytes(ref(s, 'users/alice/x.txt'), png, { contentType: 'text/plain' }));
    await assertFails(uploadBytes(ref(s, 'users/alice/big.png'), new Uint8Array(2 * 1024 * 1024 + 1), { contentType: 'image/png' }));
  });
});
