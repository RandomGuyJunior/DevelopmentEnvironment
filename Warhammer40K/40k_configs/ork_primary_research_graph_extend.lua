-- Extend actual variant graph before constructing the paid controller.
local M={Version=1}
local function leaf(s)return tostring(s):gsub('\\','/'):lower():match('([^/]+)%.lua$')or tostring(s):lower()end
function M.Extend(V,D,F,external)
 local sourceKeys={};for k,p in pairs(V.SourceProfiles)do sourceKeys[leaf(p.source)]=k end
 for k,p in pairs(F.profiles)do sourceKeys[leaf(p.source)]=k end
 for s,k in pairs(external or{})do sourceKeys[leaf(s)]=k end
 local buildings={};for k,s in pairs(V.SourceBuildings)do buildings[leaf(s)]=k end
 for _,d in pairs(D)do local path=(d.customParams or{}).source_entity
  if path and path:find('attrib/ebps/races/orks/',1,true)==1 then
   local name=leaf(path);local k=buildings[name]or name;buildings[name]=k
   V.SourceBuildings[k]=path:gsub('^attrib/','');V.DefaultBindings[k]=d.name
  end
 end
 for k,p in pairs(F.profiles)do
  assert(not V.SourceProfiles[k],'Primary research duplicated');p.requires_whole_consumer=true
  V.SourceProfiles[k]=p;V.ResearchProducers[k]=buildings[leaf(p.source_producers[1])]or p.producer
  local cond={buildings={},research={},not_research={}};local seen={}
  local function add(t,s)if not seen[t..':'..s]then cond[t][#cond[t]+1]=s;seen[t..':'..s]=true end end
  for _,r in ipairs(p.requirements)do local f=r.fields
   if r.type=='required_total_pop'then cond.population=math.max(cond.population or 0,f.population_required or 0)
   elseif r.type=='required_structure'then add('buildings',buildings[leaf(f.structure_name)]or('__missing_source_building_'..leaf(f.structure_name)))
   elseif (r.type=='required_global_addon'or r.type=='global_required_addon')then
    if leaf(f.global_addon_name)=='ork_hq_addon'then cond.global_addon='ork_source_hq_addon'else p.requirement_consumer_missing=r.type..':'..tostring(f.global_addon_name)end
   elseif r.type=='required_research'then
    local key=sourceKeys[leaf(f.research_name)]or('__missing_source_research_'..leaf(f.research_name));add(f.research_must_not_be_complete and'not_research'or'research',key)
   elseif r.type~='required_none'then p.requirement_consumer_missing=r.type end
  end
  V.ResearchConditions[k]=cond
 end
 V.PrimaryResearchFacts=F;return F
end
return M
