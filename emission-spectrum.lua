-- emission spectrum

hs=include('emission-spectrum/lib/halfsecond')
MusicUtil=require "musicutil"
engine.name="EmissionSpectrum"

max_note_num=12*4

function init()
  hs.init()
  initialize_params()
  local voices={2,3,3,1}
  for sector=1,4 do
    for i=1,voices[sector] do
      clock.run(function()
        clock.sleep(sector+i*0.5)
        while true do
          local note_ind=math.random(params:get(sector.."start"),params:get(sector.."end"))
          local attack=util.clamp(math.randomn(params:get(sector.."attack mean"),params:get(sector.."attack std"))*params:get("timescale"),0.001,100)
          local decay=util.clamp(math.randomn(params:get(sector.."decay mean"),params:get(sector.."decay std"))*params:get("timescale"),0.001,100)
          local ring=util.clamp(math.randomn(params:get(sector.."ring mean"),params:get(sector.."ring std")),0.001,1)
          local duration=attack+decay
          engine.emit(note_ind,notes[note_ind],attack,decay,ring)
          for j=1,2 do
            local k=j*2-1
            if params:get("crow_"..j.."_sector")==sector then
              crow.output[k].volts=(notes[note_ind]-24)/12
              crow.output[k+1].action=string.format("{to(10,%3.5f),to(0,%3.5f)}",attack,decay)
              crow.output[k+1].execute()
              print(k,(notes[note_ind]-24)/12,string.format("{to(5,%3.5f),to(0,%3.5f)}",attack,decay))
            end
          end
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
  notes=MusicUtil.generate_scale_of_length(params:get("root_note"),params:get("scale_mode"),max_note_num)
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

  -- setup crow
  params:add_group("CROW",4)
  params:add_option("crow_1_sector","crow 1+2 sector",{1,2,3,4},3)
  params:add_option("crow_2_sector","crow 3+4 sector",{1,2,3,4},2)
  for _,pram in ipairs({
  {id="crow_slew",name="crow slew",min=0.0,max=10,exp=false,div=0.1,default=0}}) do
  for i=1,2 do
    params:add{
      type="control",
      id=i..pram.id,
      name=pram.name,
      controlspec=controlspec.new(pram.min,pram.max,pram.exp and "exp" or "lin",pram.div,pram.default,pram.unit or "",pram.div/(pram.max-pram.min)),
      formatter=pram.formatter,
    }
    params:set_action(i..pram.id,function(v)
      crow.output[i*2-1].slew=v
    end)
  end
end

-- setup scales
scale_names={}
for i=1,#MusicUtil.SCALES do
  table.insert(scale_names,string.lower(MusicUtil.SCALES[i].name))
end
params:add{type="option",id="scale_mode",name="scale mode",
  options=scale_names,default=1,
action=function() build_scale() end}
params:add{type="number",id="root_note",name="root note",
  min=0,max=127,default=18,formatter=function(param) return MusicUtil.note_num_to_name(param:get(),true) end,
action=function() build_scale() end}

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

local ways_and_means={10,7,5,1}
for i=1,4 do
  local params_menu={
    {id="start",name="start",min=1,max=max_note_num,exp=false,div=1,default=(i-1)*max_note_num/4+1},
    {id="end",name="end",min=1,max=max_note_num,exp=false,div=1,default=i*max_note_num/4},
    {id="attack mean",name="attack mean",min=0.01,max=30,exp=true,div=0.1,default=ways_and_means[i],formatter=function(param) return param:get().." s" end},
    {id="attack std",name="attack std",min=0.01,max=30,exp=true,div=0.1,default=ways_and_means[i]/4,formatter=function(param) return "+/-"..param:get().." s" end},
    {id="decay mean",name="decay mean",min=0.01,max=30,exp=true,div=0.1,default=ways_and_means[i],formatter=function(param) return param:get().." s" end},
    {id="decay std",name="decay std",min=0.01,max=30,exp=true,div=0.1,default=ways_and_means[i]/4,formatter=function(param) return "+/-"..param:get().." s" end},
    {id="ring mean",name="ring mean",min=0.01,max=1,exp=false,div=0.1,default=0.5,formatter=function(param) return param:get() end},
    {id="ring std",name="ring std",min=0.01,max=1,exp=false,div=0.1,default=0.2,formatter=function(param) return "+/-"..param:get().." s" end},
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
    params:set_action(i..pram.id,function(v)
    end)
  end
end
params:bang()
end

-- return a normally distributed variable
function math.randomn(mu,sigma)
  return math.log(1/math.random())^.5*math.cos(math.pi*math.random())*sigma+mu
end

function wrap(n,a,b)
  while n>b do
    n=n-(b-a)
  end
  while n<a do
    n=n+(b-a)
  end
  return n
end

function note_pos(ind)
  return math.floor(util.round(128/max_note_num*ind))
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

current_sector=1
shift=false
show_sector={0,0,0,0}
show_curve={0,0,0,0}
function key(k,z)
  if k==1 then
    shift=z==1
  elseif k==2 and z==1 then
    current_sector=current_sector-1
    if current_sector<1 then
      current_sector=1
    end
    show_sector[current_sector]=10
  elseif k==3 and z==1 then
    current_sector=current_sector+1
    if current_sector>4 then
      current_sector=4
    end
    show_sector[current_sector]=10
  end
end

function enc(k,d)
  if shift then
    if k==1 then
    elseif k==2 then
      params:delta(current_sector.."attack mean",d)
      show_curve[current_sector]=40
    elseif k==3 then
      params:delta(current_sector.."decay mean",d)
      show_curve[current_sector]=40
    end
  else
    if k==1 then
    elseif k==2 then
      params:delta(current_sector.."start",d)
      show_sector[current_sector]=40
    elseif k==3 then
      params:delta(current_sector.."end",d)
      show_sector[current_sector]=40
    end
  end
end

function redraw()
  screen.clear()
  screen.aa(0)
  screen.blend_mode(0)

  for i=1,4 do
    if show_sector[i]>0 then
      screen.blend_mode(3)
      show_sector[i]=show_sector[i]-1
      screen.level(math.floor(util.round(show_sector[i]/4)))
      local ss=note_pos(params:get(i.."start"))
      local ee=note_pos(params:get(i.."end"))
      screen.rect(ss,0,ee-ss+1,65)
      screen.fill()
      screen.blend_mode(0)
    end
    if show_curve[i]>0 then
      show_curve[i]=show_curve[i]-1
      screen.level(math.floor(util.round(show_curve[i]/4)))
      screen.move(12,32)
      screen.text(string.format("attack: %2.3f s",params:get(i.."attack mean")))
      screen.move(128-12,32)
      screen.text_right(string.format("decay: %2.3f s",params:get(i.."decay mean")))
    end
  end

  for note_ind,v in ipairs(note_env) do
    if v>0.002 then
      local level=util.round(util.linlin(0.002,1,0,15.49,v))
      local lw=notes[note_ind]%2==1 and 1 or 2 -- util.round(util.linexp(0,1,1,2,v))
      local pos=note_pos(note_ind)
      screen.line_width(math.floor(lw))
      screen.level(level)
      screen.move(pos,0)
      screen.line(pos,64)
      screen.stroke()
    end
  end

  screen.update()
end
