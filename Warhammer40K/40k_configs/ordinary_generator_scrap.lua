-- One ordinary paid generator, one native salvage feature; opt-in until native review.
local M={Key='imp_generator',Feature='imp_generator_generator_scrap',Fraction=.25}
local function enabled(v)return v==true or v==1 or v=='1'end
local function finite(v)return type(v)=='number'and v==v and v>=0 and v<math.huge end
function M.Enabled(o)
 return o and enabled(o.prototype_generator_scrap_review)and enabled(o.prototype_development_playtest)and enabled(o.prototype_source_progression)
  and(o.prototype_diagnostic==nil or o.prototype_diagnostic=='normal')and not enabled(o.prototype_spyder_harvest_review)
  and not enabled(o.prototype_corpse_reclaim_review)and not enabled(o.prototype_source_paid_match)
  and not(o.prototype_source_acceptance and o.prototype_source_acceptance~='')or false
end
function M.Apply(U,o,V)
 if not M.Enabled(o)then return{enabled=false,applied=false}end
 local d=U[M.Key];local cp=d and d.customparams or{}
 if not d or cp.animsource~='imp_generator'or cp.faction~='Imperial Guard'or d.objectname~='imp_generator.glb'or d.script~='40k_roster.lua'then return{enabled=true,applied=false,reason='generator_identity'}end
 if d.corpse or d.featuredefs then return{enabled=true,applied=false,reason='existing_corpse_binding'}end
 for _,k in ipairs({'metalcost','energycost','buildtime'})do if not finite(d[k])then return{enabled=true,applied=false,reason='invalid_'..k}end end
 if d.buildtime<=0 then return{enabled=true,applied=false,reason='invalid_buildtime'}end
 for _,path in ipairs({'objects3d/twisted_metal.glb','unittextures/twisted_metal_tex1.png','unittextures/twisted_metal_tex2.png'})do
  if not V.FileExists(path)then return{enabled=true,applied=false,reason='missing_'..path}end
 end
 -- Resource values follow the final ordinary definition, never the scenery's
 -- fixed 12-metal price. No manual feature creation or second wreck chain.
 d.corpse='generator_scrap'
 d.featuredefs={generator_scrap={name='Generator machinery scrap',description='Salvageable generator machinery',object='twisted_metal.glb',
  blocking=false,reclaimable=true,autoreclaimable=true,resurrectable=0,indestructible=true,flammable=false,damage=100,health=100,
  metal=d.metalcost*M.Fraction,energy=d.energycost*M.Fraction,reclaimtime=math.max(30,math.min(6000,d.buildtime*M.Fraction)),
  footprintx=4,footprintz=4,featuredead='',customparams={ordinary_generator_scrap=1,source_scenery='art/ebps/environment/urban/dressing/dressing_twistedmetal_01.whm'}}}
 return{enabled=true,applied=true,key=M.Key}
end
function M.New(S,F,fps)
 assert(finite(fps)and fps>0 and fps%1==0)
 local allowed={};for def,d in pairs(F)do
  local cp=d.customParams or{}
  if d.name==M.Feature and tostring(cp.ordinary_generator_scrap)=='1'and d.reclaimable and d.resurrectable==0 then allowed[def]=true end
 end
 local R={rows={},count=0}
 local function owns(id)return allowed[S.GetFeatureDefID(id)]end
 function R.AllowCreation(def)return true end -- native death retains its one entitlement
 function R.Created(id)
  if not owns(id)or R.rows[id]then return end
  local born=S.GetFeatureRulesParam(id,'40k_generator_scrap_born')
  if not finite(born)then born=S.GetGameFrame();S.SetFeatureRulesParam(id,'40k_generator_scrap_born',born,{private=true})end
  R.rows[id]={born=born};R.count=R.count+1
 end
 function R.AllowBuildStep(id,part)
  return not owns(id)or(R.rows[id]~=nil and type(part)=='number'and finite(-part)and part<0)
 end
 function R.Destroyed(id)if R.rows[id]then R.rows[id]=nil;R.count=R.count-1 end end
 function R.Frame(frame)end -- unreclaimed salvage has no lifetime or population cull
 function R.Restore()
  for _,id in ipairs(S.GetAllFeatures()or{})do R.Created(id)end
 end
 return R
end
return M
