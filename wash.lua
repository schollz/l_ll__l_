-- wash

engine.name="Washmo"

function init()
  local notes={0,2,4,5,7,9,11}
  local octaves={12,24,36,48}
  --engine.washmo(60,5,0.5,0.5)
  for i=1,10 do
    clock.run(function()
      while true do
        local note=notes[math.random(#notes)]+octaves[math.random(#octaves)]+26+12
        local duration=math.random(500,2000)/100
        engine.washmo(note,duration,0.5,0.5)
        clock.sleep(duration)
      end
    end)
  end

end

function redraw()

end
