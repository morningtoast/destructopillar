pico-8 cartridge // http://www.pico-8.com
version 17
__lua__
-- destructopillar
-- 2019, brian vaughn @morningtoast

--[[

bookmarks:
#loop		Main loop; _init/_update/_draw
#intro		Level intro where map is generated and vars are set
#map		Map generation
#level		Level configuration
#house		House object
#tank		Tank enemy object
#heli		Helicopter enemy object
#play		Main gameplay loop
#draw		Standalone draw routines; snake,map,ui
#exit		Exit arrow 
#guns		Bullets and emitters
#food		Fruit drop
#utility	Utility and support functions


main tables:
houses		Buildings (can be very big)
snake		Player snake segments
tailpath	Placement coordinates for snake segments
roads		Road spritemaps
mobs		Enemies
bullets		Bullets and other effects

]]

-- looks for a type of map and replaces it with another; only 1 at a time
-- ex: swap_map("empty","water1") == replaces 1 random empty map with a water map
function swap_map(lookfor,replacewith)
	local grab={}
	foreach(roads,function(v)
		if v.road==lookfor then add(grab,cp_table(v)) end
	end)

	local g=trandom(grab)
	local new={mx=g.mx,my=g.my,road=replacewith}

	foreach(roads,function(v)
		if v.mx==g.mx and v.my==g.my then del(roads,v) end
	end)

	add(roads,new)

	for k,v in pairs(roads) do
		local my,mx,road=v.my,v.mx,v.road
		
		if replacewith=="tleft" then
			if my==g.my then
				if mx!=g.mx and mx<g.mx  then
					if road=="empty" then roads[k].road="horz" end
					if road=="vert" then roads[k].road="center" end
				end
			end
		end

		if replacewith=="tright" then
			if my==g.my then
				if mx!=g.mx and mx>g.mx  then
					if road=="empty" then roads[k].road="horz" end
					if road=="vert" then roads[k].road="center" end
				end
			end
		end

		if replacewith=="tup" then
			if mx==g.mx then
				if my!=g.my and my<g.my  then
					if road=="empty" then roads[k].road="vert" end
					if road=="horz" then roads[k].road="center" end
				end
			end
		end

		if replacewith=="tdown" then
			if mx==g.mx then
				if my!=g.my and my>g.my  then
					if road=="empty" then roads[k].road="vert" end
					if road=="horz" then roads[k].road="center" end
				end
			end
		end
	end
end

-- #map generation
function generate_map()
	printh("_generating map....")
	map_size=map_w*map_h
	
	local sourcex=flr(rnd(map_w))+1
	local sourcey=flr(rnd(map_h))+1
	
	roads={}
	add(roads,{mx=sourcex,my=sourcey,road="center"}) --seed map with town center
	
	-- add initial horz/vert based on seed center square
	for mapx=1,map_w do
		for mapy=1,map_h do
			local space=false
			
			printh("checking "..mapx..","..mapy)
			
			if mapy!=sourcey and mapx!=sourcex then space="empty" end
			if mapy==sourcey and mapx!=sourcex then space="horz" end
			if mapx==sourcex and mapy!=sourcey then space="vert" end
			
			if space then
				add(roads,{mx=mapx,my=mapy,road=space})
			end
		end
	end
	
	-- add in road splits and extends
	if map_size>=9 then
		swap_map("horz",trandom({"tup","tdown"}))
		swap_map("vert",trandom({"tleft","tright"}))
	end
	
	if map_size>=12 then
		swap_map("horz",trandom({"tup","tdown"}))
		swap_map("vert","vfactory")
	end
	
	if map_size>=16 then
		swap_map("vert",trandom({"tleft","tright"}))
		swap_map("horz","hfactory")
		swap_map("vert","vfactory")
	end
	
	
	foreach(roads,function(v)
		local secx,secy=(v.mx-1)*128,(v.my-1)*128
		local sheetx,sheety=-1,-1
		local sheetw,sheeth=15,15
		local skipchance=.2
		local xoffset,yoffset=0,0
		local road=v.road
			
			
		-- build quad array
		for n=1,4 do houses[v.mx..","..v.my..","..n]={} end
			
		
		if road=="center" then 
			sheetx,sheety=48,0
			skipchance=0
		end
		
		if road=="tright" then 
			sheetx,sheety=112,0
		end
		
		if road=="tleft" then 
			sheetx,sheety=96,0
		end
		
		if road=="tup" then 
			sheetx,sheety=64,0
		end
		
		if road=="tdown" then 
			sheetx,sheety=80,0
		end
		
		if road=="hfactory" then 
			sheetx,sheety=80,16
			skipchance=0
		end
		
		if road=="vfactory" then 
			sheetx,sheety=96,16
			skipchance=0
		end
		
		if road=="empty" then 
			sheetx,sheety=64,17
			skipchance=.85
		end
		
		if road=="horz" then
			skipchance=.7
			
			if rnd()<.5 then
				-- top
				sheetx,sheety=48,16
				sheetw,sheeth=15,7
			else
				--bottom
				yoffset=9	
				sheetx,sheety=48,24
				sheetw,sheeth=15,7
			end
		end
		
		if road=="vert" then
			skipchance=.7
			if rnd()<.5 then
				-- left
				sheetx,sheety=48,16
				sheetw,sheeth=7,15
			else
				-- right
				xoffset=9
				sheetx,sheety=56,16
				sheetw,sheeth=7,15
			end
		end
			
		--if 
			
			
		
		--houses[v.mx..","..v.my..","..quad]={}
		
		if sheetx>=0 then
			for i=xoffset,sheetw+xoffset do
				local gx=sheetx+i

				for j=yoffset,sheeth+yoffset do
					local gy=sheety+j
					local mapspr=mget(gx,gy) --map sprite
					
					-- random chance that house gets skipped
					--if mapspr==91 then skipchance=.6 end --reduce chance for watch towers
					if rnd()<skipchance then mapspr=0 end
					
					
					-- #house
					local obj={
						timer=objtimer,
						x=secx+8*i,
						y=secy+8*j,
						spr=0,
						hp=100,hpx=100,
						w=0,h=0,
						st=1,
						bash=false,
						smoke={},
						hb={x=0,y=0,w=8,h=8},
					}
							
					
						
					-- sets properties for house type
					-- set_props(spriteTable,tileWidth,tileHeight,maxHP,maxPopulation)
					function set_props(spr,w,h,hpx,pop)
						local spr=split(spr)
						local obj={
								spr=trandom(spr),
								w=w,h=h,
								hpx=max(20,random(flr(hpx-hpx*.3), hpx)),
								pop=max(3,random(flr(pop-pop*.7), pop)),
								hb={x=0,y=0,w=w*8,h=h*8}
						}
							
						obj.hp=obj.hpx
						
						pop_quota+=obj.pop --total population for level
							
						return obj
					end
						
						
					if obj.x>=secx+64 then
						if obj.y>=secy+64 then quad=4 else quad=2 end
					else
						if obj.y>=secy+64 then quad=3 else quad=1 end	
					end
						
					
					
					-- look at placement tile and see what kind it is, then populate with properties
					if mapspr>0 then
						local props=false
						if mapspr==53 then props=set_props("9;10;11",1,1,40,10) end --1x1 fac
						if mapspr==7 then props=set_props("44;46",2,2,220,150) end --2x2 fac
						if mapspr==40 then props=set_props("88",2,1,100,50) end --2x1 fac
						if mapspr==37 then props=set_props("27;42;43",1,1,70,30) end --1x1 biz
						if mapspr==38 then props=set_props("12;14;78;76",2,2,150,100) end -- 2x2 biz
						if mapspr==36 then props=set_props("58;59",1,2,100,50) end -- 1x2 biz
						if mapspr==20 then props=set_props("25;26",1,1,30,10) end -- 1x1 res
						if mapspr==5 then props=set_props("70",2,2,100,100) end -- 2x2 res
						--if mapspr==91 then props=set_props("91",1,2,150,5) end -- watch tower 1x2 
							
						

						printh("add to sector "..v.mx..","..v.my.. "("..secx..","..secy..") at "..obj.x..","..obj.y.." which is quad "..quad)
							
						if props then
							obj=table_merge(obj,props)
							add(houses[v.mx..","..v.my..","..quad],obj)
						end
					end
				end
			end
		end
	end)	
end




-- #food
function meter_up(amt,x,y)
	meter_now=min(meter_max,meter_now+amt)
	if meter_now>=meter_max then
		add_food(x,y)
		meter_now=0
	end
	
end


