// One-time maintenance using the owner's existing Firebase CLI sign-in.
// Dry-run is the default. No private key is required or printed.
import {createRequire} from 'node:module';
import path from 'node:path';
const require=createRequire(import.meta.url);
const auth=require(path.join(process.env.APPDATA,'npm/node_modules/firebase-tools/lib/auth.js'));
const project='lurk-mae';
const root='https://firestore.googleapis.com/v1/projects/'+project+'/databases/(default)/documents';
const prefix='projects/'+project+'/databases/(default)/documents/';
const apply=process.argv.includes('--apply');
try {
 const token=await auth.getAccessToken(auth.getGlobalDefaultAccount().tokens.refresh_token,[]);
 const headers={Authorization:'Bearer '+token.access_token,'Content-Type':'application/json'};
 async function request(url,body){
  const response=await fetch(url,{method:body===undefined?'GET':'POST',headers,...(body===undefined?{}:{body:JSON.stringify(body)})});
  if(response.status===404)return null;
  if(!response.ok)throw Error('Firestore request failed: '+response.status);
  return response.json();
 }
 const all=await request(root+':runQuery',{structuredQuery:{from:[{collectionId:'reviews',allDescendants:true}]}});
 const targets=new Set(all.filter(x=>x.document?.name.startsWith(prefix+'player_reviews/')).map(x=>x.document.name.slice(prefix.length).split('/')[1]));
 let changed=0,reviewCount=0;
 for(const uid of targets){
  const target=root+'/player_rating_summaries/'+encodeURIComponent(uid);
  const transaction=apply?(await request(root+':beginTransaction',{options:{readWrite:{}}})).transaction:null;
  const rows=await request(root+'/player_reviews/'+encodeURIComponent(uid)+':runQuery',{
   structuredQuery:{from:[{collectionId:'reviews'}]},...(transaction?{transaction}:{})});
  const previous=await request(target+(transaction?'?transaction='+encodeURIComponent(transaction):''));
  const docs=rows.filter(x=>x.document).map(x=>x.document);
  let total=0;
  for(const doc of docs){const stars=Number(doc.fields.stars.integerValue);if(!Number.isInteger(stars)||stars<1||stars>5)throw Error('Invalid historical review');total+=stars;}
  reviewCount+=docs.length;
  const same=Number(previous?.fields?.total?.integerValue)===total&&Number(previous?.fields?.count?.integerValue)===docs.length;
  if(!same){
   changed++;
   if(apply)await request(root+':commit',{transaction,writes:[{
    update:{name:prefix+'player_rating_summaries/'+uid,fields:{total:{integerValue:String(total)},count:{integerValue:String(docs.length)},lastReviewId:{stringValue:docs.at(-1)?.name.split('/').at(-1)??''}}},
    updateTransforms:[{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}],
   }]});
  }else if(transaction){await request(root+':rollback',{transaction});}
 }
 console.log(JSON.stringify({mode:apply?'apply':'dry-run',players:targets.size,reviews:reviewCount,summariesChanged:changed}));
} catch (error) {
 console.error('Rating summary maintenance failed ('+error.message+'). No credentials or review contents were displayed.');
 process.exitCode=1;
}
