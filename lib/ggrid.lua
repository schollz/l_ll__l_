-- local pattern_time = require("pattern")
local GGrid={}

function GGrid:new(args)
  local m=setmetatable({},{__index=GGrid})
  local args=args==nil and {} or args

  m.grid_on=args.grid_on==nil and true or args.grid_on

  -- initiate the grid
  m.g=grid.connect()
  m.g.key=function(x,y,z)
    if m.grid_on then
      m:grid_key(x,y,z)
    end
  end
  print("grid columns: "..m.g.cols)

  -- setup visual
  m.visual={}
  m.notes_on={}
  m.grid_width=16
  for i=1,8 do
    m.visual[i]={}
    m.notes_on[i]={}
    for j=1,m.grid_width do
      m.visual[i][j]=0
      m.notes_on[i][j]=0
    end
  end

  -- keep track of pressed buttons
  m.pressed_buttons={}

  -- grid refreshing
  m.grid_refresh=metro.init()
  m.grid_refresh.time=0.1
  m.grid_refresh.event=function()
    if m.grid_on then
      m:grid_redraw()
    end
  end
  m.grid_refresh:start()

  return m
end

function GGrid:compute_note_inds()
  self.note_ind_row_col={}
  for row=1,8 do
    self.note_ind_row_col[row]={}
    for col=1,16 do
      self.note_ind_row_col[row][col]=self:note_ind(row,col)
    end
  end
end

function GGrid:note_ind(row,col)
  local sector=math.ceil(row/2)
  if params:get(sector.."start")==params:get(sector.."end") then 
    return params:get(sector.."start")
  end
  local ss=params:get(sector.."start")
  local ee=params:get(sector.."end")
  if ss>ee then 
    ss,ee=ee,ss
  end
  return math.floor(wrap(col,ss,ee))
end

function GGrid:grid_key(x,y,z)
  self:key_press(y,x,z==1)
  self:grid_redraw()
end

function GGrid:key_press(row,col,on)
  if on then
    self.pressed_buttons[row..","..col]=true
  else
    self.pressed_buttons[row..","..col]=nil
  end

  local sector=math.ceil(row/2)
  if on then
    self.notes_on[row][col]=self:note_ind(row,col)
    note_on(sector,self.notes_on[row][col],true,true)
  elseif self.notes_on[row][col]>0 then
    note_off(self.notes_on[row][col])
    self.notes_on[row][col]=0
  end
end

function GGrid:get_visual()
  -- clear visual
  for row=1,8 do
    for col=1,self.grid_width do
      self.visual[row][col]=self.visual[row][col]-1
      if self.visual[row][col]<0 then
        self.visual[row][col]=0
      end
    end
  end

  -- figure out which keys are which notes
  if self.note_ind_row_col~=nil then
    for row=1,8 do
      for col=1,16 do
        local note=self:note_ind(row,col)
        self.visual[row][col]=util.clamp(math.floor(note_env[self.note_ind_row_col[row][col]]*30),0,15)
      end
    end
  end

  -- illuminate currently pressed button
  for k,_ in pairs(self.pressed_buttons) do
    local row,col=k:match("(%d+),(%d+)")
    self.visual[tonumber(row)][tonumber(col)]=15
  end

  return self.visual
end

function GGrid:grid_redraw()
  self.g:all(0)
  local gd=self:get_visual()
  local s=1
  local e=self.grid_width
  local adj=0
  for row=1,8 do
    for col=s,e do
      if gd[row][col]~=0 then
        self.g:led(col+adj,row,gd[row][col])
      end
    end
  end
  self.g:refresh()
end

return GGrid
