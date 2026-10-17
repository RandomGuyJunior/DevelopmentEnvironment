-- Glue to the single native health owner and event-driven LUS visibility.
local M={}
function M.Attach(C,S,defs,config,bindings,CMD,CMDTYPE,fps)
 local function env(id)return S.UnitScript.GetScriptEnv(id)end
 local hooks={}
 function hooks.Ready(id,def,level)
  local d=defs[def];local row=d and bindings[d.name];local cp=d and d.customParams or{}
  if not row or tostring(cp.listening_post_version)~='1'or cp.listening_post_key~=row.key then return false end
  local e=env(id)
  return e and type(e.ListeningPostReady)=='function'and type(e.SetListeningPostStage)=='function'and S.UnitScript.CallAsUnit(id,e.ListeningPostReady,level)==true or false
 end
 function hooks.Apply(id,def,level,profile)
  if not hooks.Ready(id,def,level)then return false end
  if C.RefreshHealth(id,level>0 and profile.stages[level].health_add or 0)~=true then return false end
  local okay,result=pcall(S.UnitScript.CallAsUnit,id,env(id).SetListeningPostStage,level)
  if okay and result==true then return true end
  -- Unexpected LUS failure cannot leave an unpublished health addition active.
  C.RefreshHealth(id,C.listeningPosts and C.listeningPosts.HealthBonus(id)or 0)
  return false
 end
 function hooks.WeaponAllowed(id,def,level,mount)
  local row=bindings[defs[def].name];local m=row and row.mounts[mount]
  return m and m.level==level or false
 end
 return VFS.Include('40k_configs/listening_post_upgrades.lua').Attach(C,S,defs,config,hooks,CMD,CMDTYPE,fps)
end
return M
