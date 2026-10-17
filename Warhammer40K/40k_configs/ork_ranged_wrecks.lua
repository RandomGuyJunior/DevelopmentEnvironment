-- Default-off genuine source-terminal Ork ranged walker native salvage pilot.
-- No runtime owner, custom spawning or cross-parser final-price state.
local M={Option='prototype_ork_ranged_wreck_pilot',Fraction=.25,Rows={
 ork_kan_twin_shoota={model='ork_kan_twin_shoota_wreck.glb',sha256='e7d63c68c3763d27a3a5dc42f9b79ae33bac20f6f4ff9c942f9c55e718a04f6e',bounds={-15.628614632093743,0.0,-39.984508099180886,15.719770008756237,18.653547359795713,-4.335585408321234}},
 ork_kan_twin_kmb={model='ork_kan_twin_kmb_wreck.glb',sha256='80dbe4ac73f3797f3f13d386253a95844aff2f241f86228145950c668129e421',bounds={-15.628614632093743,0.0,-39.984508099180886,15.719770008756237,19.957351512635803,-4.335585408321234}},
 ork_kan_twin_rokkit={model='ork_kan_twin_rokkit_wreck.glb',sha256='e2d8f7fe37294b66a37978dc85e42daea1a151a56a7492398bc7614ddede1944',bounds={-15.628614632093743,0.0,-39.984508099180886,15.719770008756237,16.416079453621933,-4.335585408321234}},
 ork_dread_ranged_fourarm={model='ork_dread_ranged_fourarm_wreck.glb',sha256='861e939043b23b5decf7ad7b439f1cd287c328f7cc3436b87e0059100918c0df',bounds={-28.500836184490655,0.0,-46.863008623138654,19.7541281658188,21.534022016807786,-4.817316978884277}},
}}
M.Keys={'ork_kan_twin_shoota','ork_kan_twin_kmb','ork_kan_twin_rokkit','ork_dread_ranged_fourarm'}
function M.Enabled(opts)local v=opts and opts[M.Option];return v==true or v==1 or v=='1'end
local function positive(v)return type(v)=='number'and v==v and v>0 and v<math.huge end
function M.Definition(key,unit)
 local row=assert(M.Rows[key],'Unsupported ranged wreck actor');local b=row.bounds
 assert(unit and positive(unit.metalcost)and positive(unit.buildtime),'Final ordinary unit bill required')
 return{name=(unit.name or key)..' wreck',description='Source terminal walker salvage',object=row.model,
  blocking=false,reclaimable=true,resurrectable=0,indestructible=true,flammable=false,damage=750,health=750,
  metal=unit.metalcost*M.Fraction,energy=0,reclaimtime=unit.buildtime*M.Fraction,featuredead='',
  footprintx=math.max(1,math.ceil((b[4]-b[1])/16)),footprintz=math.max(1,math.ceil((b[6]-b[3])/16)),
  collisionvolumetype='Box',collisionvolumescales=string.format('%.9f %.9f %.9f',b[4]-b[1],b[5]-b[2],b[6]-b[3]),
  -- Native static GLTF drawMidPos already contains actual bounds centre.
  collisionvolumeoffsets='0 0 0',customparams={prototype40k_ork_ranged_native_wreck=1,
   parent_actor=key,scale_factor=1,source_pose='die_1_terminal_persistent_project_weapon_adaptation',
   source_receipt='ork-ranged-wreck-r1',source_model_sha256=row.sha256}}
end
function M.AttachLocalFeatures(defs,opts,ready)
 if not M.Enabled(opts)then return false,'disabled'end
 local candidates={}
 for _,key in ipairs(M.Keys)do
  local d=defs[key];local row=M.Rows[key];local cp=d and d.customparams
  if not cp or cp.animsource~=key or d.script~='40k_roster.lua'or d.objectname~=key..'.glb'
   or not(cp.prototype40k_ranged_variant==true or cp.prototype40k_ranged_variant==1 or cp.prototype40k_ranged_variant=='1')
   or not positive(d.metalcost)or not positive(d.buildtime)or(cp.scale_pilot_factor and tonumber(cp.scale_pilot_factor)~=1)
   or(d.corpse and d.corpse~='')or(d.wreckname and d.wreckname~='')or(d.featuredefs and next(d.featuredefs))
   or not ready or ready(row.model,row.sha256)~=true then return false,'incomplete_or_conflicting_'..key end
  candidates[key]=M.Definition(key,d)
 end
 for _,key in ipairs(M.Keys)do
  local d=defs[key];d.featuredefs={native_wreck=candidates[key]};d.corpse='native_wreck'
  d.customparams.prototype40k_ork_ranged_native_wreck=1
 end
 return true,'four_atomic_native_local_features'
end
return M
