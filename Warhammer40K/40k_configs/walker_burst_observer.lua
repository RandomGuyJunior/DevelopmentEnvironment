-- Observation only: no command/aim/weapon/resource/projectile mutation.
local M={}
function M.New(S,U,emit,maxShots,scope)
 local actors,pending,seenPID={},{},{};local serial,count,projectiles=0,0,0;maxShots=maxShots or 128
 local function vec(fn,...)local a,b,c=fn(...);if a==nil or b==nil or c==nil then return false end;return{a,b,c}end
 local function capture(id,muzzle,mount,emitterOnly)
  local map=S.GetUnitPieceMap(id)or{};local matrices={};local muzzleName
  local selected=actors[id]and actors[id].selected and actors[id].selected[mount]
  for name,index in pairs(map)do
   if index==muzzle then muzzleName=name end
   if not(scope and scope.rangedOnly)or(selected and selected[name]and(not emitterOnly or index==muzzle))then
    local matrix={S.GetUnitPieceMatrix(id,index)};if #matrix==16 then matrices[name]=matrix else matrices[name]=false end
   end
  end
  local front,up,right=S.GetUnitVectors(id)
  local x,y,z,dx,dy,dz=S.GetUnitPiecePosDir(id,muzzle)
  return{position=vec(S.GetUnitPosition,id),front=front or false,up=up or false,right=right or false,
   matrices=matrices,muzzle_position=x and{x,y,z}or false,muzzle_direction=dx and{dx,dy,dz}or false,
   muzzle_piece=muzzle,muzzle_name=muzzleName or false,phase=S.GetUnitRulesParam(id,'40k_burst_probe_phase')or (actors[id]and actors[id].key=='ork_dakka_stompa'and S.GetUnitRulesParam(id,'40k_validation_mount'))or 'unlabelled'}
 end
 local O={}
 function O.Register(id)
  local ud=U[S.GetUnitDefID(id)];local key=ud and ud.customParams and ud.customParams.animsource
  if not key and ud and ud.name=='imp_russ'then key='leman_russ'end
  if not(key=='leman_russ'or key=='ork_dakka_stompa'or key=='ork_kan_twin_shoota'or key=='ork_kan_twin_kmb'or key=='ork_kan_twin_rokkit'or key=='ork_dread_ranged_fourarm'or(key=='nec_immortal'and scope and scope.nec_immortal==true))then return false end
  local selected
  if scope and scope.rangedOnly then
   if not(key=='ork_kan_twin_shoota'or key=='ork_kan_twin_kmb'or key=='ork_kan_twin_rokkit'or key=='ork_dread_ranged_fourarm')then return false end
   assert(type(scope.weaponDefs)=='table','Actual ranged WeaponDefs required');selected={}
   local map=S.GetUnitPieceMap(id)or{}
   for n,w in ipairs(ud.weapons)do
    local wd=assert(scope.weaponDefs[w.weaponDef],'Actual selected native weapon required');local c=wd.customParams or{};local names={}
    for _,field in ipairs({'source_aimpiece','source_pitchpiece','source_muzzle','source_muzzle_pair','source_weapon_bones'})do
     if c[field]then for name in tostring(c[field]):gmatch('[^,%s]+')do assert(map[name]~=nil,'Actual source physical piece missing:'..name);names[name]=true end end
    end
    assert(c.source_muzzle and c.source_aimpiece and c.source_pitchpiece and c.source_weapon_bones,'Genuine selected emitter/bone metadata required');selected[n]=names
   end
  end
  actors[id]={key=key,weapons=ud.weapons,selected=selected};return true
 end
 function O.Shot(id,n,muzzle)
  if count>=maxShots or not actors[id]or not muzzle then return end
  serial=serial+1;count=count+1;pending[id]=pending[id]or{}
  local row={kind='SHOT',serial=serial,frame=S.GetGameFrame(),owner=id,mount=n,actor=actors[id].key,snapshot=capture(id,muzzle,n),
   native_target=S.GetUnitWeaponTarget and{S.GetUnitWeaponTarget(id,n)}or false,
   nominal_weapon_vector=S.GetUnitWeaponVectors and{S.GetUnitWeaponVectors(id,n)}or false}
  local prev=pending[id][n];row.ambiguous=prev and not prev.consumed and prev.frame==row.frame or false;pending[id][n]=row;emit(row)
 end
 function O.Query(id,n,piece)
  local shot=pending[id]and pending[id][n]
  if not shot or shot.consumed or shot.frame~=S.GetGameFrame()then return end
  if piece~=shot.snapshot.muzzle_piece then shot.queryMismatch=true;return end
  if shot.query then return end
  -- Real native Query callback, not inferred from a nominal weapon vector.
  shot.query={frame=S.GetGameFrame(),piece=piece,snapshot=capture(id,piece,n)}
 end
 function O.Projectile(pid,id,wd)
  local a=actors[id];if not a or projectiles>=maxShots*2 then return end;projectiles=projectiles+1
  local matches={};for n,w in ipairs(a.weapons)do if w.weaponDef==wd then matches[#matches+1]=n end end
  local shot=#matches==1 and pending[id]and pending[id][matches[1]]or nil
  local duplicate=seenPID[pid];seenPID[pid]=true
  local linked=shot and not duplicate and not shot.ambiguous and not shot.queryMismatch and not shot.consumed and shot.frame==S.GetGameFrame()
  local row={kind='PROJECTILE',projectile=pid,owner=id,weapondef=wd,frame=S.GetGameFrame(),actor=a.key,
   mount=#matches==1 and matches[1]or false,shot_serial=linked and shot.serial or false,
   association=linked and 'unique_same_frame_unconsumed_shot'or 'UNRESOLVED',
   position=vec(S.GetProjectilePosition,pid),velocity=vec(S.GetProjectileVelocity,pid),direction=vec(S.GetProjectileDirection,pid),
   snapshot=linked and capture(id,shot.snapshot.muzzle_piece,matches[1],true)or false,
   actual_query=linked and shot.query or false,duplicate_pid=duplicate or false}
  if linked then shot.consumed=true end;emit(row)
 end
 return O
end
return M
