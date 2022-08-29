-- wash

engine.name="Washmo"

function init()
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
  local notes={0,2,4,5,7,9,11}
  local octaves={0,12,24,36,48,60,72}
  local root=18
  local note_ind={}
  for _,n in ipairs(notes) do
    for _,o in ipairs(octaves) do
      table.insert(note_ind,n+o+root)
    end
  end
  table.sort(note_ind)
  local num_notes=#note_ind
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
        engine.washmo(note,duration,attack,1-attack)
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
