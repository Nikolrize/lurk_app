import test from 'node:test';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,setDoc,getDoc,writeBatch,deleteDoc,serverTimestamp} from 'firebase/firestore';
test('joined players cannot host until leaving or session end, including simultaneous requests',async()=>{
 const env=await initializeTestEnvironment({projectId:'demo-lurk-exclusive',firestore:{host:'127.0.0.1',port:8080,rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}});
 try{
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async c=>{
   const db=c.firestore();
   await setDoc(doc(db,'parties/squad'),{hostId:'alice',status:'open',visibility:'public',memberCount:3,maxPlayers:5});
   await setDoc(doc(db,'parties/ended'),{hostId:'alice',status:'closed',visibility:'public',memberCount:0,maxPlayers:5});
   for(const [uid,id] of [['bob','squad'],['leaver','squad'],['past','ended']]){
    await setDoc(doc(db,'parties/'+id+'/members/'+uid),{role:'member',joinedAt:new Date(),leftAt:null});
    await setDoc(doc(db,'party_memberships/'+uid),{partyId:id,updatedAt:new Date()});
   }
  });
  const users=new Map();
  const user=uid=>{if(!users.has(uid))users.set(uid,env.authenticatedContext(uid).firestore());return users.get(uid);};
  const create=(uid)=>{
   const db=user(uid),id='new-'+uid,batch=writeBatch(db);
   batch.set(doc(db,'parties/'+id),{title:'New party',hostId:uid,gameId:'valorant',region:'asia',mode:'competitive',visibility:'public',maxPlayers:5,memberCount:1,minRank:null,maxRank:null,playstyles:['chill'],communication:'mic_required',minimumRating:0,description:'',status:'open',createdAt:serverTimestamp(),updatedAt:serverTimestamp(),startedAt:null,completedAt:null});
   batch.set(doc(db,'parties/'+id+'/members/'+uid),{role:'host',joinedAt:serverTimestamp(),leftAt:null});
   batch.set(doc(db,'party_host_slots/'+uid),{activeCount:1,lastPartyId:id,updatedAt:serverTimestamp()});
   return batch.commit();
  };
  await assertFails(create('bob'));
  await assertFails(deleteDoc(doc(user('bob'),'party_memberships/bob')));
  await assertFails(create('leaver'));
  const leave=writeBatch(user('leaver'));
  leave.update(doc(user('leaver'),'parties/squad'),{memberCount:2,updatedAt:serverTimestamp()});
  leave.update(doc(user('leaver'),'parties/squad/members/leaver'),{leftAt:serverTimestamp()});
  leave.delete(doc(user('leaver'),'party_memberships/leaver'));
  await assertSucceeds(leave.commit());
  await assertSucceeds(create('leaver'));
  await assertSucceeds(create('past'));
  const join=(uid)=>{
   const db=user(uid),batch=writeBatch(db);
   batch.update(doc(db,'parties/squad'),{memberCount:3,updatedAt:serverTimestamp()});
   batch.set(doc(db,'parties/squad/members/'+uid),{role:'member',joinedAt:serverTimestamp(),leftAt:null});
   batch.set(doc(db,'party_memberships/'+uid),{partyId:'squad',updatedAt:serverTimestamp()});
   return batch.commit();
  };
  await assertFails(join('leaver'));
  const outcomes=await Promise.allSettled([create('racer'),join('racer')]);
  if(outcomes.filter(r=>r.status==='fulfilled').length!==1)throw Error('Create and join must not both succeed');
 }finally{await env.cleanup();}
});