function add_food(x,y)
	local pool=split("1;2;3;4;5")
	local atype,gfx=tonum(trandom(pool)),64
	printh("fruit is "..atype)
	-- convert sprite into gun ID
	if atype==1 then gfx=64 end
	if atype==2 then gfx=81 end
	if atype==3 then gfx=66 end
	if atype==4 then gfx=82 end
	if atype==5 then gfx=80 end
	
	
	local obj={
		x=x,y=y,at=atype,spr=gfx,base=y+5,st=1,timer=objtimer,
		hb={x=0,y=0,w=8,h=8},
		_update=function(me)
			if me.st==1 then
				me.dy+=.25 --gravity

				if me.y>=me.base then
					me.y,me.dy,me.dx=me.base,0,0
					me.st=2
				end
			end
			
			if me.st==2 then
				if collide(me.x,me.y,me.hb, hx,hy,hhb) then
					snake_len+=1
					add(snake,snake_props(me.at))
					del(bullets,me)
					
					-- heal segments a bit
					foreach(snake,function(s) s.hp=min(hpmax, s.hp+2) end)
				end
				
				if me:timer(.8,"hop") then
					_,me.dy=dir_calc(.25,3)
				end
				
				if me.dy!=0 then me.dy+=.4  end --gravity
				
				if me.y>me.base then
					me.y=me.base
					me.dx,me.dy=0,0
					me.hop=t()
				end
				
				if me:timer(6) then del(bullets,me) end
			end
			
			me.y+=me.dy
			me.x+=me.dx
		end,
		_draw=function(me)
			if me.st==2 then
				fillp(0b1010010110100101.1) --shadow checkered
				circfill(me.x+4,me.base+5,4,1)	
				fillp()
			end
			spr(me.spr,me.x,me.y)
			--debug_hitbox(me.x,me.y,me.hb)
		end
	}
	
	
	
	
	obj.dx,obj.dy=dir_calc(nrnd(.05)+.25,3.6)
	
	add(bullets,obj)
end


-- #mobs


-- #tanks
function add_jeep(x,y,sst)
	printh("add jeep at "..x..","..y)
	create_tank(x,y,{
		st=sst,sprh=67,sprv=83,spr_w=1,spr_h=1,off=3,wait=3,hp=15,px=7,
		spd=.4,mode=1,
		hb={x=-3,y=-3,w=6,h=6},
		radar={x=-32,y=-32,w=64,h=64},
		attack={qty=3,pow=.5,between=10}
	})
end

function add_light(x,y,sst)
	printh("add_light at "..x..","..y)
	create_tank(x,y,{
		st=sst,sprh=108,sprv=109,spr_w=1,spr_h=1,off=4,wait=4,hp=25,px=8,
		spd=.35,mode=2,
		hb={x=-4,y=-4,w=8,h=8},
		radar={x=-32,y=-32,w=64,h=64},
		attack={qty=3,pow=1,between=0,aiminc=.0625}
	})
end


function add_heavy(x,y,sst)
	printh("add_heavy at "..x..","..y)
	create_tank(x,y,{
		st=sst,sprh=110,sprv=124,spr_w=2,spr_h=2,off=8,wait=5,hp=55,px=11,
		spd=.2,mode=3,
		hb={x=-5,y=-5,w=10,h=10},
		radar={x=-45,y=-45,w=90,h=90},
		attack={qty=4,pow=1,between=0,aiminc=.03125}
	})
end


function create_tank(x,y,config)
	local obj={
		x=x,y=y,dx=0,dy=0,timer=objtimer,tank=true,bash=false,dir=0,fx=0,fy=0,tdir=1,laser=false,
		dmg=false,dmgt=0,
		_update=function(me)
			function get_dir(find)
				local find=find or 0
				local dir,spr,fx,fy,hv,vf=0,1,0,0,false,false
				if (find>=0 and find<.125) or (find>=.875 and find<=1) then dir=0 spr=me.sprh fx=me.px end
				if find>=.375 and find<.625 then dir=.5 spr=me.sprh fx=-me.px hf=true end
				
				if find>=.125 and find<.375 then dir=.25 spr=me.sprv fy=-me.px vf=true end
				if find>=.625 and find<.875 then dir=.75 spr=me.sprv fy=me.px end
				
				--printh("player at "..find.." so head "..me.dir)
				
				me.dir,me.spr,me.fx,me.fy,me.hv,me.vf=dir,spr,fx,fy,hv,vf
			end
			
			me.x+=me.dx
			me.y+=me.dy
			
			local me_x,me_y=me.x,me.y
			
			me.turret=atan2(hx-me_x, hy-me_y)
			
			if me.laser then 
				me.hp-=.025
				me.laser=false
				me.dmg=true
			end
			
			-- snake damage; trample and head bashing
			me.hp-=trample_damage(me_x,me_y,me.hb)
			if collide(me_x,me_y,me.hb, hx,hy,hhb) then
				 if not me.bash then
					me.bash=true
					me.dmg=true
					me.hp-=bashpow
					expl_create(hx,hy,20,1,{rad=4,colors="7;8;9;10;5;6;13"})
				end
			else
				me.bash=false
			end
			
			if me.hp<=0 then
				meter_up(me.mode,me_x,me_y)
				big_explode(me_x,me_y)
				tank_count-=1
				del(mobs,me)
			end
			
			if me.st==0 then
				if inrange(me_x,me_y) then me.st=1 end
			end
			
			-- find player and head in that direction
			if me.st==1 then
				me.recalc=rnd(2)+1
				get_dir(me.turret)
				me.dx,me.dy=dir_calc(me.dir,me.spd)
				me.st=2
			end
			
			-- move towards player
			if me.st==2 then
				if me:timer(me.recalc) then me.st=1 end
				
				local blocked,frontx,fronty=false,me_x+me.fx,me_y+me.fy
				
				
				-- if player is in radar, stop and shoot
				 
				if in_box(hx,hy, me_x,me_y,me.radar) then --radar
					me.dx,me.dy=0,0
					me.st=99
					me.t=t() --forced reset of timer
				else
					-- check if blocked by edge, building or other tank
					if (frontx<=0 or frontx>=map_w*128) or (fronty<=0 or fronty>=map_h*128) then
						blocked=true
					else
						for _,h in pairs(houses) do
							if collide(frontx,fronty,me.hb, h.x,h.y,h.hb) then
								blocked=true
								break
							end
						end
						
						if not blocked then
							foreach(mobs,function(o)
								if o.tank and o!=me then
									if collide(frontx,fronty,me.hb, o.x,o.y,o.hb) then
										blocked=true
									end
								end
							end)
						end
					end
					
					
					if blocked then
						me.dir=abs(me.dir+.25*me.tdir)
						printh("turn to "..me.dir)
						me.dx,me.dy=dir_calc(me.dir,me.spd)
						get_dir(me.dir)
						me.recalc=rnd(2.5)+1
						me.st=3
						me.t=t()
					end
				end
				
				
			end
			
			--quick sleep after bump to avoid double collision
			--sleep after shooting, 3s between shots
			if me.st==3 and me:timer(rnd()) then 
				me.st=1 
			end 
			
			if me.st==99 and me:timer(.75) then --stop and wait a sec
				me.gun=add_gunemit(me_x,me_y,me.attack)
				me.st=98
			end
			
			if me.st==98 and me:timer(me.wait) then me.st=1 end --stop and wait a sec
			
			
			if me:timer(25,"life") then me.st=0 end --after 25s, deactivate and wait
			
			dmg_flash(me)
		end,
		_draw=function(me)
			fillp(0b1010010110100101.1) --checkered shadow
			circfill(me.x,me.y,4,1)	
			fillp()
			
			if me.dmg then spr_flash() end
			
			spr(me.spr,me.x-me.off,me.y-me.off,me.spr_w,me.spr_h,me.hv,me.vf)
			
			if me.mode>1 then
				local mx,my=get_line(me.x,me.y,7,me.turret)
				line(me.x,me.y, mx,my, 14) -- turret
			end
			pal()
			
			local frontx,fronty=me.x+me.fx,me.y+me.fy
			--pset(me.x,me.y,10)
			--pset(frontx,fronty,10)
			--debug_hitbox(me.x,me.y,me.hb)
			--debug_hitbox(frontx,fronty,me.hb,9)
			--debug_hitbox(me.x,me.y,me.radar,5)
			
			--print(me.hp,me.x,me.y,y)
		end
	}
	
	if yesno() then obj.tdir=-1 end
	
	
	obj=table_merge(obj,config)
	
	obj.hp+=mobhp_inc*obj.hp
	obj.spr=obj.sprh
	
	tank_count+=1
	
	add(mobs,obj)
	
	--return obj
end






