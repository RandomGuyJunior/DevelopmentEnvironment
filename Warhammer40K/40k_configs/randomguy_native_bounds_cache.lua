-- Release-only observed bounds. Normal-development checksum policy is unchanged.
-- Engine SHA256 is external capture provenance, NOT an in-game binary assertion.
local M = {}
local PROFILE = 'randomguy-stack-v1'
local STACK = 'RandomGuy Mod Stack warhammer-40k'
local fields = {'height','radius','midx','minx','maxx','midy','miny','maxy','midz','minz','maxz'}
local function on(x) return x == true or x == 1 or x == '1' end
local function source(d)
 local cp = d and d.customParams or {}
 return d and on(cp.prototype40k) and (d.modeltype == 'glb' or d.modeltype == 'gltf')
end
local function encode(v)
 if type(v) == 'string' then return '"' .. v:gsub('[%z\1-\31\\"]', function(c) return string.format('\\u%04x', c:byte()) end) .. '"' end
 if type(v) == 'number' then assert(v == v and math.abs(v) < math.huge, 'nonfinite cache identity'); return string.format('%.17g', v) end
 if type(v) == 'boolean' then return v and 'true' or 'false' end
 assert(type(v) == 'table', 'unsupported cache identity')
 local a = {}; for k,x in pairs(v) do a[#a+1] = encode(tostring(k)) .. ':' .. encode(x) end
 table.sort(a); return '{' .. table.concat(a, ',') .. '}'
end
local function identity(d)
 local cp = {}; for k,v in pairs(d.customParams or {}) do if type(v) == 'string' or type(v) == 'number' or type(v) == 'boolean' then cp[k] = v end end
 return {name=d.name,modelname=d.modelname,modelpath=d.modelpath,modeltype=d.modeltype,customParams=cp,xsize=d.xsize,zsize=d.zsize,isBuilding=d.isBuilding,isFactory=d.isFactory,health=d.health,metalCost=d.metalCost,energyCost=d.energyCost,buildTime=d.buildTime}
end
local function hex(s,n) return type(s) == 'string' and #s == n and not s:find('[^0-9a-f]') end
local function path(s)
 return type(s) == 'string' and #s > 0 and s == s:lower() and not s:find('[\\:%z]') and not s:find('//',1,true) and s:sub(1,1) ~= '/' and not ('/'..s..'/'):find('/%.%./') and not ('/'..s..'/'):find('/%./')
end
local function fileRecord(p,r)
 assert(path(p) and type(r) == 'table' and hex(r.sha512,128), 'invalid release file binding')
 assert(type(r.bytes) == 'number' and r.bytes > 0 and r.bytes == math.floor(r.bytes) and r.bytes <= 1073741824, 'invalid release file length')
 return {path=p,sha512=r.sha512,bytes=r.bytes}
end
function M.New(data,env)
 env = env or {UnitDefs=UnitDefs,Spring=Spring,Engine=Engine,Game=Game,VFS=VFS}
 assert(type(env.VFS.LoadFile) == 'function' and type(env.VFS.CalculateHash) == 'function' and env.VFS.GAME, 'release archive hashing API unavailable')
 data = data or env.VFS.Include('40k_reference/randomguy_source_native_bounds_receipt.lua',nil,env.VFS.GAME)
 assert(type(data) == 'table' and data.schema == 1 and data.profile == PROFILE and type(data.rows) == 'table', 'missing release native metadata receipt')
 assert(data.engineVersion == '2026.07.04' and data.engineVersion == env.Engine.version and data.engineVersionFull == env.Engine.versionFull, 'release native engine version changed')
 assert(hex(data.engineSHA256,64), 'missing external engine capture provenance')
 assert(data.gameName == STACK and env.Game.gameName == STACK and type(data.gameVersion) == 'string' and data.gameVersion == env.Game.gameVersion, 'release stack identity changed')
 assert(type(data.definitions) == 'number' and data.definitions > 0 and data.definitions == math.floor(data.definitions), 'invalid release definition count')
 local rows, names, modelFiles, checked = {}, {}, {}, {}
 local failed = false
 local function verify(r)
  assert(not failed, 'release native metadata session previously refused')
  if checked[r.path] then return end
  local ok, reason = pcall(function()
   local bytes = env.VFS.LoadFile(r.path,env.VFS.GAME)
   assert(type(bytes) == 'string' and #bytes == r.bytes, 'release file missing/length changed: '..r.path)
   assert(env.VFS.CalculateHash(bytes,1) == r.sha512, 'release file bytes changed: '..r.path)
  end)
  if not ok then failed = true; error(reason) end
  checked[r.path] = true
 end
 local smallCount, smallBytes = 0, 0
 for p,r in pairs(data.requiredFiles or {}) do
  local f = fileRecord(p,r)
  assert(not p:find('^objects3d/') and not p:find('^unittextures/') and p ~= '40k_reference/randomguy_source_native_bounds_receipt.lua', 'bulk/self file in small release closure')
  smallCount = smallCount + 1; smallBytes = smallBytes + f.bytes
  assert(smallCount <= 256 and smallBytes <= 8388608, 'small release closure exceeds budget')
  verify(f)
 end
 local count = 0
 for id,d in pairs(env.UnitDefs) do if source(d) then
  local r = data.rows[d.name]; local wanted = encode(identity(d))
  if type(r) ~= 'table' or encode(r.identity) ~= wanted then
   r = nil
   for _,candidate in ipairs((data.variants or {})[d.name] or {}) do
    if encode(candidate.identity) == wanted then assert(not r, 'ambiguous observed release identity'); r = candidate end
   end
  end
  assert(type(r) == 'table', 'missing/stale release definition '..tostring(d.name))
  assert(type(r.dimensions) == 'table' and type(r.model) == 'table' and r.model.path == d.modelpath, 'missing release dimensions/physical binding')
  local f = fileRecord(r.model.path,r.model)
  -- Standalone glTF can reference external buffers; require a proven buffer
  -- closure before admitting that format. Current release assets are GLB.
  assert(f.path:find('^objects3d/') and f.path:sub(-4) == '.glb' and d.modeltype == 'glb', 'unsupported release geometry path')
  if modelFiles[f.path] then assert(modelFiles[f.path].sha512 == f.sha512 and modelFiles[f.path].bytes == f.bytes, 'conflicting release physical bindings') else modelFiles[f.path] = f end
  local dims = {}
  for _,k in ipairs(fields) do local v = r.dimensions[k]; assert(type(v) == 'number' and v == v and math.abs(v) < math.huge, 'invalid release native dimension '..k); dims[k] = v end
  assert(r.height == dims.height and r.radius == dims.radius and r.radius >= 0 and r.height >= 0, 'inconsistent release native getters')
  assert(dims.minx <= dims.maxx and dims.miny <= dims.maxy and dims.minz <= dims.maxz, 'invalid release native envelope')
  rows[id] = {height=r.height,radius=r.radius,dimensions=dims,model=f}
  assert(not names[d.name], 'duplicate release source name'); names[d.name] = true; count = count + 1
 end end
 assert(count == data.definitions, 'release source definition count changed')
 local receiptCount = 0
 for name in pairs(data.rows) do assert(names[name], 'unmounted release definition '..tostring(name)); receiptCount = receiptCount + 1 end
 assert(receiptCount == count, 'incomplete release rows')
 local C = {}
 local function row(id) assert(not failed, 'release native metadata session previously refused'); local r=rows[id]; if r then verify(r.model) end; return r end
 function C.Height(def) local r=row(def.id); return r and r.height or def.height end
 function C.Radius(def) local r=row(def.id); return r and r.radius or def.radius end
 function C.Dimensions(id)
  local r=row(id); if not r then return env.Spring.GetUnitDefDimensions(id) end
  local t={}; for _,k in ipairs(fields) do t[k]=r.dimensions[k] end; return t
 end
 return C
end
M.Identity = identity
return M
