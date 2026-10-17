-- Genuine copied Relic candidate: source strategic object has no health extension.
local o=Spring.GetModOptions()or{}
if not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(o.prototype_source_progression)then return{}end
local key='40k_relic_objective'
for _,path in ipairs({'objects3d/'..key..'.glb','scripts/generated/'..key..'_anim.lua','unitpics/40k_'..key..'.png'})do if not VFS.FileExists(path)then return{}end end
return{[key]={name='Relic',description='Capturable strategic Relic; capture ownership is separate from Gaia lifetime',objectname=key..'.glb',script='40k_roster.lua',buildpic='40k_'..key..'.png',
 -- Stock orphan-factory guard destroys builderless HP<=1 births. Source has no health_ext;
 -- minimum native compatibility health remains nonmilitary and damage is rejected.
 health=2,metalcost=0,energycost=0,buildtime=1,footprintx=14,footprintz=14,blocking=true,
 -- Native maxHeightDif=40*tan(maxSlope); retain the placement adapter's eight-world-unit limit.
 maxslope=math.atan(8/40)*180/math.pi,maxwaterdepth=0,levelground=false,
 canmove=false,canattack=false,builder=false,capturable=false,reclaimable=false,repairable=false,
 category='OBJECTIVE',collisionvolumetype='CylY',collisionvolumescales='210 74 211',collisionvolumeoffsets='0 36.37 0',
 customparams={prototype40k=1,animsource=key,source_idleclip='idle',rosterrole='strategic_objective',production_role='capturable_relic',
 source_entity='attrib/ebps/environment/gameplay/relic_struct.lua',source_objective_health_adaptation='Nonmilitary source lacks health; exact review gadget refuses damage',
 source_capture_ownership_adaptation='Gaia lifetime; actual completed capture sets persistent gameplay owner; not a military victory survivor',source_world_scale=10,source_art_scale=2}}}
