-- Default-off private stage closure; the existing shared owner alone pays remains.
local M={Version=1,DefaultEnabled=false,Actor='imp_kasrkin',Feature='40k_kasrkin_corpse',Option='prototype_guard_kasrkin_remains_pilot'}
local function on(v)return v==true or v==1 or v=='1'end
function M.Enabled(options)return on((options or{})[M.Option])end
local expected={
 {'objects3d/40k_kasrkin_corpse.glb','7153e0876e608b37c3104217496655f5304b553bda838b1fd9fd31a22ef41a46'},
 {'unittextures/40k_kasrkin_corpse_tex1.png','a5b770a1d01ab9bdab843bfa12909b099624e39d7776694a835e1ab267f3b3ae'},
 {'unittextures/40k_kasrkin_corpse_tex2.png','46426fbc1c3e30a953a5fc1c4c013bd470dc77245872416e093c63bd0df82462'}}
function M.Register(owner,options,V)
 options=options or{};if not M.Enabled(options)then return{}end
 assert(on(options.prototype_guard_kasrkin_squad)and on(options.prototype_source_progression)and options.prototype_diagnostic=='normal','Ordinary full5 Kasrkin source route required')
 assert(not on(options.prototype_scale085_pilot),'Unpaired Kasrkin remains scale085 refused')
 assert(type(owner)=='table'and owner.Version==1 and owner.Fraction==.25 and type(owner.Actors)=='table'and type(owner.Definition)=='function','Existing sole native remains owner required')
 assert(type(V)=='table'and type(V.Include)=='function'and type(V.FileExists)=='function','Explicit private asset stage required')
 assert(V.Include('40k_configs/four_faction_playtest.lua').Enabled(options),'Actual ordinary four-faction development route required')
 local f=V.Include('40k_configs/kasrkin_corpse_stage_facts.lua')
 assert(type(f)=='table'and f.schema==1 and f.status=='ACTUAL_CLOSED_SOURCE_EXPORT_PRIVATE_STAGE'and f.actor==M.Actor and f.feature==M.Feature and f.clip=='die_normal_1'and f.terminalFrame==60,'Actual terminal60 stage identity required')
 assert(f.recipeSHA256=='be1ef06e53b91e604a7f7adaeea72239efaca94063a1a98064e801cc40c6a003'and f.completionManifestSHA256=='09e4e7ed816dba8567a36c7a4cd378016722942eab5809c936cd681bdde0e1ee'and f.sourceWHMSHA256=='eff35d403544963de7c00b03e2708ee54f5b7c3e88a717e5a7372290e159a33c','Exact closed source pins required')
 assert(f.successReceiptSHA256=='6cfa5e83dd9f649578ba9dce46166cdab16b2200df20d5d924f7607192ec4955','Exact actual closed completion receipt required')
 assert(f.stageSHA256Verified==true and f.runtimeSHA256Verified==false and f.nativeAccepted==false and f.renderAccepted==false,'Stage closure only; runtime/native claims refused')
 assert(type(f.assets)=='table'and #f.assets==3,'Exact three private stage leaves required')
 local count=0;for k in pairs(f.assets)do assert(type(k)=='number'and k%1==0 and k>=1 and k<=3,'Extra private stage leaf refused');count=count+1 end;assert(count==3,'Exact private stage rows required')
 for i,row in ipairs(expected)do local actual=f.assets[i]
  assert(type(actual)=='table'and actual.path==row[1]and actual.sha256==row[2]and type(actual.bytes)=='number'and actual.bytes>0 and actual.bytes%1==0 and V.FileExists(row[1])==true,'Missing or drifted genuine private asset stage')
 end
 local prior=owner.Actors[M.Actor];assert(not prior or(prior.feature==M.Feature and prior.name=='Kasrkin'),'Conflicting Kasrkin corpse ownership')
 owner.Actors[M.Actor]={feature=M.Feature,name='Kasrkin'}
 return{[M.Feature]=owner.Definition(M.Feature..'.glb',M.Actor)}
end
return M
