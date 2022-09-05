-- | ||  | v1.1.1
--
--
-- llllllll.co/t/|_||__|_
--
--
--
--    ▼ instructions below ▼
--
-- K2/K3 changes sector
-- E2/E3 modifies sector position
-- K1+E modifies parameters

grid_=include("lib/ggrid")
hs=include('lib/halfsecond')
MusicUtil=require "musicutil"
engine.name="EmissionSpectrum"
sequins=require("sequins")
er=require("er")

max_note_num=12*4
voice_limit=11
voice_count=0
midi_notes={}
debounce_fn={}

function note_off(note_indy)
  engine.emit_off(note_indy)
end

function note_on(sector,node_indy,force,gate,note_force)
  if node_indy==nil then
    if params:get(sector.."start")==params:get(sector.."end") then 
      note_indy=params:get(sector.."start")
    else
      local ss=params:get(sector.."start")
      local ee=params:get(sector.."end")
      if ss>ee then 
        ss,ee=ee,ss
      end
      node_indy=math.random(ss,ee)
    end
  end
  local attack=util.clamp(math.randomn(params:get(sector.."attack mean"),params:get(sector.."attack std"))*params:get("timescale"),0.001,100)
  local decay=util.clamp(math.randomn(params:get(sector.."decay mean"),params:get(sector.."decay std"))*params:get("timescale"),0.001,100)
  local ring=util.clamp(math.randomn(params:get(sector.."ring mean"),params:get(sector.."ring std")),0.001,1)
  local emit=params:get(sector.."emit")
  local note=note_force or notes[node_indy]
  local duration=attack+decay
  if voice_count<voice_limit or force==true then
    voice_count=voice_count+1
    engine[gate and "emit_on" or "emit"](node_indy,note,attack,decay,ring,params:get(sector.."amp"),params:get("resonator"),emit)
    for j=1,2 do
      local k=j*2-1
      if params:get("crow_"..j.."_sector")==sector then
        crow.output[k].volts=(note-24)/12
        crow.output[k+1].action=string.format("{to(10,%3.5f),to(0,%3.5f)}",attack,decay)
        crow.output[k+1].execute()
      end
    end
    if params:get(sector.."midi_out")>1 then
      table.insert(midi_notes,{device=params:get(sector.."midi_out")-1,ch=params:get(sector.."midi_ch"),note=notes[node_indy],attack=attack,duration=0,dead=false}) -- insert note that needs to be gated off later
      midi_device[params:get(sector.."midi_out")-1].note_on(note,math.floor(ring*127),params:get(sector.."midi_ch"))
    end
  end
  return duration
end

