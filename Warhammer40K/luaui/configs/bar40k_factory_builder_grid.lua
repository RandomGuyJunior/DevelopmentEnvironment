-- Native Grid menu logical cell1 is bottom-left in both its3x4 and2x6 layouts.
-- Add layouts only for our own factories; native factions/layouts stay intact.
-- These are references to real existing build options, not padding or units.
return function(configs, unitDefs, unitDefNames)
 local applied=0
 for name,factory in pairs(unitDefNames)do
  local cp=factory.customParams
  if factory.isFactory and name:sub(1,3)=='ork' and cp and cp.faction=='Orks' then
   local constructors={}
   for _,id in ipairs(factory.buildOptions or{})do
    local unit=unitDefs[id]
    if unit and not unit.isFactory and (unit.buildSpeed or 0)>0 and unit.buildOptions and unit.buildOptions[1] then
     constructors[#constructors+1]=unit.name
    end
   end
   if #constructors>0 then
    configs.LabGrids[name]=constructors
    applied=applied+1
   end
  end
 end
 return applied
end
