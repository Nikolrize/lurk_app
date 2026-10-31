import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, getDoc, writeBatch, serverTimestamp } from 'firebase/firestore';

test('host edits and departures preserve ownership and atomic membership counts', async () => {
 const env = await initializeTestEnvironment({projectId:'demo-lurk-lifecycle',firestore:{host:'127.0.0.1',port:8080,
  rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}});
 try {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async c => {
   const db=c.firestore();
   await setDoc(doc(db,'party_host_slots/alice'),{activeCount:2,lastPartyId:'squad',updatedAt:new Date()});
   await setDoc(doc(db,'parties/squad'),{title:'Squad',hostId:'alice',gameId:'valorant',region:'asia',mode:'competitive',visibility:'private',maxPlayers:5,memberCount:2,minRank:0,maxRank:8,playstyles:['chill'],communication:'mic_required',minimumRating:0,description:'',status:'open',createdAt:new Date(),updatedAt:new Date(),startedAt:null,completedAt:null});
   const original=(await getDoc(doc(db,'parties/squad'))).data();
   await setDoc(doc(db,'parties/legacy'),{...original,memberCount:1});
   await setDoc(doc(db,'parties/legacy/members/alice'),{role:'host',joinedAt:new Date(),leftAt:null});
   for(const [uid,role] of [['alice','host'],['bob','member']]) await setDoc(doc(db,'parties/squad/members/'+uid),{role,joinedAt:new Date(),leftAt:null});
  });
  const alice=env.authenticatedContext('alice').firestore();
  const bob=env.authenticatedContext('bob').firestore();
  const eve=env.authenticatedContext('eve').firestore();
  const party=db=>doc(db,'parties/squad');
  await assertSucceeds(getDoc(party(bob)));
  await assertFails(getDoc(party(eve)));
  await assertSucceeds(updateDoc(party(alice),{title:'Updated squad',maxPlayers:2,description:'Ready!',updatedAt:serverTimestamp()}));
  for(const patch of [{title:''},{maxPlayers:1},{memberCount:1},{hostId:'bob'},{createdAt:serverTimestamp()},{gameId:'fortnite'},{status:'closed'}]) {
   await assertFails(updateDoc(party(alice),{...patch,updatedAt:serverTimestamp()}));
  }
  await assertFails(updateDoc(party(bob),{title:'Hijacked',updatedAt:serverTimestamp()}));
  const leave=(db,uid,host=false)=>{
   const batch=writeBatch(db);
   batch.update(party(db),{memberCount:host?0:1,...(host?{status:'closed'}:{}),updatedAt:serverTimestamp()});
   batch.update(doc(db,'parties/squad/members/'+uid),{leftAt:serverTimestamp()});
   if(host) batch.set(doc(db,'party_host_slots/'+uid),{activeCount:1,lastPartyId:'squad',updatedAt:serverTimestamp()});
   return batch.commit();
  };
  await assertFails(updateDoc(doc(bob,'parties/squad/members/bob'),{leftAt:serverTimestamp()}));
  await assertFails(updateDoc(party(bob),{memberCount:1,updatedAt:serverTimestamp()}));
  await assertFails(leave(eve,'bob'));
  await assertSucceeds(leave(bob,'bob'));
  await assertFails(leave(bob,'bob'));
  await assertFails(getDoc(party(bob)));
  await assertSucceeds(leave(alice,'alice',true));
  const closed=await assertSucceeds(getDoc(party(alice)));
  assert.equal(closed.data().status,'closed');
  assert.equal(closed.data().memberCount,0);
  await assertFails(updateDoc(party(alice),{title:'Reopened',updatedAt:serverTimestamp()}));
  await assertFails(leave(alice,'alice',true));
  const createNext=()=>{
    const batch=writeBatch(alice);
    batch.set(doc(alice,'parties/next'),{...closed.data(),status:'open',memberCount:1,createdAt:serverTimestamp(),updatedAt:serverTimestamp()});
    batch.set(doc(alice,'parties/next/members/alice'),{role:'host',joinedAt:serverTimestamp(),leftAt:null});
    batch.set(doc(alice,'party_host_slots/alice'),{activeCount:1,lastPartyId:'next',updatedAt:serverTimestamp()});
    return batch.commit();
  };
  // A legacy host with two sessions must end both before creating another.
  await assertFails(createNext());
  const endLegacy=writeBatch(alice);
  endLegacy.update(doc(alice,'parties/legacy'),{status:'closed',memberCount:0,updatedAt:serverTimestamp()});
  endLegacy.update(doc(alice,'parties/legacy/members/alice'),{leftAt:serverTimestamp()});
  endLegacy.set(doc(alice,'party_host_slots/alice'),{activeCount:0,lastPartyId:'legacy',updatedAt:serverTimestamp()});
  await assertSucceeds(endLegacy.commit());
  await assertSucceeds(createNext());
 } finally { await env.cleanup(); }
});
