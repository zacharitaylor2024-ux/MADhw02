const { before, after, test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment, assertFails, assertSucceeds
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, getDocs, collection, setDoc, updateDoc, deleteDoc,
  serverTimestamp } = require('firebase/firestore');

let env;
const projectId = process.env.GCLOUD_PROJECT || 'demo-message-board';
const message = (uid, text='Hello!') => ({
  text, authorUid: uid, authorName: 'Tester',
  createdAt: serverTimestamp(), editedAt: null
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: { rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8') }
  });
  await env.withSecurityRulesDisabled(async ctx => {
    await setDoc(doc(ctx.firestore(), 'messages', 'owned-by-a'), {
      text: 'A post', authorUid: 'user-a', authorName: 'User A',
      createdAt: new Date(), editedAt: null
    });
  });
});

after(async () => { if (env) await env.cleanup(); });

test('signed-out board read is denied', async () => {
  await assertFails(getDocs(collection(env.unauthenticatedContext().firestore(), 'messages')));
});

test('different user cannot edit or delete another author', async () => {
  const db = env.authenticatedContext('user-b').firestore();
  await assertFails(updateDoc(doc(db, 'messages', 'owned-by-a'),
    {text: 'Hacked', editedAt: serverTimestamp()}));
  await assertFails(deleteDoc(doc(db, 'messages', 'owned-by-a')));
});

test('forged authorUid is denied', async () => {
  const db = env.authenticatedContext('user-b').firestore();
  await assertFails(setDoc(doc(db, 'messages', 'forgery'), message('user-a')));
});

test('correct author can create, read, edit and delete', async () => {
  const db = env.authenticatedContext('user-a').firestore();
  const target = doc(db, 'messages', 'new-owned');
  await assertSucceeds(setDoc(target, message('user-a')));
  assert.equal((await assertSucceeds(getDoc(target))).data().text, 'Hello!');
  await assertSucceeds(updateDoc(target, {text: 'Updated!', editedAt: serverTimestamp()}));
  assert.equal((await getDoc(target)).data().text, 'Updated!');
  await assertSucceeds(deleteDoc(target));
});

test('a second create with same ID is blocked', async () => {
  const db = env.authenticatedContext('user-a').firestore();
  const target = doc(db, 'messages', 'owned-by-a');
  await assertFails(setDoc(target, message('user-a', 'Duplicate')));
  assert.equal((await getDoc(target)).data().text, 'A post');
});

test('user profile belongs to its UID and cannot be forged', async () => {
  const db = env.authenticatedContext('user-a').firestore();
  const own = doc(db, 'users', 'user-a');
  await assertSucceeds(setDoc(own, {
    uid:'user-a', firstName:'Alice', lastName:'Tester', role:'member',
    registrationDateTime: serverTimestamp()
  }));
  await assertFails(getDoc(doc(env.authenticatedContext('user-b').firestore(), 'users', 'user-a')));
  await assertFails(setDoc(doc(db, 'users', 'user-b'), {
    uid:'user-b', firstName:'Fake', lastName:'User', role:'member',
    registrationDateTime: serverTimestamp()
  }));
});
