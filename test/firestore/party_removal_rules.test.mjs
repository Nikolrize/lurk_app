import test from 'node:test';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,setDoc,getDoc,updateDoc,writeBatch,serverTimestamp} from 'firebase/firestore';
test('only host can remove active members atomically; rejoining requires a fresh invite',async()=>{
 const env=await initializeTestEnvironment({projectId:'demo-lurk-removal',firestore:{host:'127.0.0.1',port:8080,rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}});
 try{
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async c=>{
   const db=c.firestore();
      for (const uid of ["alice","bob","eve"]) await setDoc(doc(db, 'players/'+uid), {username:uid,region:'Asia'});
   await setDoc(doc(db,'parties/squad'),{title:'Squad',hostId:'alice',gameId:'valorant',region:'asia',mode:'competitive',visibility:'private',maxPlayers:5,memberCount:3,minRank:null,maxRank:null,playstyles:['chill'],communication:'mic_required',minimumRating:0,description:'',status:'open',createdAt:new Date(),updatedAt:new Date(),startedAt:null,completedAt:null});
   for(const uid of ['alice','bob','eve']){
    await setDoc(doc(db,'parties/squad/members/'+uid),{role:uid==='alice'?'host':'member',joinedAt:new Date(),leftAt:null});
    if(uid!=='alice')await setDoc(doc(db,'party_memberships/'+uid),{partyId:'squad',updatedAt:new Date()});
   }
   await setDoc(doc(db,'parties/squad/invitations/bob'),{hostId:'alice',createdAt:new Date(0),chatId:'direct',messageId:'old'});
  });
  const alice=env.authenticatedContext('alice').firestore(),bob=env.authenticatedContext('bob').firestore(),eve=env.authenticatedContext('eve').firestore();
  const kick=(db,uid,actor='alice',count=2)=>{
   const batch=writeBatch(db);
   batch.update(doc(db,'parties/squad'),{memberCount:count,lastRemovedMemberId:uid,updatedAt:serverTimestamp()});
   batch.update(doc(db,'parties/squad/members/'+uid),{leftAt:serverTimestamp(),removedBy:actor});
   return batch.commit();
  };
  await assertFails(kick(eve,'bob','eve'));
  await assertFails(kick(alice,'alice'));
  await assertFails(kick(alice,'bob','alice',1));
  await assertFails(updateDoc(doc(alice,'parties/squad/members/bob'),{leftAt:serverTimestamp(),removedBy:'alice'}));
  await assertFails(updateDoc(doc(alice,'parties/squad'),{memberCount:2,lastRemovedMemberId:'bob',updatedAt:serverTimestamp()}));
  await assertSucceeds(kick(alice,'bob'));
  const removed=await assertSucceeds(getDoc(doc(bob,'parties/squad/members/bob')));
  if(removed.data().removedBy!=='alice'||!removed.data().leftAt)throw Error('Removal metadata missing');
  await assertFails(kick(alice,'bob','alice',1));
  await assertSucceeds(updateDoc(doc(alice,'parties/squad'),{title:'Still editable',updatedAt:serverTimestamp()}));
  const rejoin=()=>{
   const batch=writeBatch(bob);
   batch.update(doc(bob,'parties/squad'),{memberCount:3,updatedAt:serverTimestamp()});
   batch.set(doc(bob,'parties/squad/members/bob'),{role:'member',joinedAt:serverTimestamp(),leftAt:null});
   batch.set(doc(bob,'party_memberships/bob'),{partyId:'squad',updatedAt:serverTimestamp()});
   return batch.commit();
  };
  await assertFails(rejoin());
  await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'parties/squad/invitations/bob'),{hostId:'alice',createdAt:serverTimestamp(),chatId:'direct',messageId:'fresh'}));
  await assertSucceeds(rejoin());
  await assertFails(updateDoc(doc(eve,'parties/squad/members/bob'),{removedBy:'eve'}));
 }finally{await env.cleanup();}
});
