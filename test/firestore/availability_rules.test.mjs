import test from 'node:test';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,setDoc,updateDoc,serverTimestamp} from 'firebase/firestore';
test('availability changes preserve owner access and schedule validation',async()=>{
 const env=await initializeTestEnvironment({projectId:'demo-lurk-availability',firestore:{host:'127.0.0.1',port:8080,rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}});
 try{
  await env.clearFirestore();
  const alice=env.authenticatedContext('alice').firestore(),bob=env.authenticatedContext('bob').firestore();
  const profile=doc(alice,'players/alice');
  await assertSucceeds(setDoc(profile,{username:'Alice',bio:'',region:'Asia',createdAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  const availability={availableNow:true,preferredTimes:['Evening','Night'],weeklySchedule:[{weekday:1,startMinute:1080,endMinute:1380},{weekday:7,startMinute:1320,endMinute:120}],timeZone:'Asia/Kuala_Lumpur'};
  await assertSucceeds(updateDoc(profile,{availability,updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(bob,'players/alice'),{availability,updatedAt:serverTimestamp()}));
  for(const patch of [{availableNow:'yes'},{timeZone:'UTC'},{preferredTimes:['Evening','Evening']},{preferredTimes:['Invalid']},{weeklySchedule:[{weekday:8,startMinute:0,endMinute:60}]},{weeklySchedule:[{weekday:1,startMinute:60,endMinute:60}]},{weeklySchedule:[{weekday:1,startMinute:0,endMinute:60},{weekday:1,startMinute:120,endMinute:180}]}]){
   await assertFails(updateDoc(profile,{availability:{...availability,...patch},updatedAt:serverTimestamp()}));
  }
  await assertSucceeds(updateDoc(profile,{bio:'Still editable',updatedAt:serverTimestamp()}));
 }finally{await env.cleanup();}
});
