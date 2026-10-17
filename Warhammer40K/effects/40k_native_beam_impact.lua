-- Reuse stock BAR laser-hit geometry/timing; tint only the luminous colour maps
-- to each existing beam. No new bitmap, damage or global colour policy.
local native=VFS.Include('effects/laserhit.lua')
local function clone(v)
 if type(v)~='table'then return v end
 local out={};for k,x in pairs(v)do out[k]=clone(x)end;return out
end
local function tint(colormap,r,g,b)
 local values={};for n in colormap:gmatch('[%d%.%-]+')do values[#values+1]=tonumber(n)end
 assert(#values>0 and #values%4==0,'Native literal laser-hit colour map required')
 for i=1,#values,4 do
  local level=math.max(values[i],values[i+1],values[i+2])
  values[i],values[i+1],values[i+2]=level*r,level*g,level*b
 end
 for i,v in ipairs(values)do values[i]=string.format('%.8g',v)end
 return table.concat(values,' ')
end
local function impact(r,g,b)
 local effect=clone(assert(native['laserhit-medium']))
 for _,name in ipairs({'heatedgroundflash','sparks','hit'})do
  local layer=effect[name]
  if layer and layer.properties and layer.properties.colormap then layer.properties.colormap=tint(layer.properties.colormap,r,g,b)end
 end
 return effect
end
return{['40k_native_beam_blue_impact']=impact(.45,.85,1),['40k_native_beam_green_impact']=impact(.5,1,.2),['40k_native_beam_orange_impact']=impact(1,.45,.1)}
