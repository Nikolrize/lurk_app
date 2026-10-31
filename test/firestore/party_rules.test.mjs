import { readFileSync } from 'node:fs';
import test from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, query, setDoc, updateDoc, where, writeBatch, serverTimestamp } from 'firebase/firestore';

test('party creation is validated, atomic and private discovery stays protected', async () => {
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
   const bob=env.authenticatedContext('bob').firestore();
   const guest=env.unauthenticatedContext().firestore();
   const discovery=db=>query(collection(db,'parties'),where('visibility','==','public'),where('status','==','open'));
   await assertSucceeds(getDocs(discovery(alice)));
   await assertSucceeds(getDoc(doc(alice,'parties/public')));
   await assertFails(getDocs(discovery(guest)));
   await assertFails(getDocs(collection(alice,'parties')));
   await assertFails(getDoc(doc(bob,'parties/private')));
   await assertFails(getDoc(doc(bob,'parties/ended')));
   await assertSucceeds(getDoc(doc(alice,'parties/private')));
   await assertSucceeds(getDocs(query(collection(alice,'parties'),where('hostId','==','alice'),where('status','==','open'))));
   await assertFails(updateDoc(doc(alice,'parties/public'),{memberCount:99}));
   const party = (overrides={}) => ({title:'Test party',hostId:'alice',gameId:'valorant',
     region:'asia',mode:'competitive',visibility:'public',maxPlayers:5,memberCount:1,
     minRank:2,maxRank:5,playstyles:['chill','fun'],communication:'mic_required',
     minimumRating:4,description:'',status:'open',createdAt:serverTimestamp(),
     updatedAt:serverTimestamp(),startedAt:null,completedAt:null,...overrides});
   const member=()=>({role:'host',joinedAt:serverTimestamp(),leftAt:null});
   const create=(db,id,data=party(),membership=member(),uid='alice')=>{
     const batch=writeBatch(db);
     batch.set(doc(db,`parties/${id}`),data);
     batch.set(doc(db,`parties/${id}/members/${uid}`),membership);
     batch.set(doc(db,`party_host_slots/${uid}`),{activeCount:1,lastPartyId:id,updatedAt:serverTimestamp()});
     return batch.commit();
   };
   const close=async id=>{
     const batch=writeBatch(alice);
     batch.update(doc(alice,'parties/'+id),{status:'closed',memberCount:0,updatedAt:serverTimestamp()});
     batch.update(doc(alice,'parties/'+id+'/members/alice'),{leftAt:serverTimestamp()});
     batch.set(doc(alice,'party_host_slots/alice'),{activeCount:0,lastPartyId:id,updatedAt:serverTimestamp()});
     await assertSucceeds(batch.commit());
   };
   await assertSucceeds(create(alice,'created-public'));
   await assertFails(create(alice,'second-open-party'));
   await assertFails(updateDoc(doc(alice,'party_host_slots/alice'),{activeCount:0,updatedAt:serverTimestamp()}));
   await assertFails(getDoc(doc(bob,'party_host_slots/alice')));
   await close('created-public');
   await assertSucceeds(create(alice,'radiant',party({minRank:8,maxRank:8})));
   await close('radiant');
   await assertSucceeds(create(alice,'mlbb',party({gameId:'mobile_legends',minRank:0,maxRank:9,region:'africa'})));
   await close('mlbb');
   for (const [gameId, topRank] of [
     ['apex_legends',7], ['cs2',17], ['honor_of_kings',9], ['league_of_legends',9],
   ]) {
     await assertSucceeds(create(alice,gameId,party({gameId,minRank:0,maxRank:topRank})));
     await close(gameId);
     await assertFails(create(alice,gameId+'-too-high',party({gameId,minRank:0,maxRank:topRank+1})));
   }
   for (const gameId of ['minecraft','roblox','peak']) {
     await assertSucceeds(create(alice,gameId,party({gameId,minRank:null,maxRank:null})));
     await close(gameId);
     await assertFails(create(alice,gameId+'-rank',party({gameId,minRank:0,maxRank:1})));
   }
   await assertFails(create(alice,'rank-too-high',party({minRank:0,maxRank:9})));
   await assertFails(create(alice,'mlbb-too-high',party({gameId:'mobile_legends',minRank:0,maxRank:10})));
   await assertSucceeds(create(alice,'created-private',party({visibility:'private'})));
   await assertSucceeds(getDoc(doc(alice,'parties/created-private/members/alice')));
   await assertFails(getDoc(doc(bob,'parties/created-private')));
   await assertFails(getDoc(doc(bob,'parties/created-private/members/alice')));
   await close('created-private');
   await assertFails(setDoc(doc(alice,'parties/orphan-party'),party()));
   await assertFails(setDoc(doc(alice,'parties/orphan-member/members/alice'),member()));
   await assertFails(setDoc(doc(alice,'parties/public/members/alice'),member()));
   await assertFails(create(guest,'guest'));
   await assertFails(create(bob,'forged-host'));
   await assertFails(create(alice,'wrong-member',party(),member(),'bob'));
   await assertFails(create(alice,'wrong-role',party(),{...member(),role:'member'}));
   for (const [index, patch] of [
     {title:''}, {title:'   '}, {title:'x'.repeat(61)}, {maxPlayers:1}, {maxPlayers:11},
     {maxPlayers:3.5}, {memberCount:2}, {status:'completed'}, {hostId:'bob'},
     {region:'Malaysia'}, {visibility:'hidden'}, {minimumRating:6}, {playstyles:[]},
     {playstyles:['chill','chill']}, {communication:'anything'}, {minRank:5,maxRank:2},
     {gameId:'fortnite',minRank:1,maxRank:2}, {description:'x'.repeat(501)},
     {extra:'unauthorized'}, {createdAt:new Date(0)},
   ].entries()) await assertFails(create(alice,`invalid-${index}`,party(patch)));
   const concurrent=await Promise.allSettled([create(alice,'race-one'),create(alice,'race-two')]);
   if(concurrent.filter(r=>r.status==='fulfilled').length!==1) throw Error('Concurrent creation must allow exactly one party');
   await env.withSecurityRulesDisabled(async context=>{
     const missing = await getDoc(doc(context.firestore(),'parties/invalid-3'));
     if(missing.exists()) throw Error('Failed batch created an orphan party');
   });
 } finally { await env.cleanup(); }
});
