-- Exact source CEG closure for the three-family scale pilot, not global FX.
local M={Version=1,SourcePath='effects/40k_expansion_weapon_fx.lua',Keys={
 '40k_dow_bolter_impact','40k_dow_bolter_muzzle',
 '40k_dow_heavy_bolter_impact','40k_dow_heavy_bolter_muzzle',
 '40k_dow_lasgun_impact','40k_dow_lasgun_muzzle',
 '40k_dow_shoota_muzzle','40k_dow_tankcannon_muzzle'}}
local function key(name)return tostring(name):match('^[Cc][Uu][Ss][Tt][Oo][Mm]:(.+)$')or tostring(name)end
function M.New(V,Pilot)
 assert(V and V.Include and Pilot and Pilot.EffectClone,'Real scale/source FX helpers required')
 local source=assert(V.Include(M.SourcePath),'Missing actual authored source CEG dictionary')
 local allowed={};for _,name in ipairs(M.Keys)do assert(source[name],'Missing genuine source CEG '..name);allowed[name]=true end
 if Pilot.Actors.imp_terminator then
  local name='40k_dow_power_fist_impact';local imperial=V.Include('effects/40k_imperial_source_fx.lua')
  source[name]=assert(imperial[name],'Missing genuine power-fist source CEG');allowed[name]=true
 end
 local C={}
 function C.Ready(name)
  local k=key(name);if not allowed[k]then return false end
  local ok,result=pcall(Pilot.EffectClone,source[k]);return ok and type(result)=='table'
 end
 function C.ValidateActors(defs)
  local seen,actors={},{}
  local function mark(name)
   local k=key(name);assert(allowed[k],'Unexpected pilot CEG '..k);assert(C.Ready(k),'Unsupported pilot source dimensions '..k);seen[k]=true
  end
  for _,d in pairs(defs)do
   local actor=(d.customparams or{}).animsource
   if Pilot.Actors[actor]then
    actors[actor]=true
    for _,fx in ipairs((d.sfxtypes or{}).explosiongenerators or{})do mark(fx)end
    for _,w in pairs(d.weapondefs or{})do for _,f in ipairs({'explosiongenerator','cegtag'})do if w[f]and w[f]~=''then mark(w[f])end end end
   end
  end
  for actor in pairs(Pilot.Actors)do assert(actors[actor],'Missing actual scale actor '..actor)end
  for _,name in ipairs(M.Keys)do assert(seen[name],'Current pilot closure no longer references '..name)end
  return true
 end
 function C.Definitions()
  local definitions={};for _,name in ipairs(M.Keys)do assert(C.Ready(name),'Source CEG clone refused '..name);definitions[Pilot.EffectName(name)]=Pilot.EffectClone(source[name])end
  return definitions
 end
 return C
end
return M
