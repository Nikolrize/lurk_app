import test from 'node:test';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,setDoc,getDoc,getDocs,collection,writeBatch,serverTimestamp} from 'firebase/firestore';

test('joins are atomic, bounded, private, idempotent and keep member rosters protected',async()=>{
 const env=await initializeTestEnvironment({projectId:'demo-lurk-joining',firestore:{host:'127.0.0.1',port:8080,rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}});
 try{
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async c=>{
   const db=c.firestore();
      for (const uid of ["alice","bob","eve","r1","r2","blocked","extra"]) await setDoc(doc(db, 'players/'+uid), {username:uid,region:'Asia'});
   for(const [id,visibility,status,size] of [['public','public','open',3],['private','private','open',3],['race','public','open',2],['ended','public','closed',3]]){
    await setDoc(doc(db,'parties/'+id),{region:'asia',hostId:'alice',visibility,status,memberCount:1,maxPlayers:size});
    await setDoc(doc(db,'parties/'+id+'/members/alice'),{role:'host',joinedAt:new Date(),leftAt:null});
   }
   await setDoc(doc(db,'parties/private/invitations/bob'),{hostId:'alice',chatId:'direct',messageId:'invite',createdAt:new Date()});
   await setDoc(doc(db,'player_blocks/alice/users/blocked'),{createdAt:new Date()});
  });
  const user=uid=>env.authenticatedContext(uid).firestore();
  const bob=user('bob'),eve=user('eve');
  const join=(db,uid,id,count=2)=>{
   const batch=writeBatch(db);
   batch.set(doc(db,'parties/'+id+'/members/'+uid),{role:'member',joinedAt:serverTimestamp(),leftAt:null});
   batch.update(doc(db,'parties/'+id),{memberCount:count,updatedAt:serverTimestamp()});
   batch.set(doc(db,'party_memberships/'+uid),{partyId:id,updatedAt:serverTimestamp()});
   return batch.commit();
  };
  const leave=(db,uid,id,count)=>{
   const batch=writeBatch(db);
   batch.update(doc(db,'parties/'+id+'/members/'+uid),{leftAt:serverTimestamp()});
   batch.update(doc(db,'parties/'+id),{memberCount:count,updatedAt:serverTimestamp()});
   batch.delete(doc(db,'party_memberships/'+uid));
   return batch.commit();
  };
  await assertSucceeds(getDoc(doc(bob,'parties/public/members/bob')));
  await assertFails(join(eve,'eve','private'));
  await assertFails(join(user('blocked'),'blocked','public'));
  await assertFails(join(env.unauthenticatedContext().firestore(),'guest','public'));
  await assertFails(join(bob,'eve','public'));
  await assertFails(join(bob,'bob','ended'));
  await assertFails(setDoc(doc(bob,'parties/public/members/bob'),{role:'member',joinedAt:serverTimestamp(),leftAt:null}));
  await assertSucceeds(join(bob,'bob','public'));
  await assertFails(join(bob,'bob','public',3));
  await assertFails(join(bob,'bob','private'));
  await assertSucceeds(getDocs(collection(bob,'parties/public/members')));
  await assertSucceeds(getDocs(collection(user('outsider'),'parties/public/members')));
  await assertFails(getDocs(collection(user('outsider'),'parties/private/members')));
  await assertSucceeds(join(eve,'eve','public',3));
  await assertFails(join(user('extra'),'extra','public',4));
  await assertSucceeds(leave(bob,'bob','public',2));
  await assertSucceeds(join(bob,'bob','public',3));
  await assertSucceeds(leave(bob,'bob','public',2));
  await assertSucceeds(join(bob,'bob','private'));
  await assertSucceeds(getDocs(collection(bob,'parties/private/members')));
  await assertFails(getDoc(doc(eve,'parties/private')));
  await assertFails(setDoc(doc(eve,'party_memberships/bob'),{partyId:'public',updatedAt:serverTimestamp()}));
  const results=await Promise.allSettled([join(user('r1'),'r1','race'),join(user('r2'),'r2','race')]);
  if(results.filter(r=>r.status==='fulfilled').length!==1)throw Error('Exactly one player must win the last slot');
 }finally{await env.cleanup();}
});