-- #heli
-- states:1=towards player;2=inrange,shoot;3=fly away
function add_heli()
	local obj={
		heli=true,
		st=0,timer=objtimer,life=t(),hp=45,dmg=false,dmgt=0,f=0,laser=false,
		radar={x=-46,y=-46,w=92,h=92}, --finds player
		push={x=-15,y=-15,w=30,h=30}, --avoiding others
		hb={x=-8,y=-8,w=16,h=16}, --hitbox
		_update=function(me)
			function die()
				heli_count=max(0,heli_count-1)
				del(mobs,me)
			end
			
			local spd,avoid_angle,me_x,me_y=.48,0,me.x,me.y
			
			if me.st==0 then
				me.dx,me.dy,me.dir=to_target(me_x,me_y,hx,hy,spd)
				me.st=1
			end
			
			-- avoiding other helis and looking for player
			if me.st==1 then
				if in_box(hx,hy, me_x,me_y,me.radar) then
					me.st=2
					me.t=t()
				else
					foreach(mobs,function(other)
						if other.heli and other!=me then
							if in_box(other.x,other.y, me_x,me_y,me.push) then
								avoid_angle=.24*me.adir
							end
						end
					end)

					me.dir+=avoid_angle
					me.dx,me.dy=dir_calc(me.dir,spd)
					me.dir=atan2(hx-me_x, hy-me_y)
				end
			end
			
			-- stop and shoot
			if me.st==2 and me:timer(.5) then
				me.gun=add_gunemit(me_x,me_y,{qty=3,pow=1,between=10,bullet=add_mobshot,target=target_snake})
				
				me.dx,me.dy=0,0
				me.st=3
			end
			
			
			-- wait after shooting before restarting
			if me.st==3 and me:timer(2) then 
				me.dx,me.dy,me.dir=to_target(me_x,me_y,hx,hy,spd)
				me.st=1 
			end
			
			if me.st==4 and not inrange(me_x,me_y) then die() end

			
			if me.laser then me.hp-=.025 end
			
			-- health death
			if me.hp<=0 then
				big_explode(me_x,me_y)
				meter_up(4,me_x,me_y)
				
				if guns[me.gun] then del(guns,guns[me.gun]) end
				die()
			end
			
			
			if me:timer(45) and me.st<4 then
				me.dx,me.dy=dir_calc(rnd(),1)
				me.st=4
			end
			
			-- always actions
			me.x+=me.dx
			me.y+=me.dy
			
			
			dmg_flash(me)
		end,
		_draw=function(me)
			local me_x,me_y=me.x,me.y
			
			if inrange(me_x,me_y) then
				fillp(0b1010010110100101.1) --checkered shadow
				circfill(me_x,me_y,4,1)	
				fillp()
				
				if me.dmg then spr_flash() end
				
				local find=atan2(me_x-12-hx, me_y-12-hy)
				rspr(1,7, me_x-12,me_y-12, find*-1, 3, 0)
				
				-- rotor blades
				if fps%5==0 then
					--local r=rnd()
					--local la,lb=get_line(me_x,me_y,7,r)
					--local lc,ld=get_line(me_x,me_y,7,r+.5)
					
					circ(me_x,me_y, 3,7)
					circ(me_x,me_y, 7,7)
					--line(la,lb,lc,ld,7)
					me.f=0
				end
				pal()

				--me.f+=1
			end
			--debug_hitbox(me_x,me_y,me.push)
		end
	}
	
	obj.x,obj.y=get_line(hx,hy,130,rnd()) -- get random spot just outside of range
	if yesno() then obj.adir=-1 else obj.adir=1 end
	obj.hp+=mobhp_inc*obj.hp
	
	heli_count+=1
	
	add(mobs,obj)
end


-- #damage and #effects
function trample_damage(x,y,hb)
	local damage=0
	foreach(snake,function(s)
		if collide(s.x,s.y,s.hb, x,y,hb) then damage+=s.trample end
	end)
	
	return damage
end	

function big_explode(x,y)
	expl_create(x,y, 16, 1, {rad=8,dur=90,dir=.25,range=.25,smin=1,smax=3,grav=.3,colors="7;8;9;10;2;5",fill="0b1010010110100101.1"})
end

function blood_explode(x,y)
	expl_create(x,y, 20, 1, {rad=6,dur=90,smin=1,smax=3,grav=.3,colors="2;8;14;15"})
end


-- #guns and #bullets
--,bullet=add_mobshot,target=target_snake

function target_snake()
	if yesno() and #snake>0 then
		local t=trandom(snake)
		return t.x,t.y
	else
		return hx,hy
	end
end


function add_gunemit(x,y,options)
	local options=options or {qty=3,between=15,aim=.25}
	
	local obj={
		x=x,y=y,t=0,
		_update=function(me)
			if me.t==0 then
				
				add_mobshot(me.x,me.y,me.aim,me)
				me.qty-=1
				
				if me.aiminc then me.aim+=me.aiminc end
			end
			me.t+=1
			if me.t>me.between then me.t=0 end
			if me.qty<=0 then del(guns,me) end
		end
	}
	
	-- apply custom settings
	obj=table_merge(obj,options)
	-- make it an equal spread if no delay between shots
	local tx,ty=target_snake()
	obj.aim=atan2(tx-obj.x, ty-obj.y)
	
	if obj.between==0 and obj.aiminc then
		local h=flr(obj.qty/2)
		for n=1,h do obj.aim-=obj.aiminc end
	end
	

	add(guns,obj)
end



function add_mobshot(x,y,aim,owner)
	local obj={
		x=x,y=y,c=1,colors={7,8,14},owner=owner,
		hb={x=0,y=0,w=4,h=3},
		_update=function(me)
			me.x+=me.dx
			me.y+=me.dy
			
			local me_x,me_y=me.x,me.y
			
			foreach(snake,function(s)
				if collide(s.x,s.y,s.hb, me_x,me_y,me.hb) then
					s.hp-=me.owner.pow
					s.dmg=true
					del(bullets,me)
				end
			end)
			
			if collide(me_x,me_y,me.hb, hx,hy,hhb) then
				--life-=1
				hhit=1
				del(bullets,me)
			end
			

			if not inrange(me_x,me_y) or offmap(me_x,me_y) then
				del(bullets,me)
			end
			
			if me.c>#me.colors then me.c=1 else me.c+=1 end
		end,
		_draw=function(me)
			pal(8,me.colors[me.c])
			pal(10,14)
			if me.owner.pow<1 then
				circfill(me.x,me.y,1,14)
				pset(me.x,me.y,15)
			else
				spr(48, me.x,me.y)
			end
			pal()
		end
	}
	
	obj.dx,obj.dy=dir_calc(aim,1.3) --bullet speed
	
	add(bullets,obj)
end

function add_bullet(btype, x,y,aim)
	local obj={
		spr=48,x=x,y=y,c=1,colors={7,7,1,1,13,13},aim=aim,type=btype,dmg=1,
		hb={x=0,y=0,w=3,h=3},
		_update=function(me)
			me.x+=me.dx
			me.y+=me.dy
			
			local me_x,me_y=me.x,me.y
			
			foreach(mobs,function(m)
				if collide(m.x,m.y,m.hb, me_x,me_y,me.hb) then
					m.hp-=me.dmg
					m.dmg=true
					del(bullets,me)
				end
			end)

			if not inrange(me_x,me_y) or offmap(me_x,me_y) then  
				del(bullets,me)
			end
			
			if me.c>#me.colors then me.c=1 else me.c+=1 end
		end,
		_draw=function(me)
			pal(13,me.colors[me.c])
			spr(me.spr, me.x,me.y)
			pal()
		end
	}

	obj.dx,obj.dy=dir_calc(aim,1.4) --bullet speed
	
	if btype==3 then
		obj.spr=106
		obj.dmg=3
		obj.hb={x=0,y=0,w=5,h=5}
	end
	
	if btype==5 then
		obj.dmg=2
		obj.hb={x=0,y=0,w=5,h=5}
	end
	
	add(bullets,obj)
end



function snake_update(me)
		local me_x,me_y=me.x,me.y

		-- find nearest mob and see if it's in range
		me.nearest=false
		local nearest_d=999
		local gun_range=60 --default range for bullets/spread

		if me.at==3 then gun_range=80 end --canon
		if me.at==4 then gun_range=55 end --laser

		if me.at>1 then
			foreach(mobs,function(b)
				if inrange(b.x,b.y) then
					local d=flr(distance(me_x,me_y, b.x,b.y))

					if d<nearest_d and d<gun_range and d>12 then --attack range
						me.nearest=b
						nearest_d=d
					end
				end
			end)
		end

		-- if there is a mob within range, shoot corresponding weapon
		if me.nearest then
			local nx,ny=me.nearest.x,me.nearest.y
			local target_ang=atan2(nx-me_x, ny-me_y)


			-- straight bullets
			if me.at==2 then
				if me:timer(me.br) then
					add_bullet(2, me_x,me_y, target_ang+nrnd(.03))
				end
			end

			-- canon
			if me.at==3 and nearest_d>20 then
				if me:timer(me.br) then
					add_bullet(3, me_x,me_y, target_ang)
				end
			end

			-- laser
			if me.at==4 then
				me.nearest.laser=true
			end

			-- spread
			if me.at==5 then
				if me:timer(me.br) then
					local aim=me.a

					add_bullet(5, me_x,me_y, aim+.25)
					add_bullet(5, me_x,me_y, aim+.3125)
					add_bullet(5, me_x,me_y, aim+.1875)
					add_bullet(5, me_x,me_y, aim-.25)
					add_bullet(5, me_x,me_y, aim-.3125)
					add_bullet(5, me_x,me_y, aim-.1875)
				end
			end


		end

		if me.hp<=0 then
			snake_len-=1
			while #tailpath>=snake_len*seg_dist do del(tailpath,tailpath[1]) end
			blood_explode(me.x,me.y)

			foreach(snake,function(s)
				if s.id>me.id then
					s.id=max(me.id,s.id-1)
				end
			end)


			del(snake,me)
		end

		dmg_flash(me)	
end


