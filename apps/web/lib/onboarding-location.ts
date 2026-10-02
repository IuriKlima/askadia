import type {FactInput,PlaceOption,ProfileFacts,ProfileKey} from '@askadia/contracts';
export function confirmedLocationAnswers(place:PlaceOption,facts:ProfileFacts,manualCity=''):Partial<Record<ProfileKey,FactInput>>{
 const city=place.city||manualCity.trim()||facts.city?.value;
 if(!city)throw new Error('Informe a cidade e o estado para confirmar este local.');
 const answers:Partial<Record<ProfileKey,FactInput>>={placeId:{value:place.id,status:'provided'},city:{value:city.slice(0,100),status:'provided'}};
 if(place.address.trim())answers.address={value:place.address.slice(0,6000),status:'provided'};
 if(place.postalCode&&/^\d{5}-?\d{3}$/.test(place.postalCode)&&place.postalCode.replace('-','')!==facts.postalCode?.value?.replace('-',''))answers.postalCode={value:place.postalCode,status:'provided'};
 const fill=(key:ProfileKey,value:string|null|undefined)=>{if(value?.trim()&&!facts[key]?.value)answers[key]={value:value.slice(0,6000),status:'provided'};};
 fill('businessType',place.details?.businessType?.slice(0,100));fill('hours',place.details?.hours.join('\n'));
 fill('channels',[place.details?.website&&'Site: '+place.details.website,place.details?.phone&&'Telefone comercial: '+place.details.phone].filter(Boolean).join('\n'));
 return answers;
}
