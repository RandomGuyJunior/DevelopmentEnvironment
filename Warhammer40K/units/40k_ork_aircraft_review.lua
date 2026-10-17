-- Entirely opt-in; source conversion does not grant normal release/native acceptance.
local o=Spring and Spring.GetModOptions and Spring.GetModOptions()or{}
if tostring(o.prototype_ork_aircraft_review)~='1'or not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(o.prototype_source_progression)or o.prototype_source_acceptance~='orks'then return{}end
if not VFS.FileExists('scripts/generated/ork_aircraft_source_facts.lua')then return{}end
local f=VFS.Include('scripts/generated/ork_aircraft_source_facts.lua');local M=VFS.Include('40k_configs/ork_aircraft_native_definitions.lua');local out={}
for _,key in ipairs({'ork_fighta_bomba','ork_nuke_bomba'})do
 local ready=true
 for _,p in ipairs({'objects3d/'..key..'.glb','scripts/generated/'..key..'_anim.lua','unitpics/40k_'..key..'.png','unittextures/'..key..'_tex1.png','unittextures/'..key..'_tex2.png','scripts/40k_roster.lua','scripts/40k_ork_aircraft_aim.lua'})do if not VFS.FileExists(p)then ready=false end end
 if ready then out[key]=M.Build(key,f[key],f[key].producer_workertime)end
end
return out
