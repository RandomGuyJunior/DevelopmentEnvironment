-- Bounded diagnostic-only planning. Ordinary leader MOVE remains the caller's responsibility.
local M={}
local function finite(v)return type(v)=='number'and v==v and v~=math.huge and v~=-math.huge end
local function half(d)
 if not d or not finite(d.xsize)or not finite(d.zsize)or d.xsize<=0 or d.zsize<=0 then return end
 return d.xsize*4,d.zsize*4
end
local function geometry(S,defs,factory,s)
 if type(S.GetUnitPosition)~='function'or type(S.GetUnitDefID)~='function'or not s or not s.slots then return end
 local fx,_,fz=S.GetUnitPosition(factory);local hx,hz=half(defs[S.GetUnitDefID(factory)])
 if not finite(fx)or not finite(fz)or not hx then return end
 local bodies={};local seen={};local spread=0;local lx,_,lz=S.GetUnitPosition(s.leader)
 if not finite(lx)or not finite(lz)then return end
 for i=1,8 do
  local id=s.slots[i];if not id or seen[id]then return end;seen[id]=true
  local x,_,z=S.GetUnitPosition(id);local bx,bz=half(defs[S.GetUnitDefID(id)])
  if not finite(x)or not finite(z)or not bx then return end
  bodies[i]={id=id,x=x,z=z,hx=bx,hz=bz,def=S.GetUnitDefID(id)}
  spread=math.max(spread,math.abs(x-lx)+bx,math.abs(z-lz)+bz)
 end
 for i in pairs(s.slots)do if type(i)=='number'and(i<1 or i>8)then return end end
 return{fx=fx,fz=fz,hx=hx,hz=hz,lx=lx,lz=lz,bodies=bodies,spread=spread}
end
local function outside(g,x,z,hx,hz)
 return x+hx<g.fx-g.hx-16 or x-hx>g.fx+g.hx+16 or z+hz<g.fz-g.hz-16 or z-hz>g.fz+g.hz+16
end
function M.Outside(S,defs,factory,s)
 local g=geometry(S,defs,factory,s);if not g then return false,0,'missing_geometry'end
 local n=0;for _,b in ipairs(g.bodies)do if outside(g,b.x,b.z,b.hx,b.hz)then n=n+1 end end
 return n==8,n
end
function M.Plan(S,defs,game,factory,s)
 local g=geometry(S,defs,factory,s)
 if not g or type(S.GetGroundHeight)~='function'or type(S.TestBuildOrder)~='function'or type(S.TestMoveOrder)~='function'
  or not finite(game.mapSizeX)or not finite(game.mapSizeZ)then return nil,'missing_api_or_geometry'end
 -- At most 64 destinations x eight current body footprints; no terrain-wide scan.
 local radius=math.max(g.hx,g.hz)+g.spread+64
 for ring=0,3 do for a=0,15 do
  local angle=a*math.pi/8;local x,z=g.fx+(radius+ring*64)*math.cos(angle),g.fz+(radius+ring*64)*math.sin(angle)
  local legal=true;local y=S.GetGroundHeight(x,z)
  if not finite(y)then legal=false end
  for _,b in ipairs(g.bodies)do
   local bx,bz=x+b.x-g.lx,z+b.z-g.lz;local by=S.GetGroundHeight(bx,bz)
   if not finite(by)or bx-b.hx<32 or bz-b.hz<32 or bx+b.hx>game.mapSizeX-32 or bz+b.hz>game.mapSizeZ-32
    or not outside(g,bx,bz,b.hx,b.hz)then legal=false;break end
   if S.TestBuildOrder(b.def,bx,by,bz,0)~=2 or not S.TestMoveOrder(b.def,bx,by,bz,0,0,0,true,true,false)then legal=false;break end
  end
  if legal then return{x,y,z,plannedBodies=8,checkedDestinations=ring*16+a+1}end
 end end
 return nil,'no_legal_destination'
end
return M
