-- wash

engine.name="EmissionSpectrum"

function init()
  initialize_params()
  local notes={0,2,4,5,7,9,11}
  local octaves={0,12,24,36,48,60,72}
  local root=18
  local note_ind={}
  for _,n in ipairs(notes) do
    for _,o in ipairs(octaves) do
      table.insert(note_ind,n+o)
    end
  end
  table.sort(note_ind)
  num_notes=#note_ind
  note_pos={}
  for i,n in ipairs(note_ind) do
    note_pos[n]=math.floor(util.linlin(1,num_notes,1,127,i))
  end
  for i=1,10 do
    clock.run(function()
      while true do
        local note=notes[math.random(#notes)]+octaves[math.random(#octaves)]+root
        local duration=math.random(500,2000)/10000*params:get("timescale")
        local attack=math.random(300,700)/1000
        -- print(note,duration,attack)
        engine.washmo(note+root,duration,attack,1-attack)
        clock.sleep(duration)
      end
    end)
  end
  clock.run(function()
    while true do
      clock.sleep(1/10)
      redraw()
    end
  end)
  -- clock.run(function()
  --   while true do
  --     clock.sync(1)
  --     engine.kick(40,6,0.05,1,1,0.3,0.8,0.15,0)
  --   end
  -- end)
  note_env={}
  for i=1,127 do
    table.insert(note_env,0)
  end
end


function initialize_params()
  rev_params={
    reverb=2,
    rev_eng_input=0,
    rev_return_level=6,
    rev_low_time=7,
    rev_mid_time=11,
  }
  for k,v in pairs(rev_params) do
    rev_params[k]=params:get(k)
  end
  params:set("reverb",2)
  params:set("rev_eng_input",0)
  params:set("rev_return_level",6)
  params:set("rev_low_time",7)
  params:set("rev_mid_time",11)
  params:add_number("timescale","timescale",1,1000,100)
  local params_menu={
    {id="timescale",name="timescale",min=0.01,max=10,exp=false,div=0.01,default=1},
  }  
  for _,pram in ipairs(params_menu) do
    params:add{
      type="control",
      id=pram.id,
      name=pram.name,
      controlspec=controlspec.new(pram.min,pram.max,pram.exp and "exp" or "lin",pram.div,pram.default,pram.unit or "",pram.div/(pram.max-pram.min)),
      formatter=pram.formatter,
    }
    params:set_action(pram.id,function(v)
    end)
  end

  for i=1,4 do 
    local params_menu={
      {id="start",name="start",min=1,max=num_notes,exp=false,div=1,default=(i-1)*25+1},
      {id="end",name="end",min=1,max=num_notes,exp=false,div=1,default=i*25},
      {id="attack mean",name="attack mean",min=0.01,max=30,exp=true,div=0.01,default=10,formatter=function(param) return param:get().." s" end},
      {id="attack std",name="attack std",min=0.01,max=30,exp=true,div=0.01,default=3,formatter=function(param) return "+/-"..param:get().." s" end},
      {id="decay mean",name="decay mean",min=0.01,max=30,exp=true,div=0.01,default=10,formatter=function(param) return param:get().." s" end},
      {id="decay std",name="decay std",min=0.01,max=30,exp=true,div=0.01,default=3,formatter=function(param) return "+/-"..param:get().." s" end},
    }  
    params:add_group("SECTOR"..i,#params_menu)
    for _,pram in ipairs(params_menu) do
      params:add{
        type="control",
        id=i..pram.id,
        name=pram.name,
        controlspec=controlspec.new(pram.min,pram.max,pram.exp and "exp" or "lin",pram.div,pram.default,pram.unit or "",pram.div/(pram.max-pram.min)),
        formatter=pram.formatter,
      }
      params:set_action(pram.id,function(v)
      end)
    end
  end
  params:bang()
end

-- return a normally distributed variable
function math.randomn(mu,sigma)
  return math.log(1/math.random())^.5*math.cos(math.pi*math.random())*sigma+mu
 end

function osc.event(path,args,from)
  local note=tonumber(args[1])
  local env=tonumber(args[2])
  note_env[note]=env
end

function cleanup()
  for k,v in pairs(rev_params) do
    params:set(k,v)
  end

end

blend_mode=8
function redraw()
  screen.clear()
  screen.aa(0)
  screen.blend_mode(0)
  
  for n,v in ipairs(note_env) do
    if v>0.002 then
      local level=util.round(util.linexp(0.002,1,0.001,15,v))
      local lw=n%2==1 and 1 or 2 -- util.round(util.linexp(0,1,1,2,v))
      screen.line_width(math.floor(lw))
      screen.level(level)
      screen.move(note_pos[n],0)
      screen.line(note_pos[n],64)
      screen.stroke()
    end
  end

  screen.update()
end
