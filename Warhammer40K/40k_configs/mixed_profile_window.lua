-- Read-only wall-clock window shared by opt-in mixed diagnostics.
local M={}
function M.New(S,cfg)
 local serial,started=0,nil
 return function(now)
  local nextSerial=S.GetGameRulesParam('40k_mixed_v2_serial') or 0
  if nextSerial~=serial then serial=nextSerial;started=now end
  local done=S.GetGameRulesParam('40k_mixed_v2_done')==1
  local mapped=cfg.Window(serial)
  local stage=mapped and mapped.stage
  local phase=mapped and mapped.phase
  local valid=mapped~=nil
  local age=started and S.DiffTimers(now,started) or 0
  return {serial=serial,stage=stage,phase=phase,target=cfg.stages[stage],done=done,
   age=age,active=valid and not done and age>=cfg.settleWall and age<cfg.settleWall+cfg.measureWall,
   valid=valid,ended=valid and age>=cfg.settleWall+cfg.measureWall}
 end
end
return M
