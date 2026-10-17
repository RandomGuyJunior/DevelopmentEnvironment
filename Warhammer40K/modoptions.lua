-- Generated release schema: exact current Hosting defaults plus authored 40K keys.
-- Snapshot provenance is recorded separately; this does not pin public dependency tags.
local options=VFS.Include('40k_reference/randomguy_hosting_modoptions.lua')
local present={}
for _,option in ipairs(options)do
 if option.type=='bool'or option.type=='number'or option.type=='string'or option.type=='list'then
  assert(type(option.key)=='string'and not present[option.key],'Duplicate Hosting option: '..tostring(option.key))
  present[option.key]=true
 end
end
for _,option in ipairs(VFS.Include('40k_configs/randomguy_options_schema.lua'))do
 assert(type(option.key)=='string'and option.key:match('^prototype_'),'Only authored 40K options may be appended')
 assert(not present[option.key],'40K option collides with native Hosting option: '..option.key)
 present[option.key]=true
 options[#options+1]=option
end
return options
