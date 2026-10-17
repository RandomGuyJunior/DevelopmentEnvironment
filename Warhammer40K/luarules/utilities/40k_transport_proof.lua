-- Read-only proof predicates; never issues orders or mutates unit state.
local M={}
function M.finite(x) return type(x)=='number' and x==x and math.abs(x)<math.huge end
function M.command(cmd,args,C)
 for _,v in ipairs(args) do if not M.finite(v) then return false end end
 local n=#args
 if cmd==C.LOAD_UNITS then return n==1 and type(args[1])=='number' end
 if cmd==C.UNLOAD_UNITS then return n==4 and args[4]>0 end
 if cmd==C.MOVE then return n==3 end
 if cmd==C.STOP then return n==0 end
 if cmd==C.FIRE_STATE or cmd==C.MOVE_STATE then return n==1 and args[1]==0 end
 return false
end
function M.snapshot(ids,base,read,truck)
 local members={}
 for _,id in ipairs(read.members or {}) do
  if members[id] then return false,'duplicate_membership' end
  members[id]=true
 end
 for id in pairs(members) do if not base[id] then return false,'foreign_cargo' end end
 for _,id in ipairs(ids) do
  local b,a=base[id],read.units[id]
  if not a or a.dead or a.def~=b.def or a.team~=b.team then return false,'identity_or_team_changed' end
  if not M.finite(b.hp) or not M.finite(b.maxhp) or not M.finite(a.hp) or not M.finite(a.maxhp) then return false,'health_readback_missing' end
  if a.hp~=b.hp or a.maxhp~=b.maxhp then return false,'health_changed' end
  if (a.owner==truck)~=not not members[id] then return false,'owner_membership_disagreement' end
  if a.owner and a.owner~=truck then return false,'unexpected_transporter' end
 end
 return true,members
end
function M.callback(kind,id,def,team,transport,transportTeam,expected,base,truck,truckTeam)
 local b=base[id]
 if kind~=expected.kind or id~=expected.id or not b or def~=b.def or team~=b.team or transport~=truck or transportTeam~=truckTeam then
  return false,'unexpected_native_callback'
 end
 return true
end
local function dot(a,b) return a[1]*b[1]+a[2]*b[2]+a[3]*b[3] end
local function sub(a,b) return {a[1]-b[1],a[2]-b[2],a[3]-b[3]} end
local function cross(a,b) return {a[2]*b[3]-a[3]*b[2],a[3]*b[1]-a[1]*b[3],a[1]*b[2]-a[2]*b[1]} end
local function radius(p)
 -- Pinned types: ellipsoid0, cylinder1, box2, sphere3. Equal-axis
 -- ellipsoids are mathematically spheres; cylinders are never inferred spheres.
 if p.kind==3 or p.kind==0 and p.half[1]==p.half[2] and p.half[2]==p.half[3] then
  if p.half[1]~=p.half[2] or p.half[2]~=p.half[3] then return end
  return p.half[1]
 end
end
local function valid(p)
 if not p or p.disabled~=false then return false end
 for _,v in ipairs({p.center,p.half}) do
  if not v then return false end
  for i=1,3 do if not M.finite(v[i]) then return false end end
 end
 for i=1,3 do if p.half[i]<=0 then return false end end
 if not p.axes or #p.axes~=3 then return false end
 for _,a in ipairs(p.axes) do for i=1,3 do if not M.finite(a[i]) then return false end end end
 return true
end
function M.overlap(a,b)
 if not valid(a) or not valid(b) then return nil,'native_primitive_readback_unknown' end
 local ra,rb=radius(a),radius(b)
 local d=sub(a.center,b.center)
 if ra and rb then
  local dsq=dot(d,d);local rs=ra+rb
  return dsq<rs*rs,'sphere_sphere',math.sqrt(dsq),rs
 end
 if ra and b.kind==2 or rb and a.kind==2 then
  local sphere,box,r
  if ra then sphere,box,r=a,b,ra else sphere,box,r=b,a,rb end
  local relative=sub(sphere.center,box.center);local closest={0,0,0}
  for i=1,3 do local v=math.max(-box.half[i],math.min(box.half[i],dot(relative,box.axes[i])))
   for j=1,3 do closest[j]=closest[j]+box.axes[i][j]*v end
  end
  local delta=sub(relative,closest);local dsq=dot(delta,delta)
  return dsq<r*r,'sphere_obb',math.sqrt(dsq),r
 end
 if a.kind==2 and b.kind==2 then
  local axes={};for i=1,3 do axes[#axes+1]=a.axes[i];axes[#axes+1]=b.axes[i] end
  for i=1,3 do for j=1,3 do axes[#axes+1]=cross(a.axes[i],b.axes[j]) end end
  local maxgap=-math.huge
  for _,axis in ipairs(axes) do
   local nsq=dot(axis,axis)
   if nsq>0 then
    local span=0;for i=1,3 do span=span+math.abs(dot(axis,a.axes[i]))*a.half[i]+math.abs(dot(axis,b.axes[i]))*b.half[i] end
    local gap=(math.abs(dot(d,axis))-span)/math.sqrt(nsq)
    maxgap=math.max(maxgap,gap)
   end
  end
  return maxgap<0,'obb_obb_sat',maxgap,0
 end
 -- General unequal ellipsoids/cylinders require another exact primitive solver.
 -- Fail UNKNOWN rather than turning their enclosing boxes into alleged overlap.
 return nil,'unsupported_native_primitive_pair'
end
function M.pad(units,truck,pad,ground,testMove,observe)

 local list={}
 for _,a in ipairs(units) do
  if not M.finite(a.x) or not M.finite(a.y) or not M.finite(a.z) then return false,'position_missing' end
  if (a.x-pad.x)^2+(a.z-pad.z)^2>(pad.radius+8)^2 then return false,'outside_requested_unload_pad' end
  local h=ground(a.x,a.z)
  if not M.finite(h) or h<0 or math.abs(a.y-h)>8 then return false,'unload_ground_height' end
  if not testMove(a.def,a.x,h,a.z) then return false,'unload_ground_not_passable' end
  list[#list+1]=a
 end
 list[#list+1]=truck
 -- Test actual native primitives; bounding boxes remain logging evidence only.
 for i=1,#list do for j=i+1,#list do
  local a,b=list[i],list[j]
  local overlap,kind,metric,limit=M.overlap(a.primitive,b.primitive)
  if observe then observe(a.id,b.id,overlap,kind,metric,limit) end
  if overlap==nil then return false,kind end
  if overlap then return false,'actual_native_primitive_overlap' end
 end end
 return true
end
return M
