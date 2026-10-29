import { readFileSync } from 'node:fs';
import test from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, query, setDoc, updateDoc, where } from 'firebase/firestore';

test('party discovery is authenticated, public, open and read-only', async () => {
 const env = await initializeTestEnvironment({projectId:'demo-lurk-parties',firestore:{
   host:'127.0.0.1',port:8080,
   rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}});
 try {
   await env.clearFirestore();
   await env.withSecurityRulesDisabled(async context => {
     const db=context.firestore();
     for (const [id, visibility, status] of [
       ['public','public','open'],['private','private','open'],['ended','public','completed']]) {
       await setDoc(doc(db,`parties/${id}`),{title:id,visibility,status,hostId:'alice'});
     }
   });
   const alice=env.authenticatedContext('alice').firestore();
   const guest=env.unauthenticatedContext().firestore();
   const discovery=db=>query(collection(db,'parties'),where('visibility','==','public'),where('status','==','open'));
   await assertSucceeds(getDocs(discovery(alice)));
   await assertSucceeds(getDoc(doc(alice,'parties/public')));
   await assertFails(getDocs(discovery(guest)));
   await assertFails(getDocs(collection(alice,'parties')));
   await assertFails(getDoc(doc(alice,'parties/private')));
   await assertFails(getDoc(doc(alice,'parties/ended')));
   await assertFails(setDoc(doc(alice,'parties/new'),{visibility:'public',status:'open'}));
   await assertFails(updateDoc(doc(alice,'parties/public'),{memberCount:99}));
   await assertFails(setDoc(doc(alice,'parties/public/members/alice'),{role:'host'}));
 } finally { await env.cleanup(); }
});