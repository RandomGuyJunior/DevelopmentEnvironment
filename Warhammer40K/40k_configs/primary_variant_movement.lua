-- Exact converted candidate footprints; ordinary exposure still needs native acceptance.
local M={Actors={
 ork_looted_rhino={class='40K_RHINO6',footprint=6,source='TANK3',maxslope=24},
 ork_battlewagon_armageddon={class='40K_ARMOURED10',footprint=10,source='TANK3',maxslope=24},
 ork_battlefortress_armageddon={class='40K_ARMOURED10',footprint=10,source='TANK3',maxslope=24},
 ork_great_gargant={class='40K_GREAT_GARGANT25',footprint=25,source='TANK3',maxslope=20},
}}
function M.Ready(key,class,footprint)
 local row=M.Actors[key]
 return row~=nil and row.class==class and row.footprint==footprint
end
local function ready(key,options)
 local review=VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(options.prototype_source_progression)
  and (options.prototype_diagnostic=='roster' or options.prototype_diagnostic=='expandedproduction')
 if not review and not VFS.Include('40k_configs/development_playtest.lua').Allowed(key,options) and not VFS.FileExists('40k_configs/validated/'..key..'.lua')then return false end
 for _,p in ipairs({'objects3d/'..key..'.glb','scripts/generated/'..key..'_anim.lua',
 'unitpics/40k_'..key..'.png','unittextures/'..key..'_tex1.png','unittextures/'..key..'_tex2.png','scripts/40k_roster.lua'})do
  if not VFS.FileExists(p)then return false end
 end
 return true
end
local function copy(value)
 if type(value)~='table'then return value end
 local out={};for k,v in pairs(value)do out[k]=copy(v)end;return out
end
function M.Apply(defs,options)
 options=options or {};local names={}
 local selected={}
 for key,row in pairs(M.Actors)do if ready(key,options)then selected[row.class]=row end end
 for _,d in ipairs(defs)do names[d.name:lower()]=d end
 for _,class in ipairs({'40K_RHINO6','40K_ARMOURED10','40K_GREAT_GARGANT25'})do
  local row=selected[class]
  if row and not names[class:lower()]then
   local original=assert(names[row.source:lower()],'Pinned native TANK3 class missing')
   local d=copy(original);d.name=class;d.footprintx=row.footprint;d.footprintz=row.footprint
   -- Pinned stock loader divides the desired slope by 1.5 before native load.
   d.maxslope=row.maxslope/1.5;d.maxwaterdepth=5
   defs[#defs+1]=d;names[class:lower()]=d
  end
 end
 return defs
end
return M
