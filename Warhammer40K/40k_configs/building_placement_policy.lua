-- Apply after final faction/source aliases. Source identity, never faction labels,
-- selects the measured envelope; no geometry/health/collision/egress rewrite.
local M={Bounds=VFS.Include('40k_configs/building_placement_bounds.lua'),Margin=2}
local function size(old,half)
 local n=math.max(old,math.ceil((half+M.Margin)/8)) -- raw square half-width is 8 world units
 if n%2~=old%2 then n=n+1 end -- retain the original centre/grid and geothermal cell
 return n
end
local function expandedYard(yard,ox,oz,nx,nz)
 yard=(yard or ''):gsub('%s','')
 assert(#yard==ox*oz and not yard:find('[^ocwygef]'),'Measured building requires a regular existing yardmap')
 local fill=yard:match('^e+$')and'e'or'o'
 local dx,dz=(nx-ox)/2,(nz-oz)/2;local rows={}
 for z=0,nz-1 do
  local row={}
  for x=0,nx-1 do
   local sx,sz=x-dx,z-dz
   row[#row+1]=(sx>=0 and sx<ox and sz>=0 and sz<oz)and yard:sub(sz*ox+sx+1,sz*ox+sx+1)or fill
  end
  rows[#rows+1]=table.concat(row)
 end
 return table.concat(rows)
end
function M.Apply(defs)
 local changed={}
 for name,d in pairs(defs)do
  local cp=d.customparams or{};local b=M.Bounds[cp.animsource]
  if b and (tonumber(d.speed or d.maxvelocity)or 0)==0 and not d.movementclass and not d.canfly then
   local ox,oz=tonumber(d.footprintx)or 1,tonumber(d.footprintz)or 1
   local nx,nz=size(ox,b.halfX),size(oz,b.halfZ)
   if nx~=ox or nz~=oz then
    d.yardmap=expandedYard(d.yardmap,ox,oz,nx,nz);d.footprintx,d.footprintz=nx,nz
    changed[name]={ox,oz,nx,nz}
   end
   cp.building_placement_policy='origin_envelope_v1';cp.building_placement_model=b.model
  end
 end
 return changed
end
return M
