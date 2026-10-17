-- Generated-release boundary: the normal authoring game is unchanged.
-- Run its raw overlay in a private definitions table, then export additive units.
local M = {}
local function copy(v, seen)
 if type(v) ~= 'table' then return v end
 seen = seen or {}; if seen[v] then return seen[v] end
 local out = {}; seen[v] = out
 for k,x in pairs(v) do out[copy(k,seen)] = copy(x,seen) end
 return out
end
local function marked(d)
 local cp = d and d.customparams or {}
 return cp.prototype40k == true or tostring(cp.prototype40k) == '1'
end
local protected = {animsource=true,objectname=true,script=true,buildpic=true,
 modelname=true,modelpath=true,source_entity=true,source_whm=true,
 original_bar_model_path=true,original_bar_script_path=true}
local function translate(value, names, field)
 if type(value) == 'string' then
  return not protected[field] and names[value] or value
 end
 if type(value) ~= 'table' then return value end
 local out = {}
 for key,item in pairs(value) do
  local nextkey = type(key) == 'string' and names[key] or key
  assert(out[nextkey] == nil, 'Additive release key collision: '..tostring(nextkey))
  out[nextkey] = translate(item,names,key)
 end
 return out
end
function M.Apply(defs, originalVFS, globals)
 local config = originalVFS.Include('40k_configs/randomguy_additive_map.lua')
 local names, rawSources = config.names, config.rawSources
 local native, working = {}, copy(defs)
 for key,d in pairs(defs) do if not marked(d) then native[key] = copy(d) end end
 local sandbox = setmetatable({UnitDefs=working},{__index=globals})
 sandbox._G = sandbox
 local privateVFS = {}; for k,v in pairs(originalVFS) do privateVFS[k] = v end
 sandbox.VFS = privateVFS
 function privateVFS.Include(path, env, mode)
  local raw = rawSources[path]
  return originalVFS.Include(raw or path, env or sandbox, mode)
 end
 function privateVFS.LoadFile(path, mode)
  return originalVFS.LoadFile(rawSources[path] or path, mode)
 end
 function privateVFS.FileExists(path, mode)
  return originalVFS.FileExists(rawSources[path] or path, mode)
 end
 originalVFS.Include('40k_reference/randomguy_raw_source/unitdefs_post.lua',sandbox)
 local exported, collisions = {}, 0
 for key,d in pairs(working) do
  if marked(d) then
   local target = names[key] or key
   assert(not native[target], '40K export would overwrite native unit: '..target)
   assert(not exported[target], 'Duplicate additive unit: '..target)
   if native[key] then
    assert(names[key], 'Unmapped native/40K collision: '..key)
    collisions = collisions + 1
   end
   exported[target] = translate(d,names)
  elseif not native[key] then
   -- Keep distinct original-reference/diagnostic definitions under their own IDs.
   exported[key] = copy(d)
  end
 end
 assert(collisions == config.collisions, 'Additive collision set changed')
 local commanderSet = {}
 assert(#config.commanders == 4, 'Exactly four additional 40K commanders required')
 for _,name in ipairs(config.commanders) do
  assert(not commanderSet[name], 'Duplicate additional commander: '..name)
  commanderSet[name] = true
  local d = assert(exported[name], 'Missing added commander: '..name)
  assert(marked(d), 'Unmarked added commander: '..name)
  d.customparams.startunit = true
 end
 for name,d in pairs(exported) do
  local value = (d.customparams or {}).startunit
  local isStart = value == true or value == 1 or value == '1' or value == 'true'
  assert(not isStart or commanderSet[name], 'Unexpected additional 40K startunit: '..name)
 end
 -- Native definitions and their complete build trees remain genuine BAR data.
 for key in pairs(defs) do defs[key] = nil end
 for key,d in pairs(native) do defs[key] = d end
 for key,d in pairs(exported) do
  assert(not defs[key], 'Additive export collision: '..key)
  defs[key] = d
 end
 return {collisions=collisions,commanders=config.commanders,nativePreserved=true}
end
return M
