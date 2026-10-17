-- Complete genuine terminal-pose derivatives only; one native salvage owner.
local M=VFS.Include('40k_configs/tactical_marine_remains.lua');local result={}
for actor,row in pairs(M.Actors)do
 if VFS.FileExists('objects3d/'..row.feature..'.glb')and VFS.FileExists('unittextures/'..row.feature..'_tex1.png')and VFS.FileExists('unittextures/'..row.feature..'_tex2.png')then result[row.feature]=M.Definition(nil,actor)end
end
-- This derivative deliberately reuses the genuine live flamer atlas URIs.
local flamer=VFS.Include('40k_configs/guard_squad_flamer_integration.lua')
local flamerOptions=Spring.GetModOptions()or{}
if flamer.Enabled(flamerOptions)then
 assert(VFS.Include('40k_configs/four_faction_playtest.lua').Enabled(flamerOptions),'Guard flamer remains require ordinary source progression')
 assert(not VFS.Include('40k_configs/scale_pilot.lua').Enabled(flamerOptions),'Unpaired Guard flamer scale085 candidate refused')
 for _,path in ipairs({'objects3d/40k_guardsman_flamer_corpse.glb','unittextures/guardsman_flamer_tex1.png','unittextures/guardsman_flamer_tex2.png'})do assert(VFS.FileExists(path),'Missing genuine flamer remains closure '..path)end
 local recipe=VFS.Include('40k_configs/guard_flamer_remains_recipe.lua')
 result[recipe.Feature]=assert(recipe.Register(M,true))
end
local nobOptions=Spring.GetModOptions()or{}
if VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(nobOptions.prototype_nob_remains_pilot)then
 assert(VFS.Include('40k_configs/four_faction_playtest.lua').Enabled(nobOptions),'Nob remains require ordinary source progression')
 assert(not VFS.Include('40k_configs/scale_pilot.lua').Enabled(nobOptions),'Unpaired Nob remains scale085 candidate refused')
 local recipe=VFS.Include('40k_configs/nob_remains_recipe.lua')
 result[recipe.Feature]=assert(recipe.Register(M,true))
end
local necronOptions=Spring.GetModOptions()or{}
local necronRecipe=VFS.Include('40k_configs/necron_remains_recipe.lua')
for key,definition in pairs(necronRecipe.Register(M,necronOptions,VFS))do
 assert(not result[key],'Duplicate Necron remains FeatureDef')
 result[key]=definition
end
local kasrkin=VFS.Include('40k_configs/kasrkin_remains_recipe.lua')
for key,definition in pairs(kasrkin.Register(M,Spring.GetModOptions()or{},VFS))do
 assert(not result[key],'Duplicate Kasrkin remains FeatureDef');result[key]=definition
end
local ogrynPilot=VFS.Include('40k_configs/ogryn_remains_pilot.lua');local ogrynOptions=Spring.GetModOptions()or{}
if ogrynPilot.Enabled(ogrynOptions)then
 assert(not result[ogrynPilot.Feature],'Duplicate Ogryn remains FeatureDef')
 result[ogrynPilot.Feature]=assert(ogrynPilot.Register(M,ogrynOptions,VFS))
end
local burnaPilot=VFS.Include('40k_configs/burna_remains_pilot.lua');local burnaOptions=Spring.GetModOptions()or{}
if burnaPilot.Enabled(burnaOptions)then
 assert(not result[burnaPilot.Feature],'Duplicate Burna remains FeatureDef')
 result[burnaPilot.Feature]=assert(burnaPilot.Register(M,burnaOptions,VFS))
end
local sluggaPilot=VFS.Include('40k_configs/slugga_remains_pilot.lua');local sluggaOptions=Spring.GetModOptions()or{}
if sluggaPilot.Enabled(sluggaOptions)then
 assert(not result[sluggaPilot.Feature],'Duplicate Slugga remains FeatureDef')
 result[sluggaPilot.Feature]=assert(sluggaPilot.Register(M,sluggaOptions,VFS))
end
local scalePilot=VFS.Include('40k_configs/scale_pilot.lua')
local options=Spring.GetModOptions()
if VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(options.prototype_heavy_corpse_contact_pilot)then
 assert(not scalePilot.Enabled(options),'Contact candidate needs a freshly derived paired-scale corpse before combination')
 local key='40k_heavy_marine_corpse_solidcontact'
 for _,path in ipairs({'objects3d/'..key..'.glb','unittextures/'..key..'_tex1.png','unittextures/'..key..'_tex2.png'})do assert(VFS.FileExists(path),'Missing solid-contact candidate '..path)end
 result[M.Actors.imp_devastator.feature]=M.Definition(key..'.glb','imp_devastator')
end
local terminatorPair=VFS.Include('40k_configs/terminator_scale_pair.lua')
if terminatorPair.Enabled(options)then result[terminatorPair.Feature]=assert(terminatorPair.RegisterRemains(M,options,VFS))end
local scoutPilot=VFS.Include('40k_configs/scout_remains_pilot.lua')
if scoutPilot.Enabled(options)then
 assert(not result[scoutPilot.Feature],'Duplicate Scout remains FeatureDef')
 result[scoutPilot.Feature]=assert(scoutPilot.Register(M,options,VFS))
end
scalePilot.ApplyFeatures(result,options,VFS,{bank='scale_animation_bank_v1',features=1,effects=1})
return result