-- #snake 
-- segment properties; called when adding a new segment
-- attackType: 1=basher, 2=bullet, 3=canon, 4=laser, 5=spread
function snake_props(attackType)
	local attackType=attackType or 1
	
	local obj={
		at=attackType,
		x=hx,y=hy,a=hang,timer=objtimer,hp=hpmax,hpx=hpmax,canshoot=false,dmg=false,dmgt=0,trample=.15,
		hb={x=-3,y=-3,w=6,h=6},nearest=false,
		_update=snake_update
	}
	
	obj.br=rnd(.5)+.1 --base bullet rate for basic shot
	
	if attackType==1 then obj.trample=.25 end --increased trample for apple
	if attackType>=3 then obj.br=rnd()+.5 end --canon bullet rate
	--if attackType==5 then obj.br=rnd()+2 end --spread bullet rate
	
	--debug
	obj.id=#snake+1
	
	--printh("snake ID is "..obj.id)
	
	return obj
end



-- #scenes
-- title screen + menu
scene_title={
	_init=function()
		game_level=1
	end,
	_update=function()
		if btnrp or btnlp then
			_scene(scene_intro)
		end
	end,
	_draw=function()
		rectfill(0,0,127,127,3)
		printc("destructopillar;;;;press \139 or \145 tp start",20,7)
		
	end
}

