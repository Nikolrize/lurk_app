import {readFileSync} from 'node:fs';
import test from 'node:test';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,setDoc,deleteDoc,getDoc,serverTimestamp,writeBatch} from 'firebase/firestore';

test('preserved blocks and chat settings still protect conversations',async()=>{
 const env=await initializeTestEnvironment({projectId:'demo-lurk-social-preservation',firestore:{
   host:'127.0.0.1',port:8080,rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}});
 try {
   await env.clearFirestore();
   await env.withSecurityRulesDisabled(async context=>{
     await setDoc(doc(context.firestore(),'players/alice'),{username:'Alice'});
     await setDoc(doc(context.firestore(),'players/bob'),{username:'Bob'});
   });
   const alice=env.authenticatedContext('alice').firestore();
   const bob=env.authenticatedContext('bob').firestore();
   const guest=env.unauthenticatedContext().firestore();
   const chat=()=>({type:'direct',userIds:['alice','bob'],createdAt:serverTimestamp(),updatedAt:serverTimestamp(),
     lastMessageId:'',lastMessagePreview:'',lastSenderId:''});
   await assertSucceeds(setDoc(doc(alice,'player_blocks/alice/users/bob'),{createdAt:serverTimestamp()}));
   await assertSucceeds(getDoc(doc(bob,'player_blocks/alice/users/bob')));
   await assertFails(getDoc(doc(guest,'player_blocks/alice/users/bob')));
   await assertFails(setDoc(doc(bob,'chats/blocked'),chat()));
   await assertFails(deleteDoc(doc(bob,'player_blocks/alice/users/bob')));
   await assertSucceeds(deleteDoc(doc(alice,'player_blocks/alice/users/bob')));
   // Preserve the newer block path alongside existing users-path blocks.
   await assertSucceeds(setDoc(doc(alice,'player_blocks/alice/blocked/bob'),{createdAt:serverTimestamp()}));
   await assertFails(setDoc(doc(bob,'chats/newer-blocked'),chat()));
   await assertSucceeds(deleteDoc(doc(alice,'player_blocks/alice/blocked/bob')));
   const report={reporterId:'alice',reporterUsername:'Alice',playerId:'bob',playerUsername:'Bob',reasons:['Harassment'],details:'Test report',status:'pending',createdAt:serverTimestamp()};
   await assertSucceeds(setDoc(doc(alice,'player_reports/valid'),report));
   await assertFails(setDoc(doc(bob,'player_reports/forged'),report));
   await assertFails(getDoc(doc(alice,'player_reports/valid')));
   await assertSucceeds(setDoc(doc(alice,'chats/direct'),chat()));
   await assertSucceeds(setDoc(doc(alice,'chats/direct/settings/alice'),{clearedAt:serverTimestamp()}));
   await assertFails(setDoc(doc(bob,'chats/direct/settings/alice'),{clearedAt:serverTimestamp()}));
   await assertFails(getDoc(doc(bob,'chats/direct/settings/alice')));
   await assertSucceeds(setDoc(doc(alice,'player_blocks/alice/users/bob'),{createdAt:serverTimestamp()}));
   const batch=writeBatch(bob);
   batch.set(doc(bob,'chats/direct/messages/blocked-message'),{senderId:'bob',text:'Hello',createdAt:serverTimestamp()});
   batch.update(doc(bob,'chats/direct'),{lastMessageId:'blocked-message',lastMessagePreview:'Hello',lastSenderId:'bob',updatedAt:serverTimestamp()});
   await assertFails(batch.commit());
 }finally{await env.cleanup();}
});