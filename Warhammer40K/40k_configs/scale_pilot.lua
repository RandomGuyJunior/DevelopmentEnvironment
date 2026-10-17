-- Dedicated default-off source pilot. Root owns all loader/registry hooks.
local M={Version=1,Factor=.85,Option='prototype_scale085_pilot'}
M.Actors={
 space_marine={model='space_marine_scale085.glb',bank='space_marine_scale085',corpse='40k_tactical_marine_corpse',corpseModel='40k_tactical_marine_corpse_scale085.glb'},
 guardsman={model='guardsman_scale085.glb',bank='guardsman_scale085',corpse='40k_guardsman_corpse',corpseModel='40k_guardsman_corpse_scale085.glb'},
 imp_devastator={model='imp_devastator_scale085.glb',bank='imp_devastator_scale085',corpse='40k_heavy_marine_corpse',corpseModel='40k_heavy_marine_corpse_solidcontact_scale085.glb',corpseTextures={'40k_heavy_marine_corpse_solidcontact_scale085_tex1.png','40k_heavy_marine_corpse_solidcontact_scale085_tex2.png'}}}
local function clone(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=clone(x)end;return r end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
function M.Enabled(options)local v=options and options[M.Option];return v==true or v==1 or v=='1'end
local function hooksReady(hooks)
 assert(hooks and hooks.bank=='scale_animation_bank_v1'and hooks.features==1 and hooks.effects==1,'Atomic scale registry/bank hooks missing')
end
local function vector(value)
 if type(value)=='table'then assert(#value==3);local r={};for i,x in ipairs(value)do assert(finite(x));r[i]=x*M.Factor end;return r end
 assert(type(value)=='string','Dimensional vector missing');local r={}
 for w in value:gmatch('[^,%s]+')do local n=tonumber(w);assert(finite(n),'Invalid dimensional vector');r[#r+1]=string.format('%.10g',n*M.Factor)end
 assert(#r==3,'Dimensional vector arity');return table.concat(r,' ')
end
local dimensions={size=true,length=true,width=true,frontoffset=true,particlesize=true,particlesizespread=true,sizegrowth=true,particlespeed=true,particlespeedspread=true}
local function scalar(v)
 if type(v)=='number'then assert(finite(v));return v*M.Factor end
 assert(type(v)=='string'and tonumber(v),'Pilot CEG dimension expression needs explicit reviewed recipe');return tostring(tonumber(v)*M.Factor)
end
function M.EffectName(name)
 local key=tostring(name):match('^[Cc][Uu][Ss][Tt][Oo][Mm]:(.+)$')or tostring(name)
 return key..'_scale085'
end
function M.EffectClone(effect)
 local r=clone(effect)
 for _,part in pairs(r)do if type(part)=='table'and part.properties then
  for key,v in pairs(part.properties)do if dimensions[key:lower()]then part.properties[key]=scalar(v)end end
 end end
 return r
end
function M.ApplyEffects(effects,options,hooks)
 if not M.Enabled(options)then return{applied=0}end;hooksReady(hooks)
 local names=assert(hooks.effectNames,'Preflight actual actor CEG references required');local staged={}
 for _,name in ipairs(names)do
  local key=name:match('^[Cc][Uu][Ss][Tt][Oo][Mm]:(.+)$')or name
  assert(effects[key],'Missing source CEG '..key);local target=M.EffectName(key)
  if effects[target]then assert(hooks.reapply==true,'Scale CEG collision')else staged[target]=M.EffectClone(effects[key])end
 end
 local n=0;for key,row in pairs(staged)do effects[key]=row;n=n+1 end;return{applied=n}
end
function M.ApplyFeatures(features,options,V,hooks)
 if not M.Enabled(options)then return{applied=0}end;hooksReady(hooks);local staged={}
 for source,row in pairs(M.Actors)do
  assert(V.FileExists('objects3d/'..row.corpseModel),'Missing paired scale corpse '..source)
  for _,texture in ipairs(row.corpseTextures or{})do assert(V.FileExists('unittextures/'..texture),'Missing paired corpse texture '..texture)end
  local d=assert(features[row.corpse],'Missing actual corpse definition '..source)
  assert(d.customparams and d.customparams.parent_actor==source,'Wrong source corpse')
  if not d.customparams.scale_pilot_factor then
   local c=clone(d);c.object=row.corpseModel;c.customparams.scale_pilot_factor=M.Factor
   for _,key in ipairs({'collisionvolumescales','collisionvolumeoffsets'})do if c[key]then c[key]=vector(c[key])end end
   staged[row.corpse]=c
  else assert(d.customparams.scale_pilot_factor==M.Factor and d.object==row.corpseModel,'Mixed corpse scale')end
 end
 local n=0;for key,row in pairs(staged)do features[key]=row;n=n+1 end;return{applied=n}
end
function M.ApplyUnits(defs,options,V,tuning,hooks)
 if not M.Enabled(options)then return{applied=0,effects={}}end;hooksReady(hooks)
 local staged,effectSet,seen={},{},{}
 -- Check ALL live/paired/special closure before changing any definition.
 for source,row in pairs(M.Actors)do
  for _,path in ipairs({'objects3d/'..row.model,'objects3d/'..row.corpseModel,'scripts/40k_anim/'..row.bank..'.lua'})do assert(V.FileExists(path),'Missing scale asset '..path)end
  for _,texture in ipairs(row.corpseTextures or{})do assert(V.FileExists('unittextures/'..texture),'Missing paired corpse texture '..texture)end
  local g=assert(tuning[source],'Missing measured source gait '..source)
  assert(finite(g.stride)and g.stride>0 and finite(g.rate)and g.rate>0 and g.contacts>0,'Unmeasured source gait')
 end
 for key,d in pairs(defs)do
  local cp=d.customparams or{};local source=cp.animsource;local row=M.Actors[source]
  if row then
   assert(not d.canfly and not d.floater and not d.yardmap and d.canmove~=false,'Native domain or structure entered infantry pilot')
   assert(d.footprintx==1 and d.footprintz==1 and d.movementclass=='SBOT2','Unexpected navigation envelope; remeasure before pilot')
   seen[source]=true
   if cp.scale_pilot_factor then
    assert(cp.scale_pilot_factor==M.Factor and d.objectname==row.model and cp.scale_animation_bank==row.bank,'Mixed live scale')
   else
    assert(d.objectname==source..'.glb','Non-baseline model alias requires separate provenance')
    local c=clone(d);local q=c.customparams;local g=tuning[source]
    c.objectname=row.model;q.scale_animation_bank=row.bank;q.scale_pilot_factor=M.Factor
    if c.collisionvolumescales then c.collisionvolumescales=vector(c.collisionvolumescales)end
    if c.collisionvolumeoffsets then c.collisionvolumeoffsets=vector(c.collisionvolumeoffsets)end
    c.speed=g.stride*g.rate*M.Factor;q.locomotion_source_stride=g.stride*M.Factor;q.locomotion_playback=g.rate
    q.locomotion_clip=g.clip;q.locomotion_contact_samples=g.contacts;q.locomotion_policy='natural_source_stride_scale085_pilot_v1'
    -- No target has authored numeric muzzle overrides or cargo attachments:
    -- model-contained native QueryWeapon marker coordinates are already scaled.
    assert(not q.muzzle_offset and not q.attachment_offset,'Unknown explicit offset needs recipe')
    for _,fx in ipairs((c.sfxtypes or{}).explosiongenerators or{})do effectSet[fx]=true end
    if c.sfxtypes then for i,fx in ipairs(c.sfxtypes.explosiongenerators or{})do c.sfxtypes.explosiongenerators[i]='custom:'..M.EffectName(fx)end end
    for _,w in pairs(c.weapondefs or{})do
     for _,key2 in ipairs({'explosiongenerator','cegtag'})do if w[key2]and w[key2]~=''then effectSet[w[key2]]=true;w[key2]='custom:'..M.EffectName(w[key2])end end
     for _,key2 in ipairs({'size','thickness'})do if w[key2]then w[key2]=scalar(w[key2])end end
    end
    staged[key]=c
   end
  end
 end
 for source in pairs(M.Actors)do assert(seen[source],'Missing actual live/special actor '..source)end
 local effects={};for name in pairs(effectSet)do effects[#effects+1]=name end;table.sort(effects)
 -- Root supplies actual effect registry validation, before its later registry hook.
 for _,name in ipairs(effects)do assert(hooks.effectReady(name),'Scale CEG preflight refused '..name)end
 local n=0;for key,row in pairs(staged)do defs[key]=row;n=n+1 end
 return{applied=n,effects=effects}
end
local pairOptions=Spring and Spring.GetModOptions and Spring.GetModOptions()or{}
if pairOptions.prototype_terminator_scale085_pair_pilot==true or pairOptions.prototype_terminator_scale085_pair_pilot==1 or pairOptions.prototype_terminator_scale085_pair_pilot=='1'then
 VFS.Include('40k_configs/terminator_scale_pair.lua').ConfigureScale(M,pairOptions,VFS)
end
return M