-- level #intro
-- map generation + show bonus house and messages
scene_intro={
	_init=function()
		hx,hy,hdx,hdy=0,0,0,0
		hhit,hang=0,-1 --hang: -1 is stopped, for level start only
		hhb={x=-3,y=-3,w=6,h=6}
		
		meter_max,meter_now=40,25 --meter quota/current
		
		hspeed,seg_dist=.7,10 --speed+distance; faster=more distance > .85=8
		bashpow=10 --power for head crashing into building
		life,hpmax=15,8 --hp per snake segment
		
		tailpath,mobs,guns,bullets,roads,houses={},{},{},{},{},{}
		pop_quota,pop_now=0,0 --used for limiting drawing of particles
		
		-- #level configuration
		--title,mapWidth,mapHeight,heliMax,tankMax,tankIdPool,mobHpIncreasePerLevel
		local levels={
			"demo;.01;5;5;2;3;1,2,3;0",
			"village;.01;2;2;0;3;1;0",
			"town;.5;3;3;1;5;1,2;.1"
		}
		
		local level_cfg=split(levels[game_level])
		
		level_title=level_cfg[1]
		map_w=tonum(level_cfg[3])
		map_h=tonum(level_cfg[4])
		level_helimax=tonum(level_cfg[5])
		level_tankmax=tonum(level_cfg[6])
		level_tankpool=split(level_cfg[7],",")
		mobhp_inc=tonum(level_cfg[8])
		
		-- for first level only when new game started
		if game_level==1 then
			snake={}
			snake_len=3
			for n=1,2 do add(snake,snake_props()) end
		end
		
		generate_map() --fills roads and houses arrays
		
		-- random empty square for player start
		local grab={}
		foreach(roads,function(v) if v.road=="empty" then add(grab,cp_table(v)) end end)
		local pstart=trandom(grab)
		
		--printh("total pop is "..pop_quota)
		
		pop_quota=flr(pop_quota*tonum(level_cfg[2]))
		
		hx,hy=(pstart.mx-1)*128+60,(pstart.my-1)*128+60
		camx,camy=flr(hx/128)*128,flr(hy/128)*128 --camera screen edge
		camw,camh=camx+127,camy+127
		
		-- heal all segments to start level
		foreach(snake,function(s) s.hp=s.hpx end)
		
		-- places some tanks (heli added during gameplay)
		heli_count,tank_count=0,0
		--place_tanks(level_tankmax)
		
		printh("houses="..#houses)
	end,
	_update=function()
		if btnzp then _scene(scene_play) end
	end,
	_draw=function()
		rectfill(0,0,127,127,3)
		printc("on day "..game_level.." the;very hungry destructopillar;ate a "..level_title..";;destroy buildings and;;to advance",16,7)
		printc("eat "..pop_quota.." people",61,10)
		printc("press <z> to start",110,15)
	end
}


function place_tanks(qty,spawnst)
	printh("putting down tanks: "..qty)
	
	local spawnst=spawnst or 0
	
	while qty>0 do
		local secx,secy=flr(rnd(map_w))+1,flr(rnd(map_h))+1
		local tpw,tph=secx*128,secy*128
		local clear,placex,placey,tries=false,0,0,0

		while not clear and tries<25 do
			clear=true
			placex=random(0,tpw)
			placey=random(0,tph)

			-- avoid placing tank on houses and too close to player
			if inrange(placex,placey) then 
				clear=false 
			else
				for _,h in pairs(houses) do
					if collide(h.x,h.y,h.hb, placex,placey,{x=-12,y=-12,w=24,h=24}) then
						clear=false
						break
					end
				end
				-- avoid placing too close to player
				if clear then
					foreach(mobs,function(m)
						if not m.heli then
							if flr(distance(placex,placey, m.x,m.y))<64 then
								clear=false
							end
						end
					end)
				end
			end

			tries+=1
		end

		if clear then
			local tanktype=tonum(trandom(level_tankpool))
			
			if tanktype==1 then add_jeep(placex,placey,spawnst) end
			if tanktype==2 then add_light(placex,placey,spawnst) end
			if tanktype==3 then add_heavy(placex,placey,spawnst) end
			qty-=1
		end
	end
	
end




-- game #play
scene_play={
	_init=function()
		
		scene={timer=objtimer,helispawn=t()+5}
	end,
	_update=function()
		-- panning barriers; 42=pan distance, less=closer to edge before moving camera
		if flr(hx)<=camx+42 then camx-=1 end
		if flr(hx)>=camx+128-42 then camx+=1 end
		if flr(hy)<=camy+42 then camy-=1 end
		if flr(hy)>=camy+128-42 then camy+=1 end

		camw=camx+127
		camh=camy+127

		hx+=hdx
		hy+=hdy

		-- build tail path, used for placing segments
		--x=x,y=y,a=dirHeading
		--if #tailpath<snake_len*seg_dist then add(tailpath,{x=hx,y=hy,a=hang}) end
		--if snake_len>0 and #tailpath>=snake_len*seg_dist then del(tailpath,tailpath[1]) end
		
		
		-- game starts with player stopped, waiting for direction to move
		if scene_st==1 then
			if btnlp then hang=.5 end
			if btnrp then hang=0 end
			if btnup then hang=.25 end
			if btndp then hang=.75 end

			if hang>=0 then
				hdx,hdy=dir_calc(hang,hspeed)
				scene_st=2
			end
		else
			-- turning
			if (btnl or btnr) and scene_st<4 then 
				if btnr then hang-=.012 else hang+=.012 end
				hdx,hdy=dir_calc(hang, hspeed)
			end
		end
		
		
		--[[place snake segments based on tailpath points
		local snakeseg,p=1,0
		for n=#tailpath,1,-1 do --need to go backwards so new segments are added to end
			if p==seg_dist then
				
				foreach(snake,function(s) --need to use artificial ID because using table index isn't consistent
					if s.id==snakeseg then
						s.x=tailpath[n].x
						s.y=tailpath[n].y
						s.a=tailpath[n].a
						return
					end
				end)
				
				p=0
				snakeseg+=1
			end

			p+=1
		end]]
		
		
		-- normal play for all actors
		if scene_st>1 and scene_st<4 then
			if offmap(hx,hy) then life=0 end
		
			-- if head life is zero, game over
			if life<=0 then
				blood_explode(hx,hy)
				_scene(scene_gameover)
			end
			
			
			
			-- open map exit; pick random place along warning track
			-- exit box is 20px square
			if pop_quota<=0 and scene_st!=3 then
				if yesno() then
					exit_y=(random(1,map_h*4)-1)*20
					if yesno() then
						exit_x=-20 --left side
					else
						exit_x=map_w*128-1 --right side
					end
				else
					exit_x=(random(1,map_w*4)-1)*20
					if yesno() then
						exit_y=-20 --top side
					else
						exit_y=map_h*128-1 --bottom side
					end
				end			
				
				
				scene_st=3
			end

			-- check time for spawning helicopters (every 16 seconds)
			if scene:timer(16,"helispawn") and heli_count<level_helimax then
				--add_heli()
			end
			
			-- spawn new tank every 10s 
			if scene:timer(10,"tankspawn") and tank_count<level_tankmax then
				--place_tanks(1,true)
			end

			--update_loop(guns)
			--update_loop(bullets)
			--update_loop(mobs)
		end
		
		
		-- level exit is open
		if scene_st==3 then
			if in_box(hx,hy, exit_x,exit_y,{x=0,y=0,w=20,h=20}) then 
				scene_st=4
				hdx,hdy=0,0
				scene_t=t() 
			end
		end
		
		-- hit exit, quick wait before end level
		if scene_st==4 and scene:timer(1.5) then
			game_level+=1
			_scene(scene_intro)
		end
		
		update_loop(snake)
		
		local secx,secy=flr(hx/128)+1,flr(hy/128)+1
		local secxx,secyy=(secx-1)*128,(secy-1)*128
		
		
		
		
		if hx>=secxx+64 then
			if hy>=secyy+64 then quad=4 else quad=2 end
		else
			if hy>=secyy+64 then quad=3 else quad=1 end
		end
		
		
		local sector_houses=houses[secx..","..secy..","..quad]
		
		
		
		--update_loop(houses)
		--
		foreach(sector_houses,function(me)
			local me_x,me_y=me.x,me.y
			local cx=me.x+(me.w*8)/2
			local cy=me.y+(me.h*8)/2

			if inrange(me_x,me_y) then
				if me.st<99 then
					--me.hp-=trample_damage(me_x,me_y,me.hb)

					-- head hit, first time only
					if collide(me_x,me_y,me.hb, hx,hy,hhb) then
						 if not me.bash then
							me.bash=true
							me.hp-=bashpow
							--expl_create(hx,hy,20,1,{rad=4,colors="7;8;9;10;5;6;13"})
						end
					else
						me.bash=false
					end

					if #me.smoke>0 then
						--update_loop(me.smoke)
					end
				end

				if me.hp<me.hpx*.75 and me.st<2 then --little smoke; damaged
					--me.smoke=add_smoke(cx,cy)
					me.st=2
				end

				if me.hp<=bashpow and me.st<3 then --big #smoke; next bash will kill it
					me.smoke=add_smoke(cx,cy,true)
					me.st=3
				end

				-- house explodes
				if me.hp<=0 and me.st<99 then
					me.st=99
					me.smoke={}

					pop_quota=max(0,pop_quota-me.pop)
					meter_up((me.w*me.h)+1,cx,cy)
					--big_explode(cx,cy)

					-- pop counter
					add(bullets,{
						x=cx,y=cy,ky=cy-20,n=me.pop,
						_update=function(me)
							me.y-=.6
							if me.y<me.ky then del(bullets,me) end
						end,
						_draw=function(me)
							text_shadow(me.n,me.x,me.y,7)		
						end
					})

					me.spr=68
				end
			end

			-- after n time, remove the house from table
			if me.st==99 and me:timer(1.7) then del(houses,me) end

		end)
		
		
		

		--expl_update()
	end,
	_draw=function()
		draw_map()
		
		local secx,secy=flr(hx/128)+1,flr(hy/128)+1
		local secxx,secyy=(secx-1)*128,(secy-1)*128
		
		debug=secx..","..secy
		
		
		if hx>=secxx+64 then
			if hy>=secyy+64 then quad=4 else quad=2 end
		else
			if hy>=secyy+64 then quad=3 else quad=1 end
		end
		
		
		
		
		local sector_houses={}--houses[secx..","..secy..","..quad]
		printh("head in "..secx..","..secy..","..quad)
	
		rect(secxx,secyy, secxx+128,secyy+128, 6)
		if quad==1 then	rect(secxx,secyy, secxx+64,secyy+64, 7) end
		if quad==2 then	rect(secxx+64,secyy, secxx+128,secyy+64, 7) end
		if quad==3 then	rect(secxx,secyy+64, secxx+64,secyy+128, 7) end
		if quad==4 then	rect(secxx+64,secyy+64, secxx+128,secyy+128, 7) end
		
		
		local right_sec=secx+1
		local left_sec=secx-1
		local above_sec=secy-1
		local below_sec=secy+1
		
		for n=1,4 do
			for _,h in pairs(houses[secx..","..secy..","..n]) do
				add(sector_houses,h)
			end
		end
		
		printh(#sector_houses)
		--[[
		-- build neighbor quads
		if quad==1 then
			-- same:2,3,4
			-- left: 2,4
			-- above: 3,4
			-- above/left: 4

			
			--sector_houses=table_merge(sector_houses,houses[secx..","..secy..",2"])
			--sector_houses=table_merge(sector_houses,houses[secx..","..secy..",3"])
			--sector_houses=table_merge(sector_houses,houses[secx..","..secy..",4"])
			
		end
		
		if quad==2 then
			-- same: 1,2,3
			-- right: 1,3
			-- above: 3,4
			-- above/right: 3
		end
		
		if quad==3 then
			-- same: 1,2,4
			-- left: 2,4
			-- below: 1,2
			-- left/below: 2
		end
		
		if quad==4 then
			-- neighbors in same sector are: 1,2,3
			-- right sector: 1,3
			-- below sector: 1,2
			-- below/right sector: 1
		end
		]]
		
		--update_loop(houses)
		
		--just draw quad
			foreach(sector_houses,function(me)
				palt(0,false)
				spr(me.spr, me.x,me.y, me.w,me.h)
				pal()

				if me.st>=2 then
					spr(104, me.x,me.y, me.w,1)
				end

				if #me.smoke>0 then
					draw_loop(me.smoke)
				end
			end)
		
		
		
		
		
		--[[draw all within range
		for k,list in pairs(houses) do
			foreach(list,function(me)
				palt(0,false)
				spr(me.spr, me.x,me.y, me.w,me.h)
				pal()

				if me.st>=2 then
					spr(104, me.x,me.y, me.w,1)
				end

				if #me.smoke>0 then
					draw_loop(me.smoke)
				end
			end)
		end
		]]
		
		
		
		-- level exit is open
		if scene_st>=3 then
			rectfill(exit_x+1,exit_y, exit_x+20,exit_y+20, 3)
			print("exit",exit_x+4,exit_y+9,7)
		end
		
		draw_loop(mobs)
		draw_loop(expl_all[1])
		draw_snake()
		draw_loop(bullets)
		
		-- #exit arrow
		if scene_st>=3 then
			if not inrange(exit_x+10,exit_y+10) then
				local aim=atan2(exit_x+10-hx, exit_y+10-hy)
				local exx,exy=get_line(hx,hy, 26,aim) --center
				local ax,ay=get_line(exx,exy, 5,aim+.375) --wing
				local bx,by=get_line(exx,exy, 5,aim-.375) --wing

				line(exx,exy,ax,ay, 7)
				line(exx,exy,bx,by, 7)
			end
		end
		
		-- full screen flash for head hit
		if hhit>0 and hhit<3 then
			rectfill(camx,camy, camw,camh, 7)
			hhit+=1
		else
			hhit=0
		end
		
		draw_ui()
		
		--text_shadow('mem:'..(stat(0)/1024)*100, camx+1, camy+116, 7)
		text_shadow('d:'..debug, camx+1, camy+116, 7)
    	text_shadow('cpu%:'..flr(stat(1)*100), camx+1, camy+123, 7)
	end
}


-- game over
scene_gameover={
	_update=function()
		if scene_st==1 then
			if gt==15 then
				snake[1].hp=0
				gt=0
			end
			
			if #snake<=0 then
				scene_st=2
			end
			
			update_loop(snake)
		end
		
		if scene_st==2 then
			if btnzp then
				_scene(scene_title)
			end
			
		end
		
		
		expl_update()
	end,
	_draw=function()
		draw_map()
		draw_snake()
		draw_loop(mobs)
		draw_loop(expl_all[1])
		draw_ui()
		
		if scene_st==2 then
			text_shadow("game over",camx+50,camy+60,7)
		end
	end
}



-- shared #draw
function draw_snake()
	foreach(snake,function(s) 
		if s.at==2 then pal(11,8) end
		if s.at==3 then pal(11,10) end
		if s.at==4 then pal(11,12) end
		if s.at==5 then pal(11,14) end

		if s.dmg then spr_flash() end

		spr(16,s.x-3,s.y-3)
		pal()
			
		-- laser weapon
		if s.at==4 and s.nearest then
			line(s.x+1,s.y, s.nearest.x,s.nearest.y, 12)	
			line(s.x-1,s.y, s.nearest.x,s.nearest.y, 12)
			line(s.x,s.y, s.nearest.x,s.nearest.y, 12)
				
			fillp(0b1010010110100101.1) 
			line(s.x,s.y, s.nearest.x,s.nearest.y, 7)	
			fillp()
		end
	end)
	
	-- snake head
	if life>0 then
		spr(32,hx-3,hy-3)
		local eyelx,eyely=get_line(hx,hy,3,hang-.125)
		local eyerx,eyery=get_line(hx,hy,3,hang+.125)
		pset(eyelx,eyely,10) --eyes
		pset(eyerx,eyery,10)
	end
end


function draw_map()
	camera(camx,camy)
	
	local mpw,mph=map_w*128,map_h*128
	
	-- backgrounds
	fillp(0b1111110110100111)
	rectfill(-70,-70, mpw+70,mph+70, 1) -- offmap zigzag pattern
	fillp()

	fillp(0b1000010000100001) --warning track stripes
	rectfill(-20,-20, mpw+20,mph+20, 179)
	fillp()

	rectfill(0,0, mpw,mph, 3) --green
	rect(-20,-20, mpw+20,mph+20, 11) --map border		


	-- draw road; just background map - no objects
	foreach(roads, function(v)
		local road,mx,my=v.road,(v.mx-1)*128,(v.my-1)*128
				
		--map(32,0, mx,my, 16,16) --grass

		if road=="center" then map(0,0, mx,my, 16,16) end
		if road=="vert" or road=="vfactory" then map(8,0, mx+64,my, 1,16) end
		if road=="horz" or road=="hfactory" then map(0,8, mx,my+64, 16,1) end
		if road=="tleft" then map(0,0, mx,my, 9,16) end
		if road=="tright" then map(8,0, mx+64,my, 8,16) end
		if road=="tup" then map(0,0, mx,my, 16,9) end
		if road=="tdown" then map(0,8, mx,my+64, 16,8) end
		--if road=="water1" then map(16,0, mx*128,my*128, 16,16) end
		--if road=="water2" then map(16,16, mx*128,my*128, 16,16) end
	end)
	

	--[[draw_loop(houses)
	foreach(houses,function(me)
							
		if inrange(me.x,me.y) then
			palt(0,false)
			spr(me.spr, me.x,me.y, me.w,me.h)
			pal()

			if me.st>=2 then
				spr(104, me.x,me.y, me.w,1)
			end

			if #me.smoke>0 then
				--foreach(me.smoke,function(s) s:_draw() end)
				draw_loop(me.smoke)
			end
		end
	end)]]
	
end


function draw_ui()
		-- #ui
	fillp(0b1010010110100101.1) --checkered
	rectfill(camx,camy, camx+127,camy+7, 1)
	fillp()

	-- kill meter
	rectfill(camx+25,camy+2, camx+81, camy+5, 1)
	rectfill(camx+26,camy+3, camx+26+(56*(meter_now/meter_max)), camy+4, 7)

	--hearts
	text_shadow("\135"..life,camx+3, camy+1, 7)

	--house count
	if scene_st!=3 then
		text_shadow("\137"..pop_quota,camx+95, camy+1, 7)
	else
		text_shadow("exit",camx+95, camy+1, 7)
	end
end





-- #loop
function _init()
	debug=0
	printh(".:.:.:.:.:.:.:.:::: CART LOAD "..rnd())
	cart_draw,cart_update=ef,ef
	fps=1
	_scene(scene_title)
end


function _update60()
	btnl,btnr,btnu,btnd,btnz,btnx=btn(0),btn(1),btn(2),btn(3),btn(4),btn(5)
	btnlp,btnrp,btnup,btndp,btnzp,btnxp=btnp(0),btnp(1),btnp(2),btnp(3),btnp(4),btnp(5)
	
	
	cart_update()
	gt+=1
	fps+=1
	if fps>60 then fps=1 end
end


function _draw()
	cls()
	cart_draw()
end



--#support #utility
function ef() end
function yesno(lt) 
	local lt=lt or .5
	if rnd()<lt then return true else return false end 
end
function _scene(name)
	camera()
	
	gt=0
	scene_st=1
	
	printh("> scene load")
	
	if not name._init then name._init=ef end
	if not name._update then name._update=ef end
	if not name._draw then name._draw=ef end
	
	name._init()
	cart_update=name._update
	cart_draw=name._draw
end

function objtimer(me,check,key)
	local key=key or "t"
	if not me[key] then me[key]=t() end
	if t()-me[key]>check then
		me[key]=t()
		return true
	else
		return false
	end
end


function printc(t,y,c) 
	local t=split(t)

	foreach(t,function(s)
		local x=64-(#s*2)
		text_shadow(s, 64-(#s*2),y,c)
		y+=9
	end)
end

-- uses system time to see if timer is greather than provided check, resets and returns TRUE if it is
function timer_check(timer,check)
	if t()-timer>check then
		return true
	else
		return false
	end
end

function draw_loop(t) foreach(t,function(o) o:_draw() end) end
function update_loop(t) foreach(t,function(o) o:_update() end) end
function sec(s) return s*60 end

function nrnd(n)
   local a=rnd(n)
    if rnd()<.5 then a*=-1 end
    return a
end

-- returns TRUE if x/y is within camera window
function inrange(x,y)
	if x>camx-10 and x<camw+10 and y>camy-10 and y<camh+10 then
		return true
	else
		return false
	end
end

-- returns TRUE if x/y is outside of game play border
function offmap(x,y)
	local map_offx,map_offy=-20,-20
	local map_offw=map_w*128+20
	local map_offh=map_h*128+20
	
	if x<map_offx or x>map_offw or y<map_offy or y>map_offh then
		return true
	else
		return false
	end
end


-- turns all colors white. Must provide disabling pal() when using
function spr_flash()
	for c=1,15 do pal(c,7) end
end

-- timer for damage sprite flash
function dmg_flash(obj)
	if obj.dmg then 
		obj.dmgt+=1
		if obj.dmgt>3 then obj.dmg=false obj.dmgt=0 end
	end
end


	
function debug_hitbox(x,y,hb) 
	rect(x+hb.x,y+hb.y, x+hb.x+hb.w,y+hb.y+hb.h, 7)
end

function to_target(fx,fy,tx,ty,spd)
	local aim=atan2(tx-fx, ty-fy) --turret angle
	local dx,dy=dir_calc(aim,spd)
	
	return dx,dy,aim
end

function dir_calc(angle,speed)
	local dx=cos(angle)*speed
	local dy=sin(angle)*speed
	
	return dx,dy
end

function distance(ox,oy, px,py)
  local a = ox-px
  local b = oy-py
  return (sqrt(a^2+b^2)/16)*16
end

function _alt_distance(x1,x2, y1,y2)
	r = 0.0
	axD = Abs(x2 - x1)
	ayD = Abs(y2 - y1)
	dD = Min(axD, ayD)
	r += dD * 1.4142135623730950488016887242097
	r += (axD - dD) + (ayD - dD)
	return r
end



-- get a random number between min and max
function random(min,max)
	return flr(rnd((max-min)+1))+min
end

-- round number to the nearest whole
function round(num, idp)
  local mult = 10^(idp or 0)
  return flr(num * mult + 0.5) / mult
end

function tshuffle(t)
  for i = #t, 1, -1 do
    local j = flr(rnd(i)) + 1
    t[i], t[j] = t[j], t[i]
  end
end

function trandom(t)
	tshuffle(t)
	return t[1] 
end

function get_line(x,y,dist,dir)
	fx = flr(cos(dir)*dist+x)
	fy = flr(sin(dir)*dist+y)
	
	return fx,fy
end

-- returns true if hitbox collision 
function collide(ax,ay,ahb, bx,by,bhb)
	  local l = max(ax+ahb.x,        bx+bhb.x)
	  local r = min(ax+ahb.x+ahb.w,  bx+bhb.x+bhb.w)
	  local t = max(ay+ahb.y,        by+bhb.y)
	  local b = min(ay+ahb.y+ahb.h,  by+bhb.y+bhb.h)

	  -- they overlapped if the area of intersection is greater than 0
	  if l < r and t < b then
		return true
	  end
					
	return false
end	

function in_box(ax,ay, bx,by,bhb)
	if (ax>bx+bhb.x and ax<bx+bhb.x+bhb.w) and (ay>by+bhb.y and ay<by+bhb.y+bhb.h) then
		return true
	 end
					
	return false	
end


function table_merge(t1,t2) 
	local nt=cp_table(t1)
	
	for k,v in pairs(t2) do nt[k]=v end
	
	return nt
end

function cp_table(t)
   local r={}
   for k,v in pairs(t) do r[k]=v end
   return r
end

function text_shadow(txt,x,y,c)
	print(txt,x+1,y+1,1)
	print(txt,x,y,c)
end
	
	
-- split(string[, delimter])
function split(s,dchar)
	local a={}
	local ns=""
	local dchar=dchar or ";"

	while #s>0 do
		local d=sub(s,1,1)
		if d==dchar then
			add(a,ns)
			ns=""
		else
			ns=ns..d
		end

		s=sub(s,2)
	end

	if #s<=0 then add(a,ns) end

	return a
end

		
-- rspr(spritesheetx,spritesheety, screenx,screeny, angle, tilewidth, transcolor)
-- tilewidth is squared when look at sprites. so a tilewidth=2 will do a 2x2 sprite size
function rspr(sx,sy,x,y,a,w,trans)
	local sx=(sx-1)*8
	local sy=(sy-1)*8
	
  local ca,sa=cos(a),sin(a)
  local srcx,srcy,addr,pixel_pair
  local ddx0,ddy0=ca,sa
  local mask=shl(0xfff8,(w-1))
  w*=4
  ca*=w
  sa*=w
  local dx0,dy0=sa-ca+w,-ca-sa+w
  w=2*w-1
  for ix=0,w do
   srcx,srcy=dx0,dy0
   for iy=0,w do
    if band(bor(srcx,srcy),mask)==0 then
     local c=sget(sx+srcx,sy+srcy)
     if c!=trans then
      pset(x+ix,y+iy,c)
     end
    end
    srcx-=ddy0
    srcy+=ddx0
   end
   dx0+=ddx0
   dy0+=ddy0
  end
 end

-- house #smoker
function add_smoke(x,y,showFire)
	local showFire=showFire or false
	local trail={}
	
	for n=1,7 do
		local obj={
			x=x,y=y,ox=x,oy=y,
			t=0,
			h=-8,
			sp=rnd(.3)+.2,
			dir=rnd(.0626)+.2187,
			fill=false,
			c=5,colors="6;5;1",
			_update=function(o)
				o.y+=o.dy
				o.x+=o.dx
				o.t+=1

				if o.y<o.oy+o.h then
					o.x,o.y,o.t,o.c=o.ox,o.oy,0,trandom(split(o.colors))
					o.dx,o.dy=dir_calc(o.dir,o.sp)
				end
			end,
			_draw=function(o)
				local rad=1+(.06*o.t)
				
				if rnd()<.5 then fillp("0b1010010110100101.1") end
				circfill(o.x,o.y, rad, o.c)
				fillp()
			end
		}
		
		if showFire then
			obj.colors="10;9;8;5;1;2"
			obj.h=-16
		end

		obj.dx,obj.dy=dir_calc(obj.dir,obj.sp)

		add(trail,obj)
	end
	
	return trail
end


-- #exploder
-- expl_create(o.x,o.y, 25, 1, {rad=8})
expl_all={{}}
function expl_create(x,y, qty, layer, options)
    layer=layer or 1
	qty=qty or 25

	for n=0,qty do
		local obj={
			x=x,y=y,
			t=0,
			dur=30,
			rad=3,
			fill=false,
			decay=.2,
			colors="7;10;9;8",
			smin=.7,
			smax=2,
			grav=0,
			layer=layer,
			dir=0,
			range=0,
			_update=function(o)
				o.dy+=o.g
				o.y+=o.dy
				o.x+=o.dx
				o.t+=1
				o.rad-=o.decay

				if o.t>o.dur or o.rad<0 then del(expl_all[o.layer],o) end
			end,
			_draw=function(o)
				if inrange(o.x,o.y) then
					if rnd()<.5 then fillp(o.fill) end
					circfill(o.x,o.y, o.rad, o.c)
					fillp()
				end
			end
		}
		
		if options then obj=table_merge(obj,options) end
		
		obj.colors=split(obj.colors)
		
		
		

		if obj.dir>0 then
			local dirh=obj.range/2
			local dira=obj.dir-dirh
			local dirb=obj.dir+dirh
			
			obj.dir=rnd(dirb-dira)+dira
		else
			obj.dir=rnd()	
		end
	
		local c=flr(rnd(#obj.colors))+1
		obj.c=obj.colors[c]
		obj.g=rnd(abs(obj.grav))
		
		local sp=rnd(obj.smax-obj.smin)+obj.smin
		obj.dx=cos(obj.dir)*sp
		obj.dy=sin(obj.dir)*sp
		
		if obj.grav<0 then obj.g*=-1 end

		add(expl_all[layer],obj)
	end
end

function expl_update()
	foreach(expl_all,function(e)
		foreach(e,function(p)
			p:_update()		
		end)
	end)
end







__gfx__
000000000000000005555555333333ff0000000033333333333333339aaaaaaaaaaaaaa93333333333333333376666d337777777777777753377777777777663
0000000055555555555555553333333c000000b03bbbbbbbbbbbbbb39aaaaaaaaaaaaaa9366533333777766536766d533766655566555665337dddddddddd563
00700700555555555557755533333f3f000000003bbbbbbbbbbbbbb39aaaaaaaaaaaaaa936653333376666653667dd5337666666666666653377777777777663
000770005555555555755755333333ff00b000003bbbbbbbbbbbbbb39aaaaaaaaaaaaaa935553333355555553667dd5335555555555555553376666666666d53
0007700057755775557557553333f3fc000000003bbbbbbbbbbbbbb39aaaaaaaaaaaaaa933333333377776653667dd5339942222222222223376767676767d53
00700700555555555557755533333ffc00000b003bbbbbbbbbbbbbb39aaaaaaaaaaaaaa937676767376666653667dd5330404040404040423376767676767d53
000000005555555555555555333333ff000000003bbbbbbbbbbbbbb39aaaaaaaaaaaaaa93767676735555555367ddd5339444444444444423376666666666d53
00000000555555555555555533333f3f000000003bbbbbbbbbbbbbb39aaaaaaaaaaaaaa93666666633333333375555d330404040404040423376767676767d53
0011100005555555cc77cccccff3f333333333333bbbbbbbbbbbbbb39aaaaaaaaaaaaaa933633333333333336555555039444444444444423376767676767d53
01dd510005557555ccccccccff3333333bbbbbb33bbbbbbbbbbbbbb39aaaaaaaaaaaaaa936463333669949906666666030404040404040423376666666666d53
1ddb551005557555ccccc777fff333333bbbbbb33bbbbbbbbbbbbbb39aaaaaaaaaaaaaa934403333669449409994444039444444444444423376767676767d53
1dbbb5100555555577ccccccf33333333bbbbbb33bbbbbbbbbbbbbb39aaaaaaaaaaaaaa930003333664444409040404030404040004040423376767676767d53
1ddb551005555555cccccccccf3333333bbbbbb33bbbbbbbbbbbbbb39aaaaaaaaaaaaaa933333363331110009944444039444440054444423376666776666d53
01d5510005557555cccc777cff3333333bbbbbb33bbbbbbbbbbbbbb39aaaaaaaaaaaaaa93333364631cc13339040404032222220552222223376767557767d53
001110000555755577c7cccccff333333bbbbbb33bbbbbbbbbbbbbb39aaaaaaaaaaaaaa93333344031cc133399444440666ddddddddddddd3376767557767553
0000000005555555cccc7cccff3f333333333333333333333333333399999999999999993333300033113333000000033366dddddddddd336666dddddddddddd
00222000f33333333333333f3333333311111111111111111111111111111111999999999999999977777777dddddddd33333333333333503333500033335033
02ee8200cf3333333333333f333333331cccccc11cccccc11cccccccccccccc19aaaaaaaaaaaaaa97d9444d7d222222d33333333333333033335503330550003
2eee8820f33f3333333333fc333333331cccccc11cccccc11cccccccccccccc19aaaaaaaaaaaaaa97da999c7d299994d33333333333335033300003333000033
2eee8820f33333333333333ff3333f331cccccc11cccccc11cccccccccccccc19aaaaaaaaaaaaaa97dc99cc7d249944d33333333333330333655555336755553
2ee88820cf3333f333333fff333333331cccccc11cccccc11cccccccccccccc19aaaaaaaaaaaaaa977777777dddddddd33333333333375533676655336776553
02e88200f33f3333f33333fc3f3f33f31cccccc11cccccc11cccccccccccccc19aaaaaaaaaaaaaa97ccccccdd944444233332333233376533676655336766553
00222000ff33f3f33f3fffff33f3f3ff1cccccc11cccccc11cccccccccccccc19aaaaaaaaaaaaaa971c1c1cdd040040233322332233276533676655336766553
00000000cfffcffffcfffcffffccffcf1cccccc1111111111cccccccccccccc199999999999999997cccc1cdd042240233222222222266533676655336776553
08800000cffcffcfffcfffccfcffffcf1cccccc1999999991cccccccccccccc155555555555555553333333337777775322a221a221a66533677655336776553
8aa80000f33f33f333f3ffff3f33f3ff1cccccc19aaaaaa91cccccccccccccc15555757555555555333333333766666532a911a911a946532677655226776552
8aa80000cff3f3333f3f333ff3f333331cccccc19aaaaaa91cccccccccccccc1555575775555555537777775376666653a991a991a9945534676655446766552
08800000f3333333333333fc3f33f3331cccccc19aaaaaa91cccccccccccccc15555777665555555376666653766666599999999999945234476654444766542
00000000cf333333333333ff33333f331cccccc19aaaaaa91cccccccccccccc15555776555555555376666653555555599999999999994239444449999444492
00000000f33f333333333f3f333333331cccccc19aaaaaa91cccccccccccccc15557c66665555555355555553666666590909090909090239999999999999992
00000000f33333333333333f333333331cccccc19aaaaaa91cccccccccccccc15556655555555555399949923565656590909090909090239090909090909092
00000000f33333333333f3fc33333333111111119999999911111111111111115555555555b5b555304040423666666555555555555555235555555555555552
000b0b000d00000000000aa0000000003333b3633355436333333333333333335575755555b5bb55394444423565656533333333888888833333333333333333
0888b880dcd000000000009a00600600363033343633343393666666666666335575775555bbb3353040404236666665377777778ddddd833333333333333333
879888880d0000000000094908888880364566366664333636666666666666335577766555bb3555394444423565656537dddddd8d6666833777777777777763
8a88888200000000aaaaaa4a02228c8043333353033555533665555555555523557765555bc33335304040423666666537d266268d66668337ddddddddddd673
89888882000000009aaaa4aa02228c804355355646634633366540404040442357c6666553355555394444423565656537d222262222222337d66ddd66dd6d73
889888820000000049944aaa08888880335654555353635366544444444444225665555555555555394444423555555537d266267060605337dddd66dd66d673
08888820000000009aaaaaa00060060043435544535463336654222222222222555555555555555566dddddd6ddddddd37d266267666665337d666dd66dd6d73
008222000000000009aaaa000000000033033536444533436654222333333333555555555555555533666ddd666ddd3337777776706060533777777777777773
781888870000bbb00000000b0000000033655555445553346654233333333333333333333333333333dddd333333333337555555766666533766666666666653
78888187000b0b0000cc0c700082280066433536365556536666233333936663332a332a332a33333d7777d33222222337606060706060533762222222626653
7881888700b00b0000111cc006822860333b55353b433354346666393336666232a932a932a92333d779977d3353353337666666666666533762222d22626653
b788887b00b008800c1c71100082280034355464554353b334666623393655522a992a992a992333777997773343343337606060606060533762622622222653
3b7777b3088288780c1cc1c00088880034033533044350333455552233334042a999999999999233777777773444444337666666666666533766666666666653
03bbbb3088782888011111cc068cc86063556b53336553333344042223334442a999999999999233767777673244442337606060606006533765565555655653
0000000088882880c1c71110008888003533334335533b36666ddddd66666ddd91919191919192337d7447d73322223337666666666006533765565555655653
0000000008800000c1cc0cc000000000353335533336333366666dd666666666555555555555523377744777332332336ddddddddddddddddddddddddddddddd
00000000000000000000000000000000000220000000000053353653333333333333333333533333008800003345343362626260620220260000000000000000
0000000000000000000000000000000000022800000000003535334333333333113353351133531508aa80003343543328888822288888820000000000000000
000000000000000000000000000000000002880000000000536056543333333305333315355331558a99a8003345343308222280682222860000000000000000
000000000000000000000000000000000022882200000000045344533333333313533143354535438a99a8003b43343328288280282882820000262626262000
0000000000000000000000000000000000028800000000003346655033333333055305555004055008aa80003333333328288280682882860002888888888200
0000000000000000000000000000000000228882200000004565046333333333001555000000000000880000333333b308222280282222820000288222222000
0000000000000000000000000020000000028880000000005563544533333333000000000000000000000000333b333328888822628888260000282288822000
00000008800000000000000000280008820288800000000053355360333333330000000000000000000000003333333362626260020000200002822222882000
00000002800000000000000000280008820288800000000000000000000000000000100000000000000000000000000000000000000000000002822222882000
00002282822000000008000000288002222222222222200000000000000000000001710000000000000000000000000000000000000000000000282288822000
0088ccc28288200000080000002288888888888888888c8000000000000000001111771000000000000000000000000000000000000000000000288222222000
028ccc22888888828288800000022222888888888888cc8200000000000000007777777100000000000000000000000000002002200200000002888888888200
028ccc228888888282888000002288888888888888888c8000000000000000007777777100000000000000000000000000028228822820000000262626262000
0088ccc2828820000008000000288002222222222222200000000000000000001111771000000000000000000000000000068882288860000000000000000000
00002282822000000008000000280008820288800000000000000000000000000001710000000000000000000000000000028822228820000000000000000000
00000008800000000000000000280008820288800000000000000000000000000000100000000000000000000000000000068222222860000000000000000000
00000008800000000000000000200000000288800000000000000000000000000000000000000000000000000000000000028282282820000000000000000000
00000000000000000000000000000000002288822000000000000000000000000000000000000000000000000000000000068282282860000000000000000000
00000000000000000000000000000000000288000000000000000000000000000000000000000000000000000000000000028288882820000000000000000000
00000000000000000000000000000000002288220000000000000000000000000000000000000000000000000000000000068228822860000000000000000000
00000000000000000000000000000000000288000000000000000000000000000000000000000000000000000000000000028222222820000000000000000000
00000000000000000000000000000000000228000000000000000000000000000000000000000000000000000000000000002000000200000000000000000000
00000000000000000000000000000000000220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000110000000000000000000000000000001100000000000000000000000000000000000000000000000000000000000000110000000000000000000000000000001100000000000000
0000000000000000110000000000000000000000000000000000000000000000000000000000000000000000000000000000001400000025112627000000000000000000000000001100000000000000000000000000000000001400000000000000000000000000110000000000000000000000000000001100000000000000
0000000000000000110000000000000000000000000000000000000000000000000000000000040000000000000004000000141414000025113637000000000000000000000000001100000000000000000000000000000000140000000000000000001400000000112500000000000000000000000000001125000000000000
0000000000000000110000000000000000000000002300000000000000000000000000000000000000000000000000000000002627000000110025000014000000000014141400001125000000000000000000000000000000000000000000000000141414000000112500000000000000001400000000001125000000000000
0000000000000000110000000000000000000000031221000000000000000000000000000400000000000004000000000000253637002425112514000000000000000000000000001125000000000000000000000000000000000024000000000000000000000000110000000000000000141400000000001100000000000000
0000000000000000110000000000000000000000221212212323000000000000000000000000000000000400000000000000000026273425112500252400000000001414000000251100000000000000000000002400252400000034000000000000000000000000110000000000000000001400000026271100000000000000
0000000000000000110000000000000000000003121212121212210000000000000004000000000000000000000000000000242436372627112426273426270000000000000024251100000024000000000000253426273426272400002400000000000000000000112500000000000005060000000036371126270000000000
0000000000000000110000000000000000000003121212121212122100000000000000000000000000000000000000000025343425253637113436372536370000000025252534251100252534250000000025250036372536373425253400000000252500000000112526270000000015160000000000241136370025000000
0101010101010101020101010101010100000000333212121212121221000000000000000000000000000000000000000101010101010101020101010101010101010101010101010201010101010101010101010101010102010101010101010101010101010101022536370000000000000000000025340201010101010101
0000000000000000110000000000000000000000000032121212121212130000000400000000000000000404000000000000252524252627112525252425000000002500252526272524240025250000000000000000000011242500002500000000000025262725112627000000000014000000000026271124242500000000
0000000000000000110000000000000000000000000000321212313333000000000000000400000000000000000000000000002534243637112627003424000000000000002436372434340000000000000000140014002511340000000000000000000000363700113637240000000000140000000036371134340000000000
0000000000000000110000000000000000000000000000003333000000000000000000000000000000000000000000000000000000340025113637140034000000000000003400003400000000000000000506000000002511000026272500000000000000000000112500340000000000000000000025001100000000000000
0000000000000000110000000000000000000000000000000000000000000000000000000000000000000000000000000000142400001400112500140000000000001400000000000000000000000000001516140000000011000036370000000000000000000000112627000000000000001400000000001100000014000000
0000000000000000110000000000000000000000000000000000000000000000000000000000000000000000000000000000003400262700112526270000140000001400140000000000000000000000000014001400000011250000000000000000001414000000113637000000140000001400000000251100000000140000
0000000000000000110000000000000000000000000000000000000000000000000000000400000000000000000000000000000000363725110036370014000000140000001414000000000000000000000014140000140011250000000000000000140000000000110000000014000014000000000000001125000000000000
0000000000000000110000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000110000000000000000000000000000000000000000000000000000000000000011000000000000000000000000000000110000000000000000000000000000001100000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000
0000000000000000000000000000000000002323232323000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001425000000000000000000000000000000000000000000110000000005060000000000000000000000000000000000
0000000000000000000000000000000000221212121212130000000000000000000000000000000000000000000000000000050600140000000000000000000000000014000000000000000014000000000025000000000000000000000000000000350000000000110000000015160000000000000000000000000000000000
0000000000000000000000000000000003121212121212130000000000000000000000000000000000000000000000000000151614140000001400001400000000000000140000000000000014140000000000000007080000000000000000000000000708003500110000000014000000000000000000000000000000000000
0000000000000000000000000000000000333333321212121300000000000000000000000000000000000000000000000000000000000014141400000000000000000014001400000000000000000000000000000017180000350028290000000007081718003535110000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000140000005b000000000000000000000000000007080708000000000017180028293535110024000000000000000000000000000000000000000000
000000000000000000000000000000000000000000002323232323230000000000000000000000000000000000000000000000002400050600000000141400000000000000000000146b000000000000000000002829000017181718003535000028292829003535112434000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000312121212121213000000000000000000000000000000000000000000001434251516002525000000000000000000000000000014140000000000000000282900070807082829003535000708070828293535113400000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000032121212121221000000000000000000000000000000000000000000000000242400141400001400000014000000000000000000000000000000010101010135171817183501010101011718171801010101110000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000002322121212121212130000000000000000000000000000000000000014140000343414262700001400000000140000140000000000000000000000000035353528292829000000353500000028292829282935110000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000031212121212121212212300000000000000000000000000000000000000000000000014363700000000000000000000141405060000000000140000003535352829003500350035353500000000000708070835112500252500000000000000000000000000000000000000
0000000000000000000000000000000000000003121212121212121212121213000000000000000000000000000000000000141400000000000000000000000000000000140015160000000000140000000000000000000000003535000000000000001718171835112500000000000000000000000000000000000000000000
0000000000000000000000000000000000000003121212121212121212121213000000000000000000000000000000000000001414000025000014140000000000000000000000000000001400001400000000252535000000000000003500000000000000003535110025000000000000000000000000000000000000000000
0000000000000000000000000000000000000000333333333333321212121213000000000000000000000000000000000000000000000000000014141400000000000000000000000000000014000000000000000000000000000000000000000000000000000035110000001400000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000003212121213000000000000000000000000000000000000000014000000001414000000000000000000000000000000000000000000000000000000142500000000000000000000000000000000110000001400000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000033333300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000
