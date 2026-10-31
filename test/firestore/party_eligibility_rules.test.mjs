import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,setDoc,getDoc,writeBatch,serverTimestamp} from 'firebase/firestore';
test('joining enforces real review averages, matching regions, capacity and invitation requirements',async()=>{
 const env=await initializeTestEnvironment({projectId:'demo-lurk-eligibility',firestore:{host:'127.0.0.1',port:8080,rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}});
 try {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async c=>{
   const db=c.firestore();
   for(const uid of ['good','low','unrated','europe','exact','race1','race2']){
    await setDoc(doc(db,'players/'+uid),{username:uid,region:uid==='europe'?'Europe':'Asia',rating:5});
    if(uid!=='unrated')await setDoc(doc(db,'player_rating_summaries/'+uid),{total:uid==='low'?7:uid==='exact'?8:9,count:2});
   }
   for(const id of ['public','private','exact','race','unrated','wrongregion','low','norating']){
    await setDoc(doc(db,'parties/'+id),{hostId:'host',region:'asia',minimumRating:id==='norating'?0:4,status:'open',visibility:id==='private'?'private':'public',memberCount:1,maxPlayers:2});
    await setDoc(doc(db,'parties/'+id+'/members/host'),{role:'host',joinedAt:new Date(0),leftAt:null});
   }
   for(const uid of ['good','low','europe'])await setDoc(doc(db,'parties/private/invitations/'+uid),{hostId:'host',createdAt:new Date()});
  });
  const join=(uid,id)=>{
   const db=env.authenticatedContext(uid).firestore(),b=writeBatch(db);
   b.update(doc(db,'parties/'+id),{memberCount:2,updatedAt:serverTimestamp()});
   b.set(doc(db,'parties/'+id+'/members/'+uid),{role:'member',joinedAt:serverTimestamp(),leftAt:null});
   b.set(doc(db,'party_memberships/'+uid),{partyId:id,updatedAt:serverTimestamp()});
   return b.commit();
  };
  await assertFails(join('low','low'));
  await assertFails(join('unrated','unrated')); // players.rating=5 cannot bypass real reviews
  await assertFails(join('europe','wrongregion'));
  await assertFails(join('low','private')); // invitation does not bypass minimum rating
  await assertFails(join('europe','private'));
  await assertSucceeds(join('good','private'));
  await assertSucceeds(join('exact','exact'));
  await assertSucceeds(join('unrated','norating'));
  const attempts=await Promise.allSettled([join('race1','race'),join('race2','race')]);
  assert.equal(attempts.filter(x=>x.status==='fulfilled').length,1);
  const p=await getDoc(doc(env.authenticatedContext('race1').firestore(),'parties/race'));
  assert.equal(p.data().memberCount,2);
  await assertFails(join('good','race'));
 } finally {await env.cleanup();}
});
