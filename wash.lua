-- wash

engine.name="Washmo"

function init()
  clock.run(function()
    while true do
      local duration=math.random(500,1500)/100
      print("washing",duration)
      engine.washmo(duration,math.random(20,80)/100)
      clock.sleep(duration*0.9)
    end
  end)
  clock.run(function()
    clock.sleep(2.5)
    while true do
      local duration=math.random(500,1500)/100
      print("washing",duration)
      engine.washmo(duration,math.random(20,80)/100)
      clock.sleep(duration*0.9)
    end
  end)
end

function redraw()

end
