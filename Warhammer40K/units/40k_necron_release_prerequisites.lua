-- Genuine source prerequisite for the tier2 Monolith/Ctan/late-game tree.
-- Source-only pending conversion/native acceptance; never supplies a BAR placeholder.
local key='nec_ancient_core'
local options=Spring and Spring.GetModOptions and Spring.GetModOptions() or {}
local mode=options.prototype_diagnostic
local diagnostic=mode=='roster' or mode=='expandedproduction' or mode=='vital'
if not VFS.FileExists('objects3d/'..key..'.glb') or not VFS.FileExists('scripts/generated/'..key..'_anim.lua')
 or not VFS.FileExists('scripts/40k_roster.lua') or (not diagnostic and not VFS.Include('40k_configs/development_playtest.lua').Allowed(key,options) and not VFS.FileExists('40k_configs/validated/'..key..'.lua')) then return {} end
return {[key]={name='Ancient Summoning Core',description='Source advanced summoning and late-game research support',
 objectname=key..'.glb',script='40k_roster.lua',buildpic='40k_'..key..'.png',
 metalcost=0,energycost=2000,buildtime=19800,health=11000,speed=0,canmove=false,canattack=false,builder=false,
 footprintx=8,footprintz=8,yardmap=string.rep('o',64),maxslope=20,maxwaterdepth=5,sightdistance=450,
 collisionvolumetype='Box',collisionvolumeoffsets='0 0 0',
 customparams={faction='Necrons',prototype40k=1,prototype40k_expansion=1,animsource=key,root_bone='bone_master',rosterrole='support',production_role='research',unitgroup='util',
 source_entity='attrib/ebps/races/necrons/structures/necron_summoning_core_big.lua',source_build_seconds=360,
 source_time_adaptation='19800 native work units equals source360seconds at native Scarab55workpower',balance_status='source_prerequisite_native_pending'}}}
