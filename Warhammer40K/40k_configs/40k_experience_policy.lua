-- Re-evaluate the actual final game policy in a private native-LuaParser-like
-- environment. Never rerun BAR init against the live normalized options proxy.
local M={}
local function copy(t)
 local out={};for k,v in pairs(t or{})do if type(v)=='table'then out[k]=copy(v)else out[k]=v end end;return out
end
local function finite(v)return type(v)=='number'and v==v and v>=0 and v<math.huge end
function M.Read()
 assert(VFS and VFS.Include and Spring and Spring.GetModOptions,'Policy source APIs unavailable')
 local raw
 if BAR and BAR.GetModOptionsCopy then raw=BAR.GetModOptionsCopy()
 else
  raw=Spring.GetModOptions()
  assert(type(raw)=='table'and getmetatable(raw)==nil,'Immutable options require BAR.GetModOptionsCopy')
 end
 assert(type(raw)=='table','Actual option copy unavailable')
 local options=copy(raw)
 local env={}
 -- Match the ModInfo native LuaParser Script namespace: it exposes engine
 -- version checking, not GetName. Pinned init consequently selects LuaParser.
 local globals={'assert','error','ipairs','next','pairs','pcall','select','tonumber','tostring','type','unpack','xpcall','getmetatable','setmetatable','rawget','rawset','rawequal','getfenv','setfenv','loadstring','load','print'}
 for _,name in ipairs(globals)do env[name]=_G[name]end
 env.math=copy(math);env.string=copy(string);env.table=copy(table);env.coroutine=copy(coroutine)
 env._G=env;env.BAR={};env.require=nil;env.Script={IsEngineMinVersion=assert(Script.IsEngineMinVersion)}
 -- ModInfo's filename LuaParser calls SetupLua(...,false), so Game is absent.
 env.Game=nil;env.Platform=copy(Platform);env.LOG=copy(LOG);env.Encoding=copy(Encoding)
 env.Spring={GetModOptions=function()return copy(options)end,Echo=Spring.Echo,Log=Spring.Log,TimeCheck=Spring.TimeCheck}
 env.VFS={}
 for _,name in ipairs({'Include','LoadFile','FileExists','DirList','SubDirs','ZIP','RAW','MOD','BASE','MAP','RAW_FIRST','ZIP_FIRST'})do env.VFS[name]=VFS[name]end
 local rules=VFS.Include('gamedata/modrules.lua',env)
 local policy=assert(type(rules)=='table'and rules.experience,'Actual final experience policy missing')
 local result={}
 for _,name in ipairs({'experienceMult','powerScale','healthScale','reloadScale'})do assert(finite(policy[name]),'Invalid actual experience policy '..name);result[name]=policy[name]end
 return result
end
return M
