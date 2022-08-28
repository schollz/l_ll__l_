-- wash

engine.name="Wash"

function init()
    for i=1,2 do 
        clock.run(function()
            clock.sleep(2.5*i)
            while true do 
                local duration=math.random(500,1500)/100
                engine.wash(duration,math.random(20,80)/10)
                clock.sleep(duration)
            end    
        end)
    end
end