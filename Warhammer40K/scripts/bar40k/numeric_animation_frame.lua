-- Finite immutable artwork cache: one flat number array per authored frame.
-- Decoding each string once avoids allocating new row/string tables every sim tick.
-- There are no unit IDs, transient poses, callbacks or GC settings in this cache.
local shared=GG.Bar40KNumericFrameCache
if not shared then shared=setmetatable({},{__mode='k'});GG.Bar40KNumericFrameCache=shared end
return function(frames,index)
 local cache=shared[frames];if not cache then cache={};shared[frames]=cache end
 local f=cache[index];if f then return f end;f={};local input=frames[index]
 if type(input)=='string' then for value in input:gmatch('[^,;]+')do f[#f+1]=assert(tonumber(value))end
 else for _,r in ipairs(input)do for j=1,6 do f[#f+1]=r[j]end end end
 cache[index]=f;return f
end
