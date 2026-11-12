-- Lossless immutable decimal clip storage; only two decoded frames per clip stay live.
-- Cache contains artwork values only. Unit handles, callbacks and pose buffers stay local.
local shared = GG.Bar40KPackedFrameCache
if not shared then shared=setmetatable({},{__mode='k'});GG.Bar40KPackedFrameCache=shared end
return function(frames,index)
 local value=frames[index]
 if type(value)~='string' then return value end
 local cache=shared[frames]
 if not cache then cache={};shared[frames]=cache end
 for i=1,#cache do if cache[i].index==index then return cache[i].value end end
 local out={}
 for text in value:gmatch('[^;]+') do
  local row={};for n in text:gmatch('[^,]+')do row[#row+1]=assert(tonumber(n),'Invalid packed animation number')end
  assert(#row==6,'Invalid packed animation row');out[#out+1]=row
 end
 if #cache==2 then table.remove(cache,1)end
 cache[#cache+1]={index=index,value=out}
 return out
end
