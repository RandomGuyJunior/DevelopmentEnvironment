-- Extra real source pivots for one native main-gun group; no actor/weapon bypass.
return function(lookup,setOffset,wait,xaxis,yaxis)
 local R={}
 local function pieces(text)local out={};for name in(text or''):gmatch('[^,%s]+')do local p=lookup(name);if not p then return nil end;out[#out+1]=p end;return out end
 function R.Aim(m,h,p)
  if tostring(m.params.source_group_aim_required)~='1'then return true end
  local yaw=pieces(m.params.source_group_yaw);local pitch=pieces(m.params.source_group_pitch)
  if not yaw or not pitch or #yaw~=3 or #pitch~=3 then return false end
  for _,piece in ipairs(yaw)do setOffset(piece,yaxis,h,tonumber(m.params.source_aimspeed)or 3)end
  for _,piece in ipairs(pitch)do setOffset(piece,xaxis,-p,2)end
  m.airYaw,m.airPitch=yaw,pitch;return true
 end
 function R.Wait(m)
  for _,piece in ipairs(m.airYaw or{})do wait(piece,yaxis)end
  for _,piece in ipairs(m.airPitch or{})do wait(piece,xaxis)end
 end
 return R
end
