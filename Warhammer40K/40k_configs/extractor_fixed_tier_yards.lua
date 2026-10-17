-- Apply AFTER measured placement envelopes. Native high-resolution BAR yard semantics.
local M={}
local function orbit(x,z,n)
 local cells={};local keys={}
 for i=1,4 do local k=z*n+x;if not keys[k]then cells[#cells+1]=k;keys[k]=true end;x,z=n-1-z,x end
 table.sort(cells);return cells
end
function M.Yards(rawX,rawZ)
 assert(rawX==rawZ and rawX>=3 and rawX%1==0,'Extractor yard requires measured square footprint >=3')
 local n=rawX*2;local corners={[0]=true,[n-1]=true,[(n-1)*n]=true,[n*n-1]=true}
 local seen,groups={},{}
 for z=0,n-1 do for x=0,n-1 do
  local cells=orbit(x,z,n);local key=table.concat(cells,',')
  if not seen[key]then seen[key]=true
   if #cells==4 and not corners[cells[1]]then
    local d=0;for _,k in ipairs(cells)do local px,pz=k%n,math.floor(k/n);d=d+(px-(n-1)/2)^2+(pz-(n-1)/2)^2 end
    groups[#groups+1]={cells=cells,distance=d,key=key}
   end
  end
 end end
 table.sort(groups,function(a,b)if a.distance~=b.distance then return a.distance<b.distance end;return a.key<b.key end)
 assert(#groups>=3,'Insufficient independent native upgrade markers')
 local yards={}
 for tier=1,3 do
  local cells={};for k=0,n*n-1 do cells[k+1]=corners[k]and'c'or'b'end
  for earlier=1,tier-1 do for _,k in ipairs(groups[earlier].cells)do cells[k+1]='s'end end
  for _,k in ipairs(groups[tier].cells)do cells[k+1]='o'end
  yards[tier]='h '..table.concat(cells)
 end
 return yards
end
function M.Apply(defs,families)
 for base in pairs(families)do
  local d=assert(defs[base]);local yards=M.Yards(d.footprintx,d.footprintz)
  for tier=1,3 do local key=tier==1 and base or base..'_t'..tier;local u=assert(defs[key])
   assert(u.footprintx==d.footprintx and u.footprintz==d.footprintz,'Tier footprint drift')
   u.yardmap=yards[tier]
   u.customparams.prototype40k_fixed_extractor_native_gate='measured_native_upgrade_yard_candidate'
  end
 end
end
return M
