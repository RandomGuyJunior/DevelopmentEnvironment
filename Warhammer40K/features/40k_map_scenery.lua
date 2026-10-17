-- Native destructible scenery shared by the private40K map pack.
-- Generated dimensions contain metadata only; authentic meshes/textures stay ignored.
local dimensions=VFS.Include("40k_reference/scenery_dimensions.lua")
local roles={
 gothic_wall={"Broken cathedral wall",650,25},
 gothic_rubble={"Cathedral rubble",120,5},
 imperial_wall={"Damaged Imperial fortification",750,25},
 marine_statue={"Broken Astartes memorial",500,15},
 judgment_statue={"Imperial judgment monument",600,20},
 oil_drum={"Abandoned promethium drums",80,8},
 supply_crate={"Imperial supply crate",100,8},
 twisted_metal={"Manufactorum wreckage",180,12},
}
local definitions={}
local function definition(key,description,health,metal,dead)
 local d=assert(dimensions[key],"Missing copied scenery dimensions: "..key)
 assert(d.x>0 and d.y>0 and d.z>0)
 return {
  name="40k_"..key,description=description,object=key..".glb",
  blocking=true,indestructible=false,health=health,damage=health,
  reclaimable=true,autoreclaimable=true,resurrectable=0,
  metal=metal,energy=0,reclaimtime=math.max(60,metal*6),
  footprintx=math.max(1,math.ceil(d.x/16)),footprintz=math.max(1,math.ceil(d.z/16)),
  collisionvolumetype="Box",collisionvolumescales=d.x.." "..d.y.." "..d.z,
  collisionvolumeoffsets="0 0 0",collisionvolumetest=1,
  featuredead=dead,customparams={prototype_40k_scenery=true,source_dow=true},
 }
end
for key,role in pairs(roles) do
 definitions["40k_"..key]=definition(key,role[1],role[2],role[3],"40k_rubble_remnant")
end
definitions["40k_rubble_remnant"]=definition("gothic_rubble","Destructible rubble remnant",40,2,"")
definitions["40k_rubble_remnant"].name="40k_rubble_remnant"
return definitions
