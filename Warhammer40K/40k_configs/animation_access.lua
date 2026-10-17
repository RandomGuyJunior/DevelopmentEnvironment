-- Read-only access by contract: return original animation tables, never proxies
-- or copies. Clip/frame mutation is forbidden for every consumer. Actor pose,
-- jump, cloth and transition state remains outside these shared source tables.
local M={}
function M.New(shared,vfs)
 assert(type(shared)=='table' and type(vfs)=='table' and type(vfs.Include)=='function')
 shared.Prototype40kAnimationCache=shared.Prototype40kAnimationCache or {}
 local cache=shared.Prototype40kAnimationCache
 local failed,loading={},{}
 local api={}
 function api.Get(key)
  if type(key)~='string' or not key:match('^[a-zA-Z0-9_]+$') then return nil,'invalid_source_key' end
  local existing=cache[key]
  if existing~=nil then
   if type(existing)~='table' or type(existing.clips)~='table' then return nil,'invalid_shared_animation' end
   return existing
  end
  if failed[key]then return nil,failed[key]end
  if loading[key]then return nil,'recursive_animation_load'end
  local path='scripts/generated/'..key..'_anim.lua'
  if vfs.FileExists and not vfs.FileExists(path)then failed[key]='missing_animation';return nil,failed[key]end
  loading[key]=true
  local ok,data=pcall(vfs.Include,path)
  loading[key]=nil
  if not ok then failed[key]='animation_include_failed';return nil,failed[key]end
  if type(data)~='table' or type(data.clips)~='table' then failed[key]='invalid_animation';return nil,failed[key]end
  cache[key]=data
  return data
 end
 return api
end
return M
