import test from 'node:test';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,setDoc,getDoc,getDocs,collection,writeBatch,serverTimestamp,deleteDoc} from 'firebase/firestore';

test('chat invitations grant private access only to recipients and require valid host/message',async()=>{
 const env=await initializeTestEnvironment({projectId:'demo-lurk-invitations',firestore:{host:'127.0.0.1',port:8080,rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}});
 try{
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async c=>{
   const db=c.firestore();
   for(const uid of ['alice','bob','eve']) await setDoc(doc(db,'players/'+uid),{username:uid});
   await setDoc(doc(db,'chats/direct'),{type:'direct',userIds:['alice','bob'],createdAt:new Date(),updatedAt:new Date(),lastMessageId:'',lastMessagePreview:'',lastSenderId:''});
   for(const [id,visibility,status,count] of [['private','private','open',1],['public','public','open',1],['full','private','open',5],['closed','private','closed',0],['member','private','open',2]]) {
    await setDoc(doc(db,'parties/'+id),{hostId:'alice',visibility,status,memberCount:count,maxPlayers:5});
   }
   await setDoc(doc(db,'parties/member/members/bob'),{role:'member',joinedAt:new Date(),leftAt:null});
  });
  const alice=env.authenticatedContext('alice').firestore();
  const bob=env.authenticatedContext('bob').firestore();
  const eve=env.authenticatedContext('eve').firestore();
  const guest=env.unauthenticatedContext().firestore();
  let next=0;
  const send=(db,partyId,recipient='bob',host='alice')=>{
   const id='invite-'+next++;
   const batch=writeBatch(db);
   batch.set(doc(db,'chats/direct/messages/'+id),{senderId:host,text:'Party invitation',type:'party_invite',partyId,createdAt:serverTimestamp()});
   batch.update(doc(db,'chats/direct'),{lastMessageId:id,lastMessagePreview:'Party invitation',lastSenderId:host,updatedAt:serverTimestamp()});
   batch.set(doc(db,'parties/'+partyId+'/invitations/'+recipient),{hostId:host,chatId:'direct',messageId:id,createdAt:serverTimestamp()});
   return batch.commit();
  };
  await assertFails(getDoc(doc(bob,'parties/private')));
  await assertFails(send(bob,'private','alice','bob'));
  await assertFails(send(alice,'private','eve'));
  await assertFails(send(guest,'private'));
  await assertFails(setDoc(doc(alice,'parties/private/invitations/bob'),{hostId:'alice',chatId:'direct',messageId:'missing',createdAt:serverTimestamp()}));
  await assertFails(send(alice,'full'));
  await assertFails(send(alice,'closed'));
  await assertFails(send(alice,'member'));
  await assertSucceeds(send(alice,'private'));
  await assertSucceeds(getDoc(doc(bob,'parties/private')));
  await assertSucceeds(getDoc(doc(bob,'parties/private/invitations/bob')));
  await assertSucceeds(getDocs(collection(bob,'parties/private/members')));
  await assertFails(getDocs(collection(eve,'parties/private/members')));
  await assertFails(getDoc(doc(eve,'parties/private')));
  await assertFails(getDoc(doc(eve,'parties/private/invitations/bob')));
  await assertFails(getDoc(doc(guest,'parties/private')));
  await assertSucceeds(send(alice,'private'));
  await assertSucceeds(send(alice,'public'));
  await assertSucceeds(setDoc(doc(alice,'player_blocks/alice/users/bob'),{createdAt:serverTimestamp()}));
  await assertFails(send(alice,'private'));
  await assertSucceeds(deleteDoc(doc(alice,'player_blocks/alice/users/bob')));
  // Accept the actual private invitation sent through the chat batch above.
  const accept=writeBatch(bob);
  accept.set(doc(bob,'parties/private/members/bob'),{role:'member',joinedAt:serverTimestamp(),leftAt:null});
  accept.update(doc(bob,'parties/private'),{memberCount:2,updatedAt:serverTimestamp()});
  accept.set(doc(bob,'party_memberships/bob'),{partyId:'private',updatedAt:serverTimestamp()});
  await assertSucceeds(accept.commit());
  await assertSucceeds(getDoc(doc(bob,'parties/private/members/bob')));
  await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'parties/private'),{status:'closed'},{merge:true}));
  await assertSucceeds(getDoc(doc(bob,'parties/private')));
 }finally{await env.cleanup();}
});
