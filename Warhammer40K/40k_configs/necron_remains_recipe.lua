-- Default-off closure over existing genuine own-death static Necron derivatives.
-- No new model, death owner, resource payout or resurrection/harvest path.
local M={DefaultEnabled=false}
local function on(v)return v==true or v==1 or v=='1'end
local rows={
 {option='prototype_necron_immortal_squad',actor='nec_immortal',feature='40k_immortal_corpse',body='nec_immortal_body',name='Immortal'},
 {option='prototype_necron_flayed_squad',actor='nec_flayed',feature='40k_flayed_one_corpse',body='nec_flayed_body',name='Flayed One'}}
function M.Register(owner,options,V)
 options=options or{};local result={}
 local terminal=on(options.prototype_flayed_terminal_remains_pilot)
 if terminal then
  assert(on(options.prototype_necron_remains_pilot)and on(options.prototype_necron_flayed_squad),'Flayed terminal pilot requires existing Necron remains and paid Flayed squad')
 end
 if not on(options.prototype_necron_remains_pilot)then return result end
 assert(options.prototype_diagnostic=='normal'and on(options.prototype_source_progression),'Necron remains require ordinary source progression')
 assert(not on(options.prototype_scale085_pilot),'Necron remains have no paired scale085 derivative')
 for _,key in ipairs({'prototype_spyder_harvest_review','prototype_corpse_reclaim_review','prototype_spyder_harvest_fixture'})do assert(not on(options[key]),'Competing Necron corpse review refused')end
 assert(owner.Fraction==.25 and type(owner.Definition)=='function','Existing sole native remains owner required')
 local selected={}
 -- Preflight every selected body before changing the existing actor table.
 for _,row in ipairs(rows)do if on(options[row.option])then
  if terminal and row.actor=='nec_flayed'then
   local proof=V.Include('40k_configs/flayed_terminal_asset_closure.lua')
   assert(proof.status=='STATIC_SOURCE_DEATH_VERIFIED'and proof.actor=='nec_flayed'and proof.feature==row.feature and proof.body=='40k_flayed_terminal129_corpse'and proof.textureBody=='40k_flayed_one_corpse'and proof.clip=='die_normal_1'and proof.terminalFrame==129 and proof.sourceOwnedStandalone==true and proof.donor==false and proof.evaluatedRigAndBake==true and proof.staticUnskinned==true and proof.groundContactVerified==true and proof.heightBoundVerified==true and proof.materialsMatchLive==true and proof.nativeAccepted==false and proof.renderAccepted==false and proof.classification=='GENUINE_FLAYED_TERMINAL129_DEFORMED_SOURCE_DEATH','Closed genuine Flayed terminal129 proof required')
   row={option=row.option,actor=row.actor,feature=row.feature,body=proof.body,textureBody=proof.textureBody,name=row.name}
  end
  for _,path in ipairs({'objects3d/'..row.body..'.glb','unittextures/'..(row.textureBody or row.body)..'_tex1.png','unittextures/'..(row.textureBody or row.body)..'_tex2.png'})do assert(V.FileExists(path),'Missing genuine Necron terminal body '..path)end
  local prior=owner.Actors[row.actor]
  assert(not prior or(prior.feature==row.feature and prior.name==row.name),'Conflicting Necron remains actor')
  selected[#selected+1]=row
 end end
 for _,row in ipairs(selected)do
  owner.Actors[row.actor]={feature=row.feature,name=row.name}
  result[row.feature]=owner.Definition(row.body..'.glb',row.actor)
 end
 return result
end
return M
