import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,setDoc,getDoc,writeBatch,serverTimestamp} from 'firebase/firestore';

test('switching leaves the previous squad atomically and failures preserve membership',async()=>{
 const env=await initializeTestEnvironment({projectId:'demo-lurk-switching',firestore:{host:'127.0.0.1',port:8080,rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}});
 try {
  await env.withSecurityRulesDisabled(async c=>{
   const db=c.firestore();
   for(const [id,visibility,count,max] of [['old','public',2,5],['next','public',1,5],['full','public',2,2],['private','private',1,5]]){
    await setDoc(doc(db,'parties/'+id),{hostId:'host-'+id,status:'open',visibility,memberCount:count,maxPlayers:max});
    await setDoc(doc(db,'parties/'+id+'/members/host-'+id),{role:'host',leftAt:null,joinedAt:new Date()});
   }
   await setDoc(doc(db,'parties/old/members/bob'),{role:'member',leftAt:null,joinedAt:new Date()});
   await setDoc(doc(db,'party_memberships/bob'),{partyId:'old',updatedAt:new Date()});
  });
  const db=env.authenticatedContext('bob').firestore();
  const switchTo=(id,count,leave=true)=>{
   const b=writeBatch(db);
   if(leave){
    b.update(doc(db,'parties/old/members/bob'),{leftAt:serverTimestamp()});
    b.update(doc(db,'parties/old'),{memberCount:1,updatedAt:serverTimestamp()});
   }
   b.set(doc(db,'parties/'+id+'/members/bob'),{role:'member',joinedAt:serverTimestamp(),leftAt:null});
   b.update(doc(db,'parties/'+id),{memberCount:count,updatedAt:serverTimestamp()});
   b.set(doc(db,'party_memberships/bob'),{partyId:id,updatedAt:serverTimestamp()});
   return b.commit();
  };
  await assertFails(switchTo('next',2,false));
  await assertFails(switchTo('full',3));
  await assertFails(switchTo('private',2));
  assert.equal((await getDoc(doc(db,'parties/old/members/bob'))).data().leftAt,null);
  assert.equal((await getDoc(doc(db,'parties/old'))).data().memberCount,2);
  assert.equal((await getDoc(doc(db,'party_memberships/bob'))).data().partyId,'old');
  await assertSucceeds(switchTo('next',2));
  assert.notEqual((await getDoc(doc(db,'parties/old/members/bob'))).data().leftAt,null);
  assert.equal((await getDoc(doc(db,'parties/old'))).data().memberCount,1);
  assert.equal((await getDoc(doc(db,'parties/next'))).data().memberCount,2);
  assert.equal((await getDoc(doc(db,'party_memberships/bob'))).data().partyId,'next');
 } finally {await env.cleanup();}
});