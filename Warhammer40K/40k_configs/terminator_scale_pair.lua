-- Complete private converted source pair, opt-in only; native/render pending.
local M={Option='prototype_terminator_scale085_pair_pilot',Actor='imp_terminator',Feature='40k_terminator_corpse',Factor=.85}
local function yes(v)return v==true or v==1 or v=='1'end
function M.Enabled(o)return yes((o or{})[M.Option])end
function M.ValidateOptions(o)
 assert(M.Enabled(o)and yes(o.prototype_scale085_pilot)and yes(o.prototype_marine_terminator_squad),'Terminator pair requires explicit full-three squad and global scale pilot')
end
function M.ValidateClosure(o,V)
 M.ValidateOptions(o);assert(V and V.Include and V.FileExists,'Terminator pair source APIs required')
 for _,path in ipairs({'objects3d/imp_terminator_scale085.glb','scripts/40k_anim/imp_terminator_scale085.lua','objects3d/40k_terminator_corpse_scale085.glb',
  'unittextures/40k_terminator_corpse_scale085_tex1.png','unittextures/40k_terminator_corpse_scale085_tex2.png','unittextures/imp_terminator_tex1.png','unittextures/imp_terminator_tex2.png',
  'objects3d/imp_terminator_scale085.glb.lua','objects3d/40k_terminator_corpse_scale085.glb.lua','40k_configs/terminator_scale_pair_facts.lua'})do assert(V.FileExists(path),'Missing closed Terminator pair '..path)end
 local p=V.Include('40k_configs/terminator_scale_pair_facts.lua')
 assert(p.factor==.85 and p.sourceOwnedAction==true and p.donor==false and p.staticUnskinned==true and p.clip=='die_1'and p.terminalFrame==46
  and p.corpseGroundMinY==0 and p.sourceVisibilityParity==false,'Genuine static Terminator terminal source proof required')
 assert(p.modelSha256=='27d7e6b723a8113e31513b9139c523ab1f83e4106a8d710900813907377e2d4e'and p.bankSha256=='ef7747d12b6ab0cb9ce3349fc6e9c384ac9815913c8c54dbd6d6c2201b9fb6f5'
  and p.corpseSha256=='0ff1dccee7368ce48781ce5eddb37c6dea638a922da08da6a9d1fb17ed779e85','Mixed live/bank/corpse provenance')
 local live=V.Include('objects3d/imp_terminator_scale085.glb.lua');local corpse=V.Include('objects3d/40k_terminator_corpse_scale085.glb.lua')
 assert(live.tex1=='imp_terminator_tex1.png'and live.tex2=='imp_terminator_tex2.png'and live.fliptextures==false and live.invertteamcolor==false,'Mixed live pair material')
 assert(corpse.tex1=='40k_terminator_corpse_scale085_tex1.png'and corpse.tex2=='40k_terminator_corpse_scale085_tex2.png'and corpse.fliptextures==false and corpse.invertteamcolor==false,'Mixed corpse pair material')
 return p
end
function M.ConfigureScale(P,o,V)
 if not M.Enabled(o)then return false end
 M.ValidateClosure(o,V);assert(P.Factor==M.Factor and P.Actors,'Actual scale registry required')
 assert(not P.Actors[M.Actor],'Terminator scale registry collision')
 P.Actors[M.Actor]={model='imp_terminator_scale085.glb',bank='imp_terminator_scale085',corpse=M.Feature,corpseModel='40k_terminator_corpse_scale085.glb',
  corpseTextures={'40k_terminator_corpse_scale085_tex1.png','40k_terminator_corpse_scale085_tex2.png'},bankSourceSha256='ff8c2fec175b17a8b17371b4f6ca96860fffa46d65b3865aa8359fd573a3e828'}
 return true
end
function M.RegisterRemains(owner,o,V)
 if not M.Enabled(o)then return nil end
 M.ValidateClosure(o,V);assert(owner.Fraction==.25 and type(owner.Definition)=='function','Existing single entitlement owner required')
 local prior=owner.Actors[M.Actor];assert(not prior or prior.feature==M.Feature,'Terminator corpse owner collision')
 owner.Actors[M.Actor]={feature=M.Feature,name='Terminator'}
 local d=owner.Definition('40k_terminator_corpse_scale085.glb',M.Actor);d.customparams.scale_pilot_factor=M.Factor
 return d -- ROOT MUST bind this explicit returned definition, never inferred baseline model.
end
function M.FinalizeUnits(defs,o,P)
 if not M.Enabled(o)then return false end
 local plans={}
 for _,key in ipairs({'imp_terminator','imp_terminator_member'})do
  local d=assert(defs[key],'Missing full-three Terminator actor');local cp=d.customparams or{}
  assert(d.objectname=='imp_terminator_scale085.glb'and cp.scale_pilot_factor==.85 and cp.scale_animation_bank=='imp_terminator_scale085','Mixed Terminator model/bank')
  -- Native importer-derived collider follows actual .85 model; do not invent
  -- explicit bind-space collision scales/offsets or change SBOT2 navigation.
  assert(d.footprintx==1 and d.footprintz==1 and d.movementclass=='SBOT2'and not d.collisionvolumescales and not d.collisionvolumeoffsets and not d.collisionvolumetype,'Unreviewed Terminator collider envelope')
  assert(not d.corpse or d.corpse=='','Second corpse owner');assert(not d.wreckname or d.wreckname=='','Second wreck owner')
  for _,w in pairs(d.weapondefs or{})do local p=w.customparams or{}
   if p.source_muzzlefx then
    local source='40k_dow_bolter_muzzle';local target=P.EffectName(source)
    assert(p.source_muzzlefx==source or p.source_muzzlefx==target,'Unknown Terminator source muzzle CEG')
    plans[#plans+1]={params=p,target=target}
   end
  end
 end
 assert(defs.imp_terminator.customparams.prototype40k_squad_capacity==3,'Fixed full-three capacity required')
 for _,row in ipairs(plans)do row.params.source_muzzlefx=row.target end
 return true
end
return M
