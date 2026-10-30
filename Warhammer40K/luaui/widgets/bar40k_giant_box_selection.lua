function widget:GetInfo()return{name='Giant partial-box selection',desc='Adds only Giant models touched by a genuine drag box',author='BAR40K',layer=-10000,enabled=true}end
local profiles=VFS.Include('luaui/configs/bar40k_giant_selection.lua')
local press,pending
local function disabled(x,y)
 if Spring.IsGUIHidden()or Spring.IsAboveMiniMap(x,y)then return true end
 local spec,_,full=Spring.GetSpectatingState()
 return spec and not full
end
local function transform(m,x,y,z)return m[1]*x+m[5]*y+m[9]*z+m[13],m[2]*x+m[6]*y+m[10]*z+m[14],m[3]*x+m[7]*y+m[11]*z+m[15]end
local function intersects(points,x0,y0,x1,y1)
 -- Separating-axis test of the projected convex eight-corner hull and rectangle.
 local function cross(a,b,c)return(b[1]-a[1])*(c[2]-a[2])-(b[2]-a[2])*(c[1]-a[1])end
 table.sort(points,function(a,b)return a[1]<b[1]or(a[1]==b[1]and a[2]<b[2])end)
 local hull={}
 for _,p in ipairs(points)do while #hull>=2 and cross(hull[#hull-1],hull[#hull],p)<=0 do hull[#hull]=nil end;hull[#hull+1]=p end
 local lower=#hull
 for i=#points-1,1,-1 do local p=points[i];while #hull>lower and cross(hull[#hull-1],hull[#hull],p)<=0 do hull[#hull]=nil end;hull[#hull+1]=p end
 hull[#hull]=nil
 if #hull<3 then return false end
 local rect={{x0,y0},{x1,y0},{x1,y1},{x0,y1}}
 local function separated(ax,ay)
  local lo,hi=math.huge,-math.huge;local rl,rh=lo,hi
  for _,p in ipairs(hull)do local v=p[1]*ax+p[2]*ay;lo=math.min(lo,v);hi=math.max(hi,v)end
  for _,p in ipairs(rect)do local v=p[1]*ax+p[2]*ay;rl=math.min(rl,v);rh=math.max(rh,v)end
  return hi<rl or rh<lo
 end
 if separated(1,0)or separated(0,1)then return false end
 for i,a in ipairs(hull)do local b=hull[i%#hull+1];if separated(-(b[2]-a[2]),b[1]-a[1])then return false end end
 return true
end
local function overlaps(u,profile,box)
 local um={Spring.GetUnitTransformMatrix(u)};if #um~=16 then return false end
 local map=Spring.GetUnitPieceMap(u);if not map then return false end
 for _,b in ipairs(profile.boxes)do
  local piece=map[b.name];local pm=piece and{Spring.GetUnitPieceMatrix(u,piece)}
  if pm and #pm==16 then
   local points={};local valid=true
   for _,x in ipairs({-b.scales[1]/2,b.scales[1]/2})do for _,y in ipairs({-b.scales[2]/2,b.scales[2]/2})do for _,z in ipairs({-b.scales[3]/2,b.scales[3]/2})do
    local px,py,pz=transform(pm,x,y,z);px,py,pz=transform(um,px,py,pz)
    local sx,sy,sz=Spring.WorldToScreenCoords(px,py,pz)
    if not sx or not sz or sz<0 or sz>1 then valid=false else points[#points+1]={sx,sy}end
   end end end
   if valid and intersects(points,box.x0,box.y0,box.x1,box.y1)then return true end
  end
 end
 return false
end
function widget:MousePress(x,y,button)
 press=nil
 if button~=1 or disabled(x,y)then return false end
 local selected={};for _,u in ipairs(Spring.GetSelectedUnits())do selected[u]=true end
 press={x=x,y=y,selected=selected}
 return false -- Native BAR receives the unchanged mouse gesture.
end
function widget:MouseRelease(x,y,button)
 if button~=1 or not press then press=nil;return false end
 local p=press;press=nil
 if disabled(x,y)then return false end
 local alt,ctrl,meta,shift=Spring.GetModKeyState()
 if alt or meta then return false end
 local threshold=Spring.GetConfigInt('MouseDragSelectionThreshold',4)
 if x==p.x or y==p.y then return false end
 if(x-p.x)^2+(y-p.y)^2<=threshold*threshold then return false end
 pending={x0=math.min(x,p.x),y0=math.min(y,p.y),x1=math.max(x,p.x),y1=math.max(y,p.y),ctrl=ctrl,shift=shift,selected=p.selected}
 return false
end
function widget:Update()
 if not pending then return end
 local box=pending;pending=nil
 if Spring.IsGUIHidden()then return end
 local selected={};for _,u in ipairs(Spring.GetSelectedUnits())do selected[u]=true end
 local changed=false
 local myTeam=Spring.GetMyTeamID();local spec,_,full=Spring.GetSpectatingState()
 for _,u in ipairs(Spring.GetAllUnits())do
  if not Spring.GetUnitNoSelect(u)and((spec and full)or Spring.GetUnitTeam(u)==myTeam)then
   local ud=UnitDefs[Spring.GetUnitDefID(u)];local key=ud and ud.customParams.bar40k_selection_profile;local profile=key and profiles[key]
   if profile and overlaps(u,profile,box)then
    if box.ctrl and box.selected[u]then if selected[u]then changed=true end;selected[u]=nil else if not selected[u]then changed=true end;selected[u]=true end
   end
  end
 end
 if changed then local list={};for u in pairs(selected)do list[#list+1]=u end;table.sort(list);Spring.SelectUnitArray(list,false)end
end
