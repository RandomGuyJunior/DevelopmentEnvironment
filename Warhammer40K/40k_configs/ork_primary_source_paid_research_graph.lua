-- Concrete source-paid research graph consumed by existing paid_research_runtime.
-- Whole effects stay suppressed until its real RegisterEffectHandler path is bound.
local M={Version=1}
function M.Graph(contract)
 local graph={Build={},Requires={},Research={}};local mapping={}
 for key,facts in pairs(contract.actors)do
  for _,research in pairs(facts.research_contract or {})do
   local source=research.virtual;local stem=source:match('([^/]+)%.lua$');local id=key..'__'..stem
   if not mapping[id]then
    local f=research.fields;local time=f['time_cost.time_seconds']
    assert(type(time)=='number'and time>0,'Source paid research time missing: '..source)
    graph.Research[#graph.Research+1]={name=id,producer=key,cost={metal=f['time_cost.cost.requisition']or 0,energy=(f['time_cost.cost.power']or 0)*5},time=time,requires_effect_handler=true,source_research=source,source_sha256=research.sha256}
    mapping[id]=research
   end
  end
 end
 table.sort(graph.Research,function(a,b)return a.name<b.name end)
 return graph,mapping
end
function M.Bind(controller,mapping,wholeSourceConsumerReady)
 local opened={}
 for id,source in pairs(mapping)do
  if wholeSourceConsumerReady(id,source)==true and controller.RegisterEffectHandler(id)then opened[#opened+1]=id end
 end
 table.sort(opened);return opened
end
return M