function init()
  norns.enc.sens(1,6)
  norns.enc.sens(2,6)
  norns.enc.sens(3,6)

  g_=grid_:new()

  hs.init()
  initialize_params()
  local voices={2,3,3,1}
  local clocks={}
  for sector=1,4 do
    for i=1,voices[sector] do
      table.insert(clocks,clock.run(function()
        -- clock.sleep(((sector-1)*3+(sector>1 and i or 0)+math.random())/2)
        while true do
          if params:get("generative")==2 then
            local duration=note_on(sector)
            clock.sleep(duration)
          else
            clock.sleep(1)
          end
        end
      end))
    end
  end

  kick_seq=sequins{true,false,false,false}
  beats=0
  clock.run(function()
    while true do
      clock.sync(1/4)
      beats=beats+1
      if (beats-1)%16+1==1 then
        engine.reset_clock()
      end
      if kick_seq() then
        engine.kick(
          params:get("basefreq"),
          params:get("ratio"),
          params:get("sweeptime")/1000,
          params:get("preamp"),
          params:get("kick_amp"),
          params:get("decay1")/1000,
          params:get("decay1L")/1000,
          params:get("decay2")/1000,
        params:get("clicky")/1000)
      end
    end
  end)

  clock.run(function()
    while true do
      clock.sleep(1/10)
      debounce_params()
      for i,mn in ipairs(midi_notes) do
        if not mn.dead then
          midi_notes[i].duration=midi_notes[i].duration+0.1
          if midi_notes[i].duration>mn.attack then
            midi_device[mn.device]:note_off(mn.note,0,mn.ch)
            midi_notes[i].dead=true
          end
        end
      end
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

function debounce_params()
  for k,v in pairs(debounce_fn) do
    if v~=nil and v[1]~=nil and v[1]>0 then
      v[1]=v[1]-1
      if v[1]~=nil and v[1]==0 then
        if v[2]~=nil then
          local status,err=pcall(v[2])
          if err~=nil then
            print(status,err)
          end
        end
        debounce_fn[k]=nil
      else
        debounce_fn[k]=v
      end
    end
  end
end

function initialize_params()
  -- setup reverb parameters to be overwritten
  -- rev_params={
  --   reverb=2,
  --   rev_eng_input=0,
  --   rev_return_level=6,
  --   rev_low_time=7,
  --   rev_mid_time=11
  -- }
  -- for k,v in pairs(rev_params) do
  --   rev_params[k]=params:get(k)
  -- end
  -- params:set("reverb",2)
  -- params:set("rev_eng_input",0)
  -- params:set("rev_return_level",6)
  -- params:set("rev_low_time",7)
  -- params:set("rev_mid_time",11)

  -- setup midi
  midi_device={}
  midi_device_list={"none"}
  local closest_note_ind=function(note)
    local closest_ind={1,100000}
    for i,note2 in ipairs(notes) do
      if math.abs(note2-note)<closest_ind[2] then
        closest_ind={i,math.abs(note2-note)}
      end
    end
    return closest_ind[1]
  end
  local j=0
  for i,dev in pairs(midi.devices) do
    if dev.port~=nil then
      j=j+1
      local connection=midi.connect(dev.port)
      local name=string.lower(dev.name).." "..i
      print("adding "..name.." as midi device")
      table.insert(midi_device_list,name)
      table.insert(midi_device,{
        name=name,
        note_on=function(id_,note,vel,ch) connection:note_on(note,vel,ch) end,
        note_off=function(id_,note,vel,ch) connection:note_off(note,vel,ch) end,
      })
      connection.event=function(data)
        local msg=midi.to_msg(data)
        if msg.type=="clock" then
          do return end
        end
        if msg.type=='start' or msg.type=='continue' then
          -- OP-1 fix for transport
        elseif msg.type=="stop" then
        elseif msg.type=="note_on" and params:get("midi_in")==j+1 then
          local note_indy=closest_note_ind(msg.note)
          print(string.format("[%s] note_on: %d",name,msg.note))
          note_on(params:get("midi_in_sector"),note_indy,true,true,msg.note)
        elseif msg.type=="note_off" and params:get("midi_in")==j+1 then
          print(string.format("[%s] note_off: %d",name,msg.note))
          note_off(closest_note_ind(msg.note))
        end
      end
    end
  end

  -- setup crow
  params:add_group("CROW",4)
  params:add_option("crow_1_sector","crow 1+2 sector",{1,2,3,4},3)
  params:add_option("crow_2_sector","crow 3+4 sector",{1,2,3,4},2)
  prams={{id="crow_slew",name="crow slew",min=0.0,max=10,exp=false,div=0.1,default=0}}
  for _,pram in ipairs(prams) do
    for i=1,2 do
      params:add{
        type="control",
        id=i..pram.id,
        name=pram.name.." "..(i*2)-1,
        controlspec=controlspec.new(pram.min,pram.max,pram.exp and "exp" or "lin",pram.div,pram.default,pram.unit or "",pram.div/(pram.max-pram.min)),
        formatter=pram.formatter,
      }
      params:set_action(i..pram.id,function(v)
        crow.output[i*2-1].slew=v
      end)
    end
  end

  local params_menu={
    {id="gating_amt",name="gating",min=0,max=1,exp=false,div=0.01,default=0.0},
    {id="gating_strength",name="gating lfo",min=0,max=1,exp=false,div=0.01,default=0.0},
    {id="gating_period",name="gating lfo period",min=0,max=30,exp=false,div=0.01,default=math.random(1,6),unit="s"},
  }
  params:add_group("GATING",#params_menu+1)
  for _,pram in ipairs(params_menu) do
    params:add{
      type="control",
      id=pram.id,
      name=pram.name,
      controlspec=controlspec.new(pram.min,pram.max,pram.exp and "exp" or "lin",pram.div,pram.default,pram.unit or "",pram.div/(pram.max-pram.min)),
      formatter=pram.formatter,
    }
    params:set_action(pram.id,function(v)
      debounce_fn["gating"]={
        3,function()
          update_gating()
        end
      }
    end)
  end
  local gating_options={"-48848","8888","48848","-22-26-26-22-26","-288444","-22-62-64","-24444444-2","-248484-2","-266484-2","-26648-112-2","-28-11284-112-2","-246-248-22-2","-4824248","-44-42-2248","-48844-11-11","-4884-11-11-11-11","-4884-11-22-11","-42-22-284-11-22-11","-4884-11-11-11-11","-4-11-11-2-284-11-11-11-11"}
  params:add_option("gating_option","gating",gating_options)
  params:set_action("gating_option",function(x)
    debounce_fn["gating"]={
      3,function()
        update_gating()
      end
    }
  end)

  -- kick
  local params_menu={
    {id="kick_amp",name="amp",min=0,max=4,exp=false,div=0.01,default=0.0,unit="amp"},
    {id="preamp",name="preamp",min=0,max=4,exp=false,div=0.01,default=1,unit="amp"},
    {id="basefreq",name="base freq",min=10,max=200,exp=false,div=0.1,default=32.7,unit="Hz"},
    {id="ratio",name="ratio",min=1,max=20,exp=false,div=1,default=6},
    {id="sweeptime",name="sweep time",min=0,max=200,exp=false,div=1,default=50,unit="ms"},
    {id="decay1",name="decay1",min=5,max=2000,exp=false,div=10,default=300,unit="ms"},
    {id="decay1L",name="decay1L",min=5,max=2000,exp=false,div=10,default=800,unit="ms"},
    {id="decay2",name="decay2",min=5,max=2000,exp=false,div=10,default=150,unit="ms"},
    {id="clicky",name="clicky",min=0,max=100,exp=false,div=1,default=0,unit="%"},
    {id="euc_n",name="euclidean n",min=1,max=128,exp=false,div=1,default=16},
    {id="euc_k",name="euclidean k",min=0,max=128,exp=false,div=1,default=4},
    {id="euc_w",name="euclidean w",min=0,max=128,exp=false,div=1,default=0},
  }
  params:add_group("KICK",#params_menu)
  for _,pram in ipairs(params_menu) do
    params:add{
      type="control",
      id=pram.id,
      name=pram.name,
      controlspec=controlspec.new(pram.min,pram.max,pram.exp and "exp" or "lin",pram.div,pram.default,pram.unit or "",pram.div/(pram.max-pram.min)),
      formatter=pram.formatter,
    }
    params:set_action(pram.id,function(x)
      if string.find(pram.id,"euc")~=nil then
        debounce_fn["euc"]={
          1,function()
            update_euclidean()
          end
        }
      end
    end)
  end

  local attacks={math.randomn(10,2),math.randomn(7,2),math.randomn(5,1),math.randomn(1.7,0.5)}
  local decays={math.randomn(10,2),math.randomn(7,2),math.randomn(5,1),math.randomn(1.7,0.5)}
  local amps={0.7,0.8,1.0,0.5}
  for i=1,4 do
    local params_menu={
      {id="start",name="start",min=1,max=max_note_num,exp=false,div=1,default=(i-1)*max_note_num/4+1},
      {id="end",name="end",min=1,max=max_note_num,exp=false,div=1,default=i*max_note_num/4},
      {id="amp",name="amp",min=0.01,max=2,exp=false,div=0.01,default=amps[i]},
      {id="attack mean",name="attack",min=0.01,max=30,exp=true,div=0.1,default=attacks[i],formatter=function(param) return param:get().." s" end},
      {id="attack std",name="attack spread",min=0.01,max=30,exp=true,div=0.1,default=decays[i],formatter=function(param) return param:get().." s" end},
      {id="decay mean",name="decay",min=0.01,max=30,exp=true,div=0.1,default=attacks[i],formatter=function(param) return param:get().." s" end},
      {id="decay std",name="decay spread",min=0.01,max=30,exp=true,div=0.1,default=decays[i],formatter=function(param) return param:get().." s" end},
      {id="ring mean",name="ring",min=0.01,max=1,exp=false,div=0.1,default=0.5,formatter=function(param) return param:get() end},
      {id="ring std",name="ring spread",min=0.01,max=1,exp=false,div=0.01,default=0.15,formatter=function(param) return param:get() end},
      {id="emit", name="absorb/emit", min=0, max=1, exp=false, div=0.01, default=0.5,formatter=function(param) return param:get() end},
    }
    params:add_group("SECTOR "..i,#params_menu+2)
    for _,pram in ipairs(params_menu) do
      params:add{
        type="control",
        id=i..pram.id,
        name=pram.name,
        controlspec=controlspec.new(pram.min,pram.max,pram.exp and "exp" or "lin",pram.div,pram.default,pram.unit or "",pram.div/(pram.max-pram.min)),
      formatter=pram.formatter}
      params:set_action(i..pram.id,function(v)
        if pram.id=="start" or pram.id=="end" then
          debounce_fn[i..pram.id]={
            3,function()
              g_:compute_note_inds()
            end
          }
        end
      end)
    end
    params:add_option(i.."midi_out","midi out",midi_device_list,1)
    params:add_number(i.."midi_ch","midi ch",1,16,1)
  end
  
  params:add_group("SOURCE", 3)
  params:add_control("noise", "noise", controlspec.new(-math.huge, 6, 'db', nil, 0, "dB"))
  params:add_control("input", "input", controlspec.new(-math.huge, 6, 'db', nil, -math.huge, "dB"))
  params:add_control("loop", "loop", controlspec.new(-math.huge, 6, 'db', nil, -math.huge, "dB"))
  params:set_action("noise", update_source)
  params:set_action("input", update_source)
  params:set_action("loop", update_source)

  -- setup other parameters
  local params_menu={
    {id="amp",name="amp",min=0.01,max=10,exp=false,div=0.01,default=0.5},
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
      if engine[pram.id]~=nil then
        engine[pram.id](v)
      end
    end)
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
    min=0,max=127,default=12,formatter=function(param) return MusicUtil.note_num_to_name(param:get(),true) end,
  action=function() build_scale() end}
  params:add_option("resonator","resonator",{"noise","input","buffer"},2)
  params:hide("resonator")
  params:add_option("generative","generative",{"off","on"},2)
  params:add_option("midi_in","midi in",midi_device_list,#midi_device_list)
  params:add_number("midi_in_sector","midi in sector",1,4,4)

  params:bang()
end

function update_source()
  engine.source(util.dbamp(params:get("noise")), util.dbamp(params:get("input")), util.dbamp(params:get("loop")))
end

function update_euclidean()
  local euc=er.gen(params:get("euc_k"),params:get("euc_n"),params:get("euc_w"))
  tab.print(euc)
  kick_seq:settable(euc)
end

function update_gating()
  local numdash=params:string("gating_option")
  local vals={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
  local isminus=false
  local i=1
  for c in numdash:gmatch"." do
    if c=="-" then
      isminus=true
    else
      if not isminus and i<33 then
        vals[i]=tonumber(c)*2
      end
      i=i+tonumber(c)
      isminus=false
    end
  end

  engine.set_gating(clock.get_tempo(),params:get("gating_amt"),params:get("gating_strength"),params:get("gating_period"),
    vals[1],vals[2],vals[3],vals[4],vals[5],vals[6],vals[7],vals[8],
    vals[9],vals[10],vals[11],vals[12],vals[13],vals[14],vals[15],vals[16],
    vals[17],vals[18],vals[19],vals[20],vals[21],vals[22],vals[23],vals[24],
  vals[25],vals[26],vals[27],vals[28],vals[29],vals[30],vals[31],vals[32])
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
  if path=="amplitude" then
    local note_ind=tonumber(args[1])
    local env=tonumber(args[2])
    -- print(args[1],args[2])
    note_env[note_ind]=env
  elseif path=="freed" then
    local note_ind=tonumber(args[1])
    note_env[note_ind]=0
    voice_count=voice_count-1
  end
end

function cleanup()
  -- for k,v in pairs(rev_params) do
  --   params:set(k,v)
  -- end
  for _,c in ipairs(clocks) do
    clock.cancel(c)
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
      params:delta(current_sector.."amp",d)
      show_curve[current_sector]=40
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
      if ss>ee then 
        ss,ee=ee,ss
      end
      screen.rect(ss,0,ee-ss+1,65)
      screen.fill()
      screen.blend_mode(0)
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

  for i=1,4 do
    if show_curve[i]>0 then
      screen.blend_mode(4)
      show_curve[i]=show_curve[i]-1
      screen.level(math.floor(util.round(show_curve[i]/4)))
      screen.move(12,32-16)
      screen.text(string.format("sector: %d",i))
      screen.move(128-12,32-8)
      screen.text_right(string.format("amp: %2.2f",params:get(i.."amp")))
      screen.move(12,32)
      screen.text(string.format("attack: %2.1f s",params:get(i.."attack mean")))
      screen.move(128-12,40)
      screen.text_right(string.format("decay: %2.1f s",params:get(i.."decay mean")))
      screen.blend_mode(0)
    end
  end

  screen.update()
end
