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
  for i=1,1 do
    clock.run(function()
      while true do
        local note=notes[math.random(#notes)]+octaves[math.random(#octaves)]+root
        local duration=math.random(500,2000)/100
        print(note,duration)
        engine.washmo(note,duration,0.5,0.5)
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

function redraw()
  screen.clear()
  for n,v in ipairs(note_env) do
    if v>0.002 then
      local level=util.round(util.linexp(0.002,1,0.001,15,v))
      screen.level(level)
      screen.move(note_pos[n],0)
      screen.line(note_pos[n],64)
      screen.stroke()
    end
  end
  -- local r=util.linlin(0,0.3,1,60,amplitude)
  -- screen.level(level)
  -- screen.circle(64,32,r)
  -- screen.fill()
  -- screen.level(level+3)
  -- screen.circle(64,32,r)
  -- screen.stroke()
  screen.update()
end
