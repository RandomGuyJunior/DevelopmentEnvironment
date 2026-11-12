-- Projectile-attached presentation using the native BAR/Dakkajet jet atlas,
-- Perlin distortion and white-core colour formula. No simulation writes.
return function(g)
 local cfg=VFS.Include('luarules/configs/bar40k_grotbomb_exhaust.lua')
 local active={};local shader,timeUniform
 local fragment=[[
 #version 120
 uniform sampler2D noiseMap;
 uniform sampler2D mask;
 uniform float frameTime;
 void main(){
  vec2 cellUV=gl_TexCoord[0].st;
  vec2 displacement=cellUV+vec2(0.0,frameTime*0.1);
  float distortion=texture2D(mask,vec2(cellUV.s/8.0,cellUV.t)).g*0.01;
  vec2 txCoord=cellUV;
  txCoord.s+=(texture2D(noiseMap,displacement*0.01*20.0).y-0.5)*40.0*distortion;
  txCoord.t+=texture2D(noiseMap,displacement).x*(1.0-cellUV.t)*15.0*distortion;
  float opac=texture2D(mask,vec2(clamp(txCoord.s,0.0,1.0)/8.0,txCoord.t)).r;
  if(opac<=0.0)discard;
  float opac2=opac*opac;
  gl_FragColor=clamp(vec4(opac*vec3(.7,.4,.1)+vec3(opac2*opac2*opac),opac*1.5),0.0,1.0);
 }
 ]]
 local function ignite(_,id)active[id]=true end
 function g:Initialize()
  if not gl or not gl.CreateShader then return end
  shader=gl.CreateShader({fragment=fragment,uniformInt={noiseMap=0,mask=1}})
  if not shader then Spring.Echo('Grot bomb jet shader:',gl.GetShaderLog());return end
  timeUniform=gl.GetUniformLocation(shader,'frameTime')
  gadgetHandler:AddSyncAction('bar40k_grotbomb_ignite',ignite)
 end
 function g:Shutdown()
  gadgetHandler:RemoveSyncAction('bar40k_grotbomb_ignite')
  if shader then gl.DeleteShader(shader)end
 end
 function g:DrawWorld()
  if not shader then return end
  local cx,cy,cz=Spring.GetCameraPosition();local t=Spring.GetFrameTimeOffset()
  gl.DepthTest(true);gl.DepthMask(false);gl.Culling(false);gl.Blending(GL.SRC_ALPHA,GL.ONE)
  gl.Texture(0,'bitmaps/gpl/perlin_noise.jpg');gl.Texture(1,'luaui/images/jet_atlas.tga');gl.UseShader(shader)
  gl.Uniform(timeUniform,Spring.GetGameFrame()+t)
  for id in pairs(active)do
   -- Unsynced native read respects projectile visibility; no hidden locations
   -- or targeting information are sent through the sync action.
   local x,y,z=Spring.GetProjectilePosition(id)
   if not x then active[id]=nil else
    local dx,dy,dz=Spring.GetProjectileDirection(id);local vx,vy,vz=Spring.GetProjectileVelocity(id)
    if dx and vx then
     -- Same native draw interpolation and MissileProjectile model offset.
     x,y,z=x-vx*(1-t),y-vy*(1-t),z-vz*(1-t)
     local rx,ry,rz=dz,0,-dx;local length=math.sqrt(rx*rx+rz*rz)
     if length<1e-6 then rx,ry,rz,length=-1,0,0,1 end
     rx,ry,rz=rx/length,ry/length,rz/length
     local ux,uy,uz=dy*rz-dz*ry,dz*rx-dx*rz,dx*ry-dy*rx
     local off=cfg.offset;local forward=off[3]+cfg.nativeMissileDrawOffset
     x,y,z=x+rx*off[1]+ux*off[2]+dx*forward,y+ry*off[1]+uy*off[2]+dy*forward,z+rz*off[1]+uz*off[2]+dz*forward
     local ax,ay,az=-dx,-dy,-dz
     local tx,ty,tz=cx-x,cy-y,cz-z
     local wx,wy,wz=ty*az-tz*ay,tz*ax-tx*az,tx*ay-ty*ax
     local width=math.sqrt(wx*wx+wy*wy+wz*wz)
     if width>1e-6 then
      wx,wy,wz=wx/width*cfg.width,wy/width*cfg.width,wz/width*cfg.width
      local ex,ey,ez=x+ax*cfg.length,y+ay*cfg.length,z+az*cfg.length
      gl.BeginEnd(GL.QUADS,function()
       gl.TexCoord(0,1);gl.Vertex(x-wx,y-wy,z-wz)
       gl.TexCoord(1,1);gl.Vertex(x+wx,y+wy,z+wz)
       gl.TexCoord(1,0);gl.Vertex(ex+wx,ey+wy,ez+wz)
       gl.TexCoord(0,0);gl.Vertex(ex-wx,ey-wy,ez-wz)
      end)
     end
    end
   end
  end
  gl.UseShader(0);gl.Texture(1,false);gl.Texture(0,false)
  gl.Blending(GL.SRC_ALPHA,GL.ONE_MINUS_SRC_ALPHA);gl.DepthMask(true);gl.DepthTest(false)
 end
end
