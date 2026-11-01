import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,setDoc,getDoc,writeBatch,serverTimestamp,Timestamp,runTransaction} from 'firebase/firestore';
const t = ms => Timestamp.fromMillis(ms);
test('rank ranges enforce boundaries and full range permits unranked players',async()=>{
 const env=await initializeTestEnvironment({projectId:'demo-lurk-match-ranks',firestore:{host:'127.0.0.1',port:8080,rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}});
 try {
  await env.withSecurityRulesDisabled(async c=>{
   const db=c.firestore();
   for(const [uid,rank] of [['low','bronze'],['edge','silver'],['high','diamond'],['unranked',null]]) {
    await setDoc(doc(db,'players/'+uid),{username:uid,region:'Asia',gameRanks:rank?{valorant:rank}:{}});
    await setDoc(doc(db,'parties/'+uid),{hostId:'host',gameId:'valorant',minRank:uid==='unranked'?0:2,maxRank:uid==='unranked'?8:4,region:'asia',minimumRating:0,status:'open',visibility:'public',memberCount:1,maxPlayers:5});
   }
  });
  const join=(uid)=>{
   const db=env.authenticatedContext(uid).firestore(),b=writeBatch(db);
   b.update(doc(db,'parties/'+uid),{memberCount:2,updatedAt:serverTimestamp()});
   b.set(doc(db,'parties/'+uid+'/members/'+uid),{role:'member',joinedAt:serverTimestamp(),leftAt:null});
   b.set(doc(db,'party_memberships/'+uid),{partyId:uid,updatedAt:serverTimestamp()});
   return b.commit();
  };
  await assertFails(join('low')); await assertFails(join('high'));
  await assertSucceeds(join('edge')); await assertSucceeds(join('unranked'));
 }finally{await env.cleanup();}
});
test('rejoin archives only the real completed visit and keeps previous rating overlap valid',async()=>{
 const env=await initializeTestEnvironment({projectId:'demo-lurk-match-visits',firestore:{host:'127.0.0.1',port:8080,rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}});
 try {
  await env.withSecurityRulesDisabled(async c=>{
   const db=c.firestore();
   for(const uid of ['alice','bob'])await setDoc(doc(db,'players/'+uid),{username:uid,region:'Asia'});
   await setDoc(doc(db,'parties/p'),{hostId:'host',gameId:'valorant',region:'asia',minimumRating:0,status:'open',visibility:'public',memberCount:1,maxPlayers:5});
   await setDoc(doc(db,'parties/p/members/alice'),{role:'member',joinedAt:t(1000),leftAt:t(2000)});
   await setDoc(doc(db,'parties/p/members/bob'),{role:'member',joinedAt:t(1500),leftAt:t(1800)});
   await setDoc(doc(db,'players/alice/party_history/p'),{joinedAt:t(1000)});
  });
  const db=env.authenticatedContext('alice').firestore();
  const archive={uid:'alice',joinedAt:t(1000),leftAt:t(2000)};
  const rejoin=(visit)=>{
   const b=writeBatch(db);
   b.set(doc(db,'parties/p/visits/alice_1000'),visit);
   b.set(doc(db,'parties/p/members/alice'),{role:'member',joinedAt:serverTimestamp(),leftAt:null});
   b.update(doc(db,'parties/p'),{memberCount:2,updatedAt:serverTimestamp()});
   b.set(doc(db,'party_memberships/alice'),{partyId:'p',updatedAt:serverTimestamp()});
   return b.commit();
  };
  await assertFails(rejoin({...archive,joinedAt:t(500)}));
  await assertSucceeds(rejoin(archive));
  assert.equal((await getDoc(doc(db,'players/alice/party_history/p'))).data().joinedAt.toMillis(),1000);
  await assertFails(setDoc(doc(db,'parties/p/visits/alice_1000'),archive));
  const leave=writeBatch(db);
  leave.update(doc(db,'parties/p/members/alice'),{leftAt:serverTimestamp()});
  leave.update(doc(db,'parties/p'),{memberCount:1,updatedAt:serverTimestamp()});
  leave.delete(doc(db,'party_memberships/alice'));
  await assertSucceeds(leave.commit());
  const submit=(proof)=>runTransaction(db,async tx=>{
   const summary=doc(db,'player_rating_summaries/bob');
   const before=(await tx.get(summary)).data()??{total:0,count:0};
   tx.set(summary,{total:before.total+5,count:before.count+1,lastReviewId:'p_alice',updatedAt:serverTimestamp()});
   tx.set(doc(db,'player_reviews/bob/reviews/p_alice'),{partyId:'p',raterId:'alice',stars:5,tags:[],comment:'',createdAt:serverTimestamp(),...proof});
  });
  await assertFails(submit({}));
  await assertFails(submit({ownVisitId:'alice_1000',peerVisitId:'alice_1000'}));
  await assertSucceeds(submit({ownVisitId:'alice_1000'}));
 }finally{await env.cleanup();}
});
