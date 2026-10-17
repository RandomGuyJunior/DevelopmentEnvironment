-- Bounded native-corpse pilot. No custom feature creation or resource owner.
local M={Fraction=.25,Option='prototype_russ_wreck_pilot',Rows={
 [1]={feature='40k_leman_russ_wreck',live='leman_russ.glb',model='40k_leman_russ_wreck.glb',
  bounds={-20.942659345309394,0,-32.39014043779653,21.34188795600963,33.44110352885433,24.90063705151283}},
 [.85]={feature='40k_leman_russ_wreck_scale085',live='leman_russ_scale085.glb',model='40k_leman_russ_wreck_scale085.glb',
  bounds={-17.801260443512984,0,-27.53161937212705,18.140604762608184,28.42493799952618,21.165541493785906}}}}
function M.Enabled(opts)local v=opts and opts[M.Option];return v==true or v==1 or v=='1'end
local function positive(v)return type(v)=='number'and v>0 and v<math.huge end
function M.Definition(factor)
 local r=assert(M.Rows[factor],'Unsupported paired Russ scale');local b=r.bounds
 return{name='Leman Russ wreck',description='Reclaimable terminal death-state Leman Russ adaptation',object=r.model,
  blocking=false,reclaimable=true,autoreclaimable=true,resurrectable=0,indestructible=true,flammable=false,
  damage=750,health=750,metal=0,energy=0,reclaimtime=1,featuredead='',footprintx=3,footprintz=4,
  collisionvolumetype='Box',collisionvolumescales=string.format('%.9f %.9f %.9f',b[4]-b[1],b[5]-b[2],b[6]-b[3]),
  -- Native GLTF CalcDrawMidPos is already bounds centre, not ground origin.
  collisionvolumeoffsets='0 0 0',
  customparams={prototype40k_russ_native_wreck=1,parent_actor='leman_russ',scale_factor=factor,
   source_pose='die_1_terminal_persistent_adaptation',source_receipt='russ-wreck-r1'}}
end
function M.Definitions()
 local out={};for f,r in pairs(M.Rows)do out[r.feature]=M.Definition(f)end;return out
end
-- Root invokes AFTER ordinary pricing and coherent live scale selection.
-- ready(model) must verify the owned private closure; file presence is not acceptance.
function M.ApplyUnits(defs,opts,ready,factor)
 if not M.Enabled(opts)then return false,'disabled'end
 local r=M.Rows[factor];local d=defs.imp_russ;local cp=d and d.customparams
 if not r or not cp or cp.animsource~='leman_russ' or d.script~='40k_tank.lua'
  or d.objectname~=r.live or not positive(d.metalcost)or not positive(d.buildtime)
  or (d.corpse and d.corpse~='')or (d.wreckname and d.wreckname~='')
  or (d.featuredefs and next(d.featuredefs))or not ready or not ready(r.model)then return false,'incomplete_or_conflicting'end
 d.corpse=r.feature;cp.prototype40k_russ_native_wreck=1
 cp.prototype40k_russ_wreck_scale=factor
 return true,r.feature
end
-- Separate feature parser root hook, given the SAME final authored UnitDefs.
-- Native Feature.cpp copies descriptor cost ONCE; it does not infer unit price.
function M.ApplyFeatures(features,defs)
 local d=defs.imp_russ;local cp=d and d.customparams
 if not cp or cp.prototype40k_russ_native_wreck~=1 then return false end
 local r=M.Rows[cp.prototype40k_russ_wreck_scale];local f=r and features[r.feature]
 assert(r and d.corpse==r.feature and f and f.object==r.model,'Russ native wreck closure mismatch')
 assert(positive(d.metalcost)and positive(d.buildtime),'Invalid final ordinary Russ bill')
 f.metal=d.metalcost*M.Fraction;f.energy=0;f.reclaimtime=d.buildtime*M.Fraction
 return true
end
-- Preferred root hook: economics and local corpse bind share one authored state.
-- Stock featuredefs_post prefixes native_wreck to imp_russ_native_wreck.
function M.AttachLocalFeature(defs,opts,ready,factor)
 local ok,reason=M.ApplyUnits(defs,opts,ready,factor)
 if not ok then return false,reason end
 local row=M.Rows[factor];local features={[row.feature]=M.Definition(factor)}
 assert(M.ApplyFeatures(features,defs),'Russ local feature economics incomplete')
 local d=defs.imp_russ
 d.featuredefs={native_wreck=features[row.feature]};d.corpse='native_wreck'
 return true,'imp_russ_native_wreck'
end
return M
