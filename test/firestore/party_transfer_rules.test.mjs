import test from 'node:test';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,setDoc,getDoc,updateDoc,writeBatch,serverTimestamp} from 'firebase/firestore';
test('host transfer preserves the session and atomically swaps privileges', async()=>{
 const env=await initializeTestEnvironment({projectId:'demo-lurk-transfer',firestore:{host:'127.0.0.1',port:8080,rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}});
 try {
  const seed=async()=>{await env.clearFirestore();await env.withSecurityRulesDisabled(async c=>{
   const db=c.firestore();
   await setDoc(doc(db,'parties/squad'),{title:'Squad',hostId:'alice',gameId:'valorant',region:'asia',mode:'competitive',visibility:'private',maxPlayers:5,memberCount:3,minRank:null,maxRank:null,playstyles:['chill'],communication:'mic_required',minimumRating:0,description:'',status:'open',createdAt:new Date(1000),updatedAt:new Date(1000),startedAt:null,completedAt:null});
   for(const uid of ['alice','bob','eve']) {
    await setDoc(doc(db,'parties/squad/members/'+uid),{role:uid==='alice'?'host':'member',joinedAt:new Date(1000),leftAt:null});
    if(uid!=='alice')await setDoc(doc(db,'party_memberships/'+uid),{partyId:'squad',updatedAt:new Date(1000)});
   }
   await setDoc(doc(db,'party_host_slots/alice'),{activeCount:1,lastPartyId:'squad',updatedAt:new Date(1000)});
  });};
  const alice=env.authenticatedContext('alice').firestore(),bob=env.authenticatedContext('bob').firestore();
  const transfer=(db,from='alice',to='bob',omit='')=>{
   const batch=writeBatch(db);
   batch.update(doc(db,'parties/squad'),{hostId:to,updatedAt:serverTimestamp()});
   if(omit!=='roles') {
    batch.update(doc(db,'parties/squad/members/'+from),{role:'member'});
    batch.update(doc(db,'parties/squad/members/'+to),{role:'host'});
   }
   if(omit!=='slots') {
    batch.set(doc(db,'party_host_slots/'+from),{activeCount:0,lastPartyId:'squad',updatedAt:serverTimestamp()});
    batch.set(doc(db,'party_host_slots/'+to),{activeCount:1,lastPartyId:'squad',updatedAt:serverTimestamp()});
   }
   if(omit!=='pointers') {
    batch.set(doc(db,'party_memberships/'+from),{partyId:'squad',updatedAt:serverTimestamp()});
    batch.delete(doc(db,'party_memberships/'+to));
   }
   return batch.commit();
  };
  await seed();
  await assertFails(transfer(bob));
  await assertFails(transfer(alice,'alice','alice'));
  await assertFails(transfer(alice,'alice','outsider'));
  for(const omit of ['roles','slots','pointers'])await assertFails(transfer(alice,'alice','bob',omit));
  await assertFails(updateDoc(doc(alice,'parties/squad/members/bob'),{role:'host'}));
  await assertSucceeds(transfer(alice));
  const party=(await getDoc(doc(bob,'parties/squad'))).data();
  if(party.hostId!=='bob'||party.status!=='open'||party.memberCount!==3)throw Error('Session changed');
  const old=(await getDoc(doc(alice,'parties/squad/members/alice'))).data();
  if(old.role!=='member'||old.leftAt!==null||old.joinedAt.toMillis()!==1000)throw Error('Participation changed');
  await assertFails(updateDoc(doc(alice,'parties/squad'),{title:'Old host',updatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(bob,'parties/squad'),{title:'New host',updatedAt:serverTimestamp()}));
  await assertSucceeds(transfer(bob,'bob','alice'));
  await seed();
  await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'party_host_slots/bob'),{activeCount:1,lastPartyId:'other',updatedAt:new Date()}));
  await assertFails(transfer(alice));
  await seed();
  await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'parties/squad/members/bob'),{leftAt:new Date()}));
  await assertFails(transfer(alice));
 } finally {await env.cleanup();}
});
