-- One actual ready Ork donor role; read-only site proposal for ordinary native build.
local M={Key='fortyk_ork_naval_factory'}
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
function M.Select(S,D,t,defID,builder,overlap,apron)
 local d=D[defID];local cp=d and d.customParams or{}
 if not d or d.name~=M.Key or cp.faction~='Orks'or cp.prototype40k_native_donor~='corsy'
  or not d.isFactory or d.minWaterDepth~=30 or d.xsize~=12 or d.zsize~=12
  or d.metalCost~=450 or d.energyCost~=950 or d.buildTime~=5100
  or tostring(d.scriptName):lower()~='units/corsy.cob'then return nil,'exact_ready_corsy_required'end
 for _,key in ipairs({'ValidUnitID','GetUnitIsDead','GetUnitTeam','GetUnitDefID','GetUnitHealth','GetUnitPosition','GetUnitCommands','GetGroundHeight','Pos2BuildPos','TestBuildOrder'})do
  if type(S[key])~='function'then return nil,'native_api_'..key end
 end
 if type(overlap)~='function'or type(apron)~='function'or builder==nil or S.ValidUnitID(builder)~=true or S.GetUnitIsDead(builder)~=false then return nil,'actual_coastal_builder_required'end
 local bd=D[S.GetUnitDefID(builder)];local hp,_,_,_,built=S.GetUnitHealth(builder)
 if not bd or not bd.isBuilder or not finite(bd.buildDistance)or bd.buildDistance<=0 or not finite(hp)or hp<=0 or built~=1 or not t.com or S.GetUnitTeam(builder)~=S.GetUnitTeam(t.com)then return nil,'owned_finished_native_builder_required'end
 local queue=S.GetUnitCommands(builder,1);if type(queue)~='table'or next(queue)~=nil then return nil,'idle_native_builder_required'end
 local bx,_,bz=S.GetUnitPosition(builder);if not finite(bx)or not finite(bz)then return nil,'native_builder_position_required'end
 local hx,hz=d.xsize*4+16,d.zsize*4+16;local seen={}
 for ring=0,4 do for a=0,15 do
  local angle=a*math.pi/8;local x,z=bx+ring*32*math.cos(angle),bz+ring*32*math.sin(angle)
  local h=S.GetGroundHeight(x,z)
  if finite(h)then
   local xx,yy,zz=S.Pos2BuildPos(defID,x,h,z,0)
   if finite(xx)and finite(yy)and finite(zz)and(xx-bx)^2+(zz-bz)^2<=bd.buildDistance^2
    and xx>=hx+64 and zz>=hz+64 and xx<=Game.mapSizeX-hx-64 and zz<=Game.mapSizeZ-hz-64 then
    local sig=xx..':'..zz
    if not seen[sig]then
     seen[sig]=true;local wet=true
     -- Enclose every native8 terrain grid vertex across the hull plus16 margin.
     -- Nine samples miss shallow interior shoals even when native build is OPEN2.
     local left,right=math.floor((xx-hx)/8)*8,math.ceil((xx+hx)/8)*8
     local bottom,top=math.floor((zz-hz)/8)*8,math.ceil((zz+hz)/8)*8
     for gx=left,right,8 do
      if not wet then break end
      for gz=bottom,top,8 do
       local ground=S.GetGroundHeight(gx,gz)
       if not finite(ground)or ground>-d.minWaterDepth then wet=false;break end
      end
     end
     if wet and overlap(t,xx,zz,d)==false and apron(t,xx,zz,d)==false then
      local result,feature=S.TestBuildOrder(defID,xx,yy,zz,0)
      if result==2 and feature==nil then return{xx,yy,zz,0},'native_open2_full_draft_current_builder_range'end
     end
    end
   end
  end
 end end
 return nil,'no_open_full_draft_site_in_current_builder_range'
end
return M
