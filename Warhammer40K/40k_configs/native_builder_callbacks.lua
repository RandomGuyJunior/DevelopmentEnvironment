-- One native builder script path per callback; no work/resource owner here.
local M={}
function M.Call(S,defs,id,name,...)
 local env=S.UnitScript.GetScriptEnv(id)
 -- Pinned BAR stores native Lua callins in env.script; other authored
 -- globally exposed helpers may still be on env itself.
 local callback=env and((env.script or{})[name]or env[name])
 if type(callback)=='function'then S.UnitScript.CallAsUnit(id,callback,...);return true end
 local d=defs[S.GetUnitDefID(id)]
 if d and tostring(d.scriptName or''):lower():sub(-4)=='.cob'and S.GetCOBScriptID and S.CallCOBScript then
  local index=S.GetCOBScriptID(id,name)
  if type(index)=='number'and index>=0 then S.CallCOBScript(id,name,0,...);return true end
 end
 return false
end
return M
