-- wash

hs = include('lib/halfsecond')
MusicUtil = require "musicutil"
engine.name="EmissionSpectrum"

max_note_num=14*4

function init()
  initialize_params()

  -- TODO: setup halfsecond

  for sector=1,4 do
    for i=1,2 do
      clock.run(function()
        while true do
          local note_ind=math.random(params:get(sector.."start"),params:get(sector.."end"))
          local attack=math.randomn(params:get(sector.."attack mean"),params:get(sector.."attack std"))*params:get("timescale")
          local decay=math.randomn(params:get(sector.."decay mean"),params:get(sector.."decay std"))*params:get("timescale")
          local duration=attack+decay
          local ring=math.random() -- TODO: make a parameter for ring
          engine.washmo(note_ind,notes[note_ind],attack,decay,ring)
          clock.sleep(duration)
        end
      end)
    end
  end

  clock.run(function()
    while true do
      clock.sleep(1/10)
      redraw()
    end
  end)

  note_env={}
  for i=1,127 do
    table.insert(note_env,0)
  end
end

function build_scale()
  notes = MusicUtil.generate_scale_of_length(params:get("root_note"), params:get("scale_mode"), 56)
end

function initialize_params()
  -- setup reverb parameters to be overwritten
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
  
  -- setup scales
  scale_names={}
  for i = 1, #MusicUtil.SCALES do
    table.insert(scale_names, string.lower(MusicUtil.SCALES[i].name))
  end
  params:add{type = "option", id = "scale_mode", name = "scale mode",
    options = scale_names, default = 5,
    action = function() build_scale() end}
  params:add{type = "number", id = "root_note", name = "root note",
    min = 0, max = 127, default = 18, formatter = function(param) return MusicUtil.note_num_to_name(param:get(), true) end,
    action = function() build_scale() end}


  -- setup other parameters
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
      {id="start",name="start",min=1,max=num_notes,exp=false,div=1,default=(i-1)*max_note_num/4+1},
      {id="end",name="end",min=1,max=num_notes,exp=false,div=1,default=i*max_note_num/4},
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
  local note_ind=tonumber(args[1])
  local env=tonumber(args[2])
  note_env[note_ind]=env
end

function cleanup()
  for k,v in pairs(rev_params) do
    params:set(k,v)
  end

end

function redraw()
  screen.clear()
  screen.aa(0)
  screen.blend_mode(0)
  
  for note_ind,v in ipairs(note_env) do
    if v>0.002 then
      local level=util.round(util.linexp(0.002,1,0.001,15,v))
      local lw=notes[note_ind]%2==1 and 1 or 2 -- util.round(util.linexp(0,1,1,2,v))
      screen.line_width(math.floor(lw))
      screen.level(level)
      screen.move(note_ind+8,0)
      screen.line(note_ind+8,64)
      screen.stroke()
    end
  end

  screen.update()
end
