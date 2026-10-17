-- Authored narrow script-status adaptation; native gadget owns all economics.
local M={}
local function enabled(v) return v==true or v==1 or v=='1' end
function M.Proxy(native,defs)
 local eligible={}
 for id,d in pairs(defs) do
  local cp=d.customParams or {}
  local scriptName=(d.scriptName or d.script or ''):lower()
  if enabled(cp.prototype40k) and cp.prototype40k_vital=='converter'
   and scriptName:match('40k_roster%.lua$')
   and cp.energyconv_capacity and cp.energyconv_efficiency then eligible[id]=true end
 end
 local proxy={};for k,v in pairs(native) do proxy[k]=v end
 proxy.CallCOBScript=function(id,name,returns,...)
  if name=='MMStatus' and returns==0 and eligible[native.GetUnitDefID(id)] then
   local status=select(1,...)
   local env=native.UnitScript.GetScriptEnv(id)
   local callback=env and env.script and env.script.MMStatus
   if callback then native.UnitScript.CallAsUnit(id,callback,status) end
   -- Observable script presentation state, never resource grants or activation.
   native.SetUnitRulesParam(id,'prototype40k_conversion_active',status==1 and 1 or 0)
   return 0
  end
  return native.CallCOBScript(id,name,returns,...)
 end
 return proxy
end
return M
