pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- ones extra screens
-- by QUALIA
--------------

-- game logic
--------------

gw, gh = 4, 4

function not3(v)
 return v == 1 or v == 2
end

function can_merge(a,b)
 if a == 0 or b == 0 then
  return false
 elseif not3(a) and not3(b) then
  return a != b
 else
  return a == b
 end
end

function merge(a,b)
 if can_merge(a,b) then
  if not3(a) then
    return 3
  else return a+1
  end
 else return a
 end
end

function slide_pieces_left(old_row)
 local new_row = deepcopy(old_row)
 local move_mask = {false}

 for i=2,#old_row do
  local val = old_row[i]
  new_row[i] = 0
  move_mask[i] = val ~= 0

  local left_val = new_row[i-1]
  if left_val == 0 then
   new_row[i-1] = val
  elseif can_merge(left_val,val) then
   new_row[i-1] = merge(left_val, val)
  else
   move_mask[i] = false
   new_row[i] = val
  end
 end

 return new_row, move_mask
end

function next_pieces(state)
 np, nb = bucket(state.piece_bucket)
 if #nb == 0 then
  nb = new_bucket(state)
 end
 return np, nb
end

function bonus_piece(max_val)
 pieces={}
 for i=max(max_val-5,4),
       max_val-3 do
  add(pieces,i)
 end
 return pieces
end

function piece_from_np(np,max_val)
 if np == 4 and max_val > 6 then
  return bonus_piece(max_val)
 end
 return min(np,3)
end

function move_outcome(move, g)
 local ng = {}
 local move_mask = {}

 if is_vertical(move) then
  g = transpose(g)
 end
 if move % 2 == 1 then
  g = lmap(reverse, g)
 end

 local candidate_rows={}

 for j=1,#g do
  local row, row_move_mask =
   slide_pieces_left(g[j])
  add(move_mask, row_move_mask)
  add(ng,row)
  if any(row_move_mask) then
   add(candidate_rows,row)
  end
 end

 if #candidate_rows ~= 0 then
  choose(candidate_rows)[#candidate_rows[1]]
    = 0xf -- sentinel for new piece
 end

 if move % 2 == 1 then
  ng        = lmap(reverse, ng)
  move_mask = lmap(reverse, move_mask)
 end
 if is_vertical(move) then
  ng        = transpose(ng)
  move_mask = transpose(move_mask)
 end

 return ng, move_mask
end

function is_vertical(move)
 return move >= 2
end

function allowed_moves(grid)
 -- 0: left
 -- 1: right
 -- 2: up
 -- 3: down
 local moves={}
 for move=0,3 do
  local ng, mask =
    move_outcome(move, grid)
  if any(lmap(any, mask)) then
   moves[move] = {
     next_grid=ng,
     move_mask=mask
   }
  end
 end
 return moves
end

function next_state(move, state)
 local ng = mapgrid(
   function(i,j,v)
    if v==0xf then
     if state.next_pieces then
      return choose(state.next_pieces)
     end
     -- special case for tutorial
     return 0
    end
    return v
   end,
   state.moves[move].next_grid
 )

 local max_val = maximum(ng)

 local np, nb = next_pieces(state)

 return {grid=ng,
         next_pieces=
           piece_from_np(
            np,
            max_val),
         piece_bucket=nb,
         moves=allowed_moves(ng),
         max_val=max_val}
end

function make_grid(w,h)
 local grid = {}
 for j=1,h do
  grid[j] = {}
  for i=1,w do
   grid[j][i] = 0
  end
 end
 return grid
end

function max_ever_val()
 local mv = 0
 for b in all(data.boards) do
  mv = max(mv, b.max_val)
 end
 return mv
end

function init_board(w,h,b)
 local grid = make_grid(w,h)

 local n = 9
 if settings.boost then
  grid[4][1] = max(3, max_ever_val() - 3)
  n -= 1
 end

 for i=1,n do
  local x,y
  repeat
   x = rndint(w)
   y = rndint(h)
  until grid[y][x] == 0
  grid[y][x], b = bucket(b)
 end
 add(b,v)
 return grid, b
end

function new_bucket(state)
 local b = base_bucket()
 if rndint(3) < 2 and state.max_val > 3 then
  add(b,4) -- 4 = sentinel for bonus piece
 end
 return b
end

function score_tile(v)
 return v>2 and bigint_new(3)^(v-2) or 0
end

function calculate_score(grid)
 score = 0
 foreach(joinlists(grid), function(x)
           score+=score_tile(x) end)
 return score
end
-->8
-- game states

function base_bucket()
 return {1,1,1,1,2,2,2,2,3,3,3,3}
end

data = {}

state = nil
function make_state(grid, np, b)
 local mv = maximum(grid)

 return {
  grid=grid,
  piece_bucket=b,
  next_pieces=piece_from_np(np,mv),
  moves=allowed_moves(grid),
  max_val=mv,
  finished=false
 }
end

transition = {}

function transition.init(target, source, dx, dy)
  btnsfx()
  target.init()
  transition.target = target
  transition.source = source
  transition.dx, transition.dy = dx, dy
  transition.x, transition.y = 0, 0
  transition.anim = animate(0.5,ease.o.quad,
                            0,120,function(t)
                              transition.x = t*dx
                              transition.y = t*dy
                            end)
  mode = transition
end

function transition.update()
  cls(scheme.bg)
  coresume(transition.anim)
  if coalive(transition.anim) then
    camera(transition.x, transition.y)
    transition.source.draw()
    camera(transition.x - 120 * transition.dx,
           transition.y - 120 * transition.dy)
    transition.target.draw()
  else
    camera()
    transition.target.draw()
    mode = transition.target
  end
end

function new_state()
 local b, grid, np
 b = base_bucket()
 grid, b = init_board(gw,gh,b)
 np, b = bucket(b)
 return make_state(grid, np, b)
end


play = {}
function play.init()
 mode = play
 play.drawn = false
 play.move = nil
 -- disable btnp repeating
 poke(0x5f5c, 255)
end

function play.draw()
 draw_next_pieces(state.next_pieces)
 if play.move then
   draw_grid(state.grid,nil,
             state.moves[play.move.btn].move_mask,
             play.move.btn)
 else
   draw_grid(state.grid)
 end
 draw_top_buttons("MENU","▤", btn(4),
                  "STATS","∧", btn(5))
end

function play.update()
 load("ones.p8")
end

btn_state = {}
function _update()
 for i=0,5 do
  if btn_state[i] != btn(i) then
   mode.drawn=false
   btn_state[i] = btn(i)
  end
 end

 mode.update()

 if not mode.drawn and mode != transition then
  cls(scheme.bg)
  mode.draw()
  mode.drawn = true
 end
end

function _init()
 store_init()
 local loaded = load_data()
 data.last_name = loaded.last_name
 data.boards = loaded.boards

 settings = loaded.settings
 apply_settings()

 cls(scheme.bg)

 local grid, np, b = load_game()
 if grid then
  state = make_state(grid, np, b)
  play.init()
  mode.draw()
  transition.init(stats, mode, 1, 0)
 else
  tutorial.init()
  mode.draw()
 end
end

-->8
-- tutorial

tutorial = {}

function tohexdigit(n)
 assert(0 <= n and n < 16)
 if n < 10 then
  return tostr(n)
 end
 return sub("abcdef", n-9,n-9)
end

function txtcol(s)
 return "\f" .. tohexdigit(scheme.txt) .. s
end

function tutorial.init()
 mode = tutorial
 tutorial.drawn = false

 play.drawn = false
 play.move = nil
 -- disable btnp repeating
 poke(0x5f5c, 255)

 tutorial.main_text = "\f8o\fcn" .. txtcol("es!")
 tutorial.bottom_text = "ANY ⬅️⬇️⬆️➡️ TO BEGIN"
 tutorial.print_main_text = function(s,y,c)print(s,55,y,c)end
 tutorial.extra_draw = nil
 tutorial.seq = cocreate(tutorial_sequence)
 coresume(tutorial.seq)
end

function tutorial.update()
 local valid_moves = keys(state.moves)
 if #valid_moves == 0 then
  coresume(tutorial.seq, btnp(0) or btnp(1) or btnp(2) or btnp(3))
  return
 end
 if tutorial.extra_draw then
  mode.drawn = false
 end

 for move in all(valid_moves) do
  if btnp(move)
    and (not mode.move
         or move != mode.move.btn)
  then
   mode.move = {btn=move, t=t()}
   break

  elseif mode.move
   and mode.move.btn == move
  then
   if btnp(mode.move.btn) then
    state =
      next_state(move,state)
    slidesfx()
    coresume(tutorial.seq, mode.move.btn)
    mode.move = nil
    break
   elseif btn(mode.move.btn) then
    mode.move.t = t()
   elseif t() - mode.move.t > 0.75 then
    mode.move = nil
    mode.drawn = false
   end
  end
 end
end

function tutorial.draw()
 if mode.move then
  draw_grid(state.grid,nil,
            state.moves[mode.move.btn].move_mask,
            mode.move.btn)
 else
  draw_grid(state.grid)
 end

 if type(tutorial.extra_draw) == "function" then
  tutorial.extra_draw()
 elseif type(tutorial.extra_draw) == "thread" then
  coresume(tutorial.extra_draw)
 end

 if tutorial.main_text then
  tutorial.print_main_text(tutorial.main_text,title_y,scheme.txt)
 end
 if tutorial.bottom_text then
  printc(tutorial.bottom_text,64,112,scheme.txt)
 end
end

function right_align_main(s,y,c)
 printr(s,107,y,c)
end

function center_align_main(s,y,c)
 printc(s,64,y,c)
end


function tutorial_sequence()
 grid = make_grid(4,4)
 state = {
  grid=grid,
  piece_bucket={},
  next_pieces=nil,
  moves={},
  max_val=0,
  finished=false
 }

 yield()
 -- wait for arrow key
 while not yield() do end


 local red, blue = "\f8red", "\fcblue"
 local nx, ny = 0, 0
 function track_move(btn)
  local dx, dy = move2dirs(btn)
  nx += dx
  ny += dy
 end

 state.grid[2][2] = 1
 state.grid[3][3] = 2
 state.moves=allowed_moves(state.grid)

 tutorial.main_text = "meet ".. blue .. txtcol(" & ") .. red
 tutorial.print_main_text = right_align_main
 tutorial.bottom_text = "DOUBLE ⬅️⬇️⬆️➡️\nTO MOVE THEM"

 -- wait for move
 track_move(yield())

 tutorial.main_text = "⬅️⬇️⬆️➡️;\nmove everybody"
 tutorial.bottom_text = nil

 track_move(yield())

 tutorial.main_text = "rearrange numbers by\npushing 'em into walls"
 tutorial.bottom_text = "⬅️⬇️⬆️➡️; MOVE EVERYBODY"

 tutorial.extra_draw = draw_walls

 while abs(nx) < 2 and abs(ny) < 2 do
  state.next_pieces = nil
  track_move(yield())
 end

 tutorial.main_text = (
   "use the walls to add\n\fcblue"
   .. txtcol(" & ")
   .. red
   .. txtcol(" together"))
 tutorial.bottom_text = nil

 -- wait for move
 while maximum(state.grid) != 3 do
  state.next_pieces = nil
  yield()
 end

 tutorial.extra_draw = nil

 tutorial.main_text = "auspicious!"
 tutorial.bottom_text = "MOVE ANYWHERE"
 state.next_pieces = nil

 yield()

 tutorial.main_text = "new numbers appear \nwhen you move cards!"
 state.next_pieces = 3

 yield()

 tutorial.print_main_text = center_align_main
 tutorial.main_text = "1 + 1 = 2"
 tutorial.bottom_text = nil


 while maximum(state.grid) != 4 do
  state.next_pieces = nil
  yield()
 end

 tutorial.print_main_text = right_align_main
 tutorial.main_text = "you're getting it!"

 state.next_pieces = 3
 yield()

 tutorial.print_main_text = center_align_main
 tutorial.main_text = "numbers 1 and higher\nwill only add together\n\f8if they are twins."

 for i=1,3 do
  state.next_pieces = nil
  yield()
 end
 state.next_pieces = 3
 yield()

 tutorial.bottom_text = "CREATE A 3 TO CONTINUE"

 state.next_pieces = 3
 yield()
 while maximum(state.grid) != 5 do
  state.next_pieces = nil
  yield()
 end

 tutorial.print_main_text = right_align_main
 tutorial.main_text = "fantastic!"
 tutorial.bottom_text = "MOVE ANYWHERE TO CONTINUE"

 state.next_pieces = 1
 yield()
 tutorial.bottom_text = nil

 tutorial.print_main_text = center_align_main
 tutorial.main_text = (
   blue .. txtcol(" WILL only ADD WITH ") .. red)

 for i=1,3 do
  state.next_pieces = 1
  yield()
 end

 state.next_pieces = 2
 yield()
 tutorial.main_text = (
   red .. txtcol(" WILL only ADD WITH ") .. blue)

 for i=1,4 do
  state.next_pieces = 2
  yield()
 end
 state.next_pieces = 1
 yield()

 tutorial.print_main_text = center_align_main
 tutorial.main_text = "make a 4!"

 while maximum(state.grid) != 6 do
  local occupied = 0
  mapgrid(function(i,j,v) if (v != 0) occupied += 1 end, state.grid)
  if occupied > 8 then
   state.next_pieces = nil
  end
  yield()
 end

 tutorial.print_main_text = right_align_main
 tutorial.main_text = "tHIS IS \f8o\fcn" .. txtcol("es!")
 tutorial.bottom_text = "MOVE TO KEEP GROWING!"

 yield()

 tutorial.print_main_text = center_align_main
 tutorial.main_text = "make the highest\nnumber you can!"

 tutorial.bottom_text = "THAT'S THE GOAL OF THE GAME"

 yield()

 tutorial.main_text = nil
 tutorial.bottom_text = "LOOK UP TO SEE WHAT'S NEXT"

 tutorial.extra_draw = animate(
  0.5,
  ease.o.quart,
  -40,0,
  function(y)
   camera(0,-y)
   draw_next_pieces(state.next_pieces)
   camera(0,0)
  end, "stick")

 for i=1,4 do
  yield()
 end

 tutorial.bottom_text = "IT'S OVER WHEN\nTHE BOARD FILLS UP"

 yield()

 tutorial.bottom_text = "HOLD A DIRECTION\nTO SEE THE FUTURE "

 yield()

 save_game()
 load("ones.p8")
end

function draw_walls()
 rect(29,39,99,109,8)
 rect(28,38,100,110,8)
 print("w\na\nl\nl",22,70,8)
 print("w\na\nl\nl",104,50,8)
end

-->8
-- stats screen

stats = {}
function stats.init()
 mode = stats
 local n_scores = store_load_byte(152)
 stats.scores =
   lmap(function(x) return x >>> 5 end,
         filter(function(x) return x != 0 end,
           store_load_bytes(153, 102)))
 -- because this is a ring, we need
 -- to put the scores before the pivot
 -- at the end of the list
 for i=1,n_scores do
  add(stats.scores, deli(stats.scores, 1))
 end
 stats.current_score = poorlog10(calculate_score(state.grid))
 add(stats.scores,stats.current_score)
 stats.hicards = store_load_bytes(140,12)

 local sum = 0
 for v in all(stats.hicards) do
  sum += v
 end
 stats.hicard_frame = #stats.scores + 1
 stats.num_frames = stats.hicard_frame + sum + 1
 stats.frame = 0
 stats.subframe = 0
end

function stats.update()
 if btnp(4) or btnp(5) then
  transition.init(play, stats, -1, 0)
 end

 if stats.frame < stats.num_frames then
  stats.subframe += 1
  if stats.subframe % 2 == 0 then
   stats.frame += 1
   stats.drawn = false
  end
 end
end


function stats.draw()
 local gui_y = 34

 local xs, ys = {}, {}
 for i=1,min(stats.frame, #stats.scores) do
  add(xs, i)
  add(ys, stats.scores[i])
 end

 print("SCORE OVER TIME", 23, gui_y, scheme.stats_subtitle)
 gui_y += 8
 local min_v, max_v = minmax(stats.scores)
 local ax = make_ax(
   34,gui_y,70,20,
   1, max(#stats.scores, 2),
   min_v, max_v
 )

 if stats.frame >= 1 then
  color(scheme.red)
  plot(xs,ys,ax,pset)

  -- Add current score to grid
  if stats.frame >= #stats.scores then
    local x, y = axpoint(ax,#stats.scores,stats.current_score)
    pset(x,y,scheme.stats_current)
  end
 end

 -- Draw axes
 ax.px -= 4
 ax.w += 12
 ax.h += 2
 color(scheme.txt)
 draw_ax(ax,1,min_v,3)

 color(scheme.txt)
 printr(loglabel(ax.y1), ax.px-2, ax.py)
 printr(loglabel((ax.y1-ax.y0) / 2), ax.px-2, ax.py + ax.h \ 2)
 printr(loglabel(ax.y0), ax.px-2, ax.py + ax.h)

 gui_y+=30

 local hist_frame = stats.frame - stats.hicard_frame
 local mv = nil
 if stats.frame >= stats.num_frames then
  mv = state.max_val-2
 end

 print("HIGH CARD DISTRIBUTION", 23, gui_y, scheme.stats_subtitle)
 gui_y+=8

 draw_high_card_dist(
   gui_y, subhist(stats.hicards, hist_frame), mv)
 draw_top_buttons("GAME","⬅️")
end

function loglabel(x)
 local num_zeros = flr(x)
 local fractional_part = x-num_zeros
 local digit = 9
 for i, v in pairs(log10_lookup) do
  if fractional_part < v then
   digit = i - 1
   break
  end
 end
 local s = tostr(digit)
 if num_zeros == 1 then
  s ..= "0"
 elseif num_zeros == 2 then
  s ..= "00"
 elseif num_zeros == 3 then
  s ..= "k"
 elseif num_zeros == 4 then
  s ..= "0k"
 elseif num_zeros == 5 then
  s ..= "00k"
 elseif num_zeros == 6 then
  s ..= "m"
 end
 return s
end

function subhist(hist, max_n)
 local sum = 0
 local new_hist = {}
 for k,n in pairs(hist) do
  new_hist[k] = max(0, min(n, max_n - sum))
  sum += n
 end
 return new_hist
end

function draw_high_card_dist(y, hist, current_mv)
 hist = shallowcopy(hist)

 if current_mv then
  hist[current_mv] += 1
 end
 local present = {}
 for v,n in pairs(hist) do
  if n != 0 then
   add(present, v)
  end
 end

 function draw_bars(start_index, x, w)
  local vals, vals_c = {}, {}
  for i=start_index,min(start_index+5,#present) do
   local v = present[i]
   if v == current_mv then
    add(vals,0)
    add(vals_c,hist[v])
   else
    add(vals,hist[v])
    add(vals_c,0)
   end
  end
  local bar_height = 6
  local spacing = 2
  local min_w = 10
  local ax = make_ax(x+min_w,y,w-min_w)
  local _,max_x = minmax(hist)
  max_x = max(max_x, 5)
  color(scheme.red)
  hbar(vals,ax,bar_height,spacing,max_x)
  color(scheme.stats_current)
  hbar(vals_c,ax,bar_height,spacing, max_x)

  for i=start_index,min(start_index+5,#present) do
   local bar_y = y + (bar_height+spacing) * (i  - start_index)
   local is_current = present[i] == current_mv
   local txt_col = (
     is_current
     and scheme.stats_current_txt
     or scheme.stats_txt)
   local n = hist[present[i]]
   rectfill(x, bar_y, x+min_w, bar_y+bar_height,
            is_current
            and scheme.stats_current
            or scheme.red)
   print(tostr(present[i]), 1+x, 1+bar_y, txt_col)
   smallnum(n,
        x+min_w + n\ax.dx - 3 - 4*(#tostr(n)-1),
        3+bar_y,txt_col)
  end
 end

 if #present <= 6 then
   draw_bars(1, 23, 82)
 else
   draw_bars(1, 23, 40)
   draw_bars(7, 73, 40)
 end
end

function smallnum(n,x,y,c)
 x = x or @0x5f26
 y = y or @0x5f27
 c = c or @0x5f25
 n = tostr(n)
 pal(7,c)
 palt(0,1)
 for i=1,#n do
  spr(tonum(sub(n,i,i)),x + (i-1) * 4, y)
 end
 pal()
end

-->8
-- plotting
-- plots

function round(x)
 return (x-flr(x)<0.5 and
  flr or ceil)(x)
end

function lerp(t,x0,x1)
 return x0 *(1-t) + (x1-x0)*t
end

function make_ax(posx,posy,
  width,height,x0,x1,y0,y1)
 local ax= {
   px=posx,py=posy,
   w=width,h=height,
   x0=x0,x1=x1,y0=y0,y1=y1
 }
 if x0 and x1 then
  ax.dx = (x1-x0)/width
 end
 if y0 and y1 then
  ax.dy = (y1-y0)/height
 end
 return ax
end

function axpoint(ax,x,y)
  return ax.px +
         round((x-ax.x0)/ax.dx),
         ax.py + ax.h -
         round((y-ax.y0)/ax.dy)
end

function linfun(fn,x0,x1,n)
 local xs,ys = {},{}
 for x=x0,x1,(x1-x0)/n do
  add(xs,x)
  add(ys,fn(x))
 end
 return xs, ys
end

function plotfn(fn,ax,addpt,x0,x1)
 ax.x0 = ax.x0 or x0
 ax.x1 = ax.x1 or x1
 if not ax.dx then
  ax.dx = (ax.x1-ax.x0)/width
 end

 local xs,ys=linfun(fn,ax.x0,ax.x1,ax.w)
 plot(xs,ys,ax,addpt)
end

function minmax(xs)
 local x0, x1
 for i=1,#xs do
  x0=min(x0,xs[i])
  x1=max(x1,xs[i])
 end
 return x0, x1
end

function plot(xs,ys,ax,addpt)
 addpt = addpt or line
 if not (ax.x0 and ax.x1) then
  local x0, x1 = minmax(xs)
  ax.x0 = ax.x0 or x0
  ax.x1 = ax.x1 or x1
  ax.dx = (ax.x1-ax.x0)/ax.w
 end
 if not (ax.y0 and ax.y1) then
  local y0, y1 = minmax(ys)
  ax.y0 = ax.y0 or y0
  ax.y1 = ax.y1 or y1
  ax.dy = (ax.y1-ax.y0)/ax.h
 end

 if addpt==line then
  line()
 end
 for i=1,#xs do
  local x,y = axpoint(ax,xs[i],ys[i])
  addpt(x,y)
 end
end

function draw_ax(ax,x,y,dotted)
 dotted = (dotted==true and 2) or dotted or 0
 x = x or 0
 y = y or 0
 x,y = axpoint(ax,x,y)
 local x0,y0 = axpoint(ax,ax.x0,ax.y0)
 local x1,y1 = axpoint(ax,ax.x1,ax.y1)
 if dotted > 1 then
  for xi=ax.px,ax.px+ax.w,dotted do
   pset(xi,y)
  end
  for yi=ax.py,ax.py+ax.h,dotted do
   pset(x,yi)
  end
 else
  line(x,y0,x,y1)
  line(x0,y,x1,y)
 end
end

function xticks(ax)
 local x0, x1 = tostr(ax.x0),tostr(ax.x1)
 local y = ax.py+ax.h+2

 print(x1,ax.px+ax.w,y)
 print(x0,ax.px,y)
end

function yticks(ax)
 local y0, y1 = tostr(ax.y0),tostr(ax.y1)
 local x = ax.px-1

 print(ax.y1,x-4*#y1,ax.py)
 print(ax.y0,x-4*#y0,ax.py+ax.h)
end

function hbar(
  xs,ax,bar_width,spacing,max_x)
 bar_width=bar_width or 1
 spacing = spacing or 0
 if not max_x then
  _,max_x = minmax(xs)
 end

 ax.w = ax.w or max_x
 ax.h = ax.h or #xs*(bar_width+spacing) - spacing
 ax.dx = ax.dx or max_x/ax.w
 ax.dy = ax.dy or #xs/ax.h
 ax.x0 = ax.x0 or 0
 ax.y0 = ax.y0 or 0

 for i=1,#xs do
  local x0, x1 = ax.px, ax.px+xs[i]/ax.dx
  local y0, y1
  if ax.dy < 0 then
   y0 = ax.py+ax.h-i*(bar_width+spacing)
   y1 = y0-bar_width
  else
   y0 = ax.py+(i-1)*(bar_width+spacing)
   y1 = y0+bar_width
  end
  if x1-x0 > 0 then
   rectfill(x0, y0, x1, y1)
  end
 end
end


-->8
-- drawing

w, h = 128, 128
tw = 16

light_scheme = {
 -- frames
 frame_base=5,
 frame_rim=6,
 go_base=5,
 go_rim=9,
 -- cards
 card_txt=0,
 high_txt=8,
 red=8,
 red_shad=2,
 blue=12,
 blue_shad=13,
 card_base=7,
 card_shad=9,
 --buttons
 btn_base=13,
 btn_shad=1, --1/5
 btn_txt=7,
 -- other backgrounds & text
 bg=7,
 grid_base=6,
 card_slot=13,
 txt=13,
 score_txt=0,
 tile_score=9,
 stats_txt=7,
 stats_current=9,
 stats_current_txt=0,
 stats_subtitle=6
}

dark_scheme = {
 -- frames
 frame_base=5, --0
 frame_rim=6, --5
 go_base=5,--0
 go_rim=8,
 -- cards
 card_txt=0,
 high_txt=10,
 red=8,
 red_shad=2,
 blue=12,
 blue_shad=5, --5/1
 card_base=13, --5/6/13
 card_shad=1, --1/2/5/
 --buttons
 btn_base=13, --1
 btn_shad=0,
 btn_txt=7,
 -- other backgrounds & text
 bg=1, --1/0
 grid_base=0, --5/1/0
 card_slot=1,
 txt=13, --6/5
 score_txt=7,
 tile_score=7,
 stats_txt=7,
 stats_current=10,
 stats_current_txt=0,
 stats_subtitle=13
}

scheme = dark_scheme

function tile_col(v)
  local _ENV = scheme
  local c1,c2 = card_base, card_shad
  if v == 0 then
    c1 = card_slot
    c2 = c1
  elseif v == 1 then
    c1,c2=blue, blue_shad
  elseif v == 2 then
    c1,c2=red, red_shad
  end
  return c1, c2
end
function tile_txt_col(v,mv)
 if v > 2 then
  local c = scheme.card_txt
  if v > 11 then
   if v == mv then
    c = 14
   else
    c = 15
   end
  elseif v == mv and mv > 3 then
   c = scheme.high_txt
  end
  return c
 end
end
function tile_label(v)
 return (v-2)%10 + (v-2)\10
end
function draw_tile(x,y,v,mv)
 local c1,c2 = tile_col(v)
 local tc = tile_txt_col(v,mv)
 local x1,x2 = x+4, x+13
 local y_mid = y + 12 - tonum(v >= 6) - tonum(v >= 11)
 rectfill(x1,y+2,x2,y_mid,c1)
 rectfill(x1,y_mid+1,x2,y+13,c2)

 if tc then
  print(tile_label(v),
        x + 0.5*tw,
        y + 0.25*tw,tc)
 end
end

function draw_next_pieces(pieces)
 rectfill((w-3*tw)/2,8,
          (w+3*tw)/2,8+tw,
          scheme.bg)
 if type(pieces) == "number" then
  pieces = {pieces}
 end

 local width = #pieces*tw

 rectfill((w-width)/2,8,
          (w+width)/2,8+tw,
          scheme.grid_base)
 for i, p in ipairs(pieces) do
  draw_tile((w-width)/2+(i-1)*tw,8,p)
 end
 printc("NEXT", 65, 8+tw+2, scheme.btn_base)
end

function grid_pos(i, j)
 local sx = (w/2 - gw*tw/2)
 local sy = (h/2 - gw*tw/2) + 10
 return sx+(i-1)*tw, sy+(j-1)*tw
end

function draw_back(w, h, x_off)
 local sx, sy = grid_pos(1,1)
 local ex, ey = grid_pos(w+1, h+1)
 x_off = x_off or 0
 rectfill(sx-2 + x_off,
          sy-2,
          ex+2 + x_off,
          ey+2,
          scheme.grid_base)
end

function draw_grid(grid, x_off, mask, dir)
 local w, h, max_val = #grid[1], #grid, maximum(grid)
 x_off = x_off or 0

 local dx, dy = move2dirs(dir or 0)
 draw_back(w, h, x_off)

 mapgrid(
   function(i,j,v)
     local x, y = grid_pos(i,j)
     x += x_off
     -- hack: always draw centred backing
     draw_tile(x,y,0)
     if mask and mask[j][i] then
      x+=2*dx
      y+=2*dy
     end
     draw_tile(x,y,v,max_val)
   end,
   grid)

end

-->8
-- sound
function ifsfx(n,o,l)
 if settings.sfx_on then
  sfx(n,3,o,l)
 end
end

function btnsfx()
 ifsfx(61)
end

function slidesfx()
 ifsfx(61 + rndint(2))
end


-->8
-- utils

function divmod(x,d)
 return x\d, x%d
end

function xor(a,b)
 return (a or b) and not (a and b)
end

function move2dirs(move)
 local h = move\2
 local d = band(move, 1)*2-1
 return d*(1-h),  d*h
end

function transpose(t)
 local r = {}
 for i=1,#t[1] do
  r[i] = {}
  for j=1,#t do
   r[i][j]=t[j][i]
  end
 end
 return r
end

function reverse(t)
 local r = {}
 for i=1,#t do
  r[i] = t[1+#t-i]
 end
 return r
end

function mapgrid(f, grid)
 local ng = {}
 for j=1,#grid do
  add(ng, {})
  for i=1,#grid[j] do
   add(ng[j], f(i, j, grid[j][i]))
  end
 end
 return ng
end

function shallowcopy(t)
 local copy = {}
 for k,v in pairs(t) do
  copy[k]=v
 end
 return copy
end

function deepcopy(t)
 local new={}
 for k, v in pairs(t) do
  if type(v) == "table" then
   v = deepcopy(v)
  end
  new[k] = v
 end
 setmetatable(new, getmetatable(t))
 return new
end

function keys(t)
 local keyset={}
 for k,v in pairs(t) do
  add(keyset,k)
 end
 return keyset
end

function any(t)
 for v in all(t) do
  if v then
   return true
  end
 end
 return false
end

function maximum(t)
 local to_search={t}
 local res = 0x8000
 while #to_search > 0  do
  local k, table = next(to_search)
  del(to_search, table)
  for v in all(table) do
   if type(v) == "table" then
    add(to_search,v)
   elseif type(v) == "number" then
    res = max(res,v)
   end
  end
 end
 return res
end

function choose(t)
 if type(t) == "number" then
  return t
 end
 local i = rndint(#t)
 return t[i]
end

function bucket(b)
 b = deepcopy(b)
 local choice = choose(b)
 return del(b,choice), b
end

function rndint(s,e)
 if e == nil then
  e = s
  s = 1
 end
 return flr(rnd(e-s+1)) + s
end

function sort(t, cmp)
 cmp = cmp or function(a,b) return a<b end
 t = shallowcopy(t)

 for i=2,#t do
  for j=i,2,-1 do
   if cmp(t[j-1],t[j]) then break end
   t[j], t[j-1] = t[j-1], t[j]
  end
 end
 return t
end

function joinlists(lists)
 local result = {}
 for list in all(lists) do
  for v in all(list) do
   add(result, v)
  end
 end
 return result
end

function text_width(s)
 local l = print(s,0,200)
 return l
end

function printc(s,x,y,c)
 y = y-- or @0x5f27
 c = c-- or @0x5f25
 for i, line in pairs(str_split(s,"\n")) do
  print(line,x-text_width(line)\2,y,c)
  y += 6
 end
end
function printr(s,x,y,c)
 y = y-- or @0x5f27
 c = c-- or @0x5f25
 for i, line in pairs(str_split(s,"\n")) do
  print(line,x-text_width(line),y,c)
  y += 6
 end
end
function print_border(s, x, y, c, sc)
 sc = sc or 0
 y = y or @0x5f27
 c = c or @0x5f25
 local shift_cursor = false
 if x == nil then
  shift_cursor = true
  x = @0x5f26
 end

 for bx=-1,1 do
  for by=-1,1 do
   print(s, x+bx, y+by, sc)
  end
 end
 print(s, x, y, c)
 if shift_cursor then
  poke(0x5f27, y+6)
 end
end

function str_in(ss, s)
 for i=1,#s-#ss+1 do
  if sub(s, i,i+#ss-1) == ss then
   return true
  end
 end
 return false
end

function str_reverse(s)
 local ns=""
 for i=1,#s do
  ns..=sub(s,-i,-i)
 end
 return ns
end

function str_concat(strs)
 local s=""
 for ss in all(strs) do
  s..=ss
 end
 return s
end

function str_divvy(s, n)
 local subs = {}
 for i=1,#s,n do
  add(subs, sub(s,i,i+n-1))
 end
 return subs
end

function str_lstrip(s,ss)
 local start = 1
 while (start <= #s and
   str_in(sub(s,start,start), ss)) do
  start+=1
 end
 return sub(s,start)
end

function str_split(s,d)
 local result = {}
 while #s do
  for i=1,#s do
   if sub(s,i,i) == d then
    add(result,sub(s,1,i-1))
    s = sub(s,i+1,#s)
    break
   elseif i == #s then
    goto split_done
   end
  end
 end
 ::split_done::
 add(result,s)
 return result
end

function lmap(f,l)
 local nl={}
 for v in all(l) do
  add(nl, f(v))
 end
 return nl
end

function filter(f,l)
 local nl={}
 for v in all(l) do
  if f(v) then
   add(nl,v)
  end
 end
 return nl
end

function coalive(c)
 return costatus(c) ~= "dead"
end
-->8
-- titlescreen

title_y = 20
titlescreen = {}

function titlescreen.init()
 mode = titlescreen

 grid = make_grid(4,3)
 for i=3,max_ever_val() do
  k,j=divmod(i-3,4)
  grid[k+1][j+1]=i
 end

 titlescreen.grid = grid
end

function titlescreen.update()
 load("ones.p8")
end

function draw_top_buttons(l_txt,l_ico,l_press,r_txt,r_ico,r_press)
  local y = 15
  draw_button(23,y,l_ico,l_press,
              scheme.btn_base,
              scheme.btn_shad)
  print(l_txt,23,y+10,scheme.btn_base)
  if r_txt then
   draw_button(93,y,r_ico,r_press,
               scheme.btn_base,
               scheme.btn_shad)
   printr(r_txt,93+14,y+10,scheme.btn_base)
  end
end

function titlescreen.draw()
 print("o",55,title_y,scheme.red)
 print("n",59,title_y,scheme.blue)
 print("es!",63,title_y,scheme.txt)

 draw_grid(titlescreen.grid)

 draw_long_boy({text="play ones ⬆️"},
   32,104,true)

 draw_top_buttons("MENU","▤",btn(4),
                  "LEARN","\^:00495d4900000000",btn(5))
end

-->8
function apply_settings()
 scheme = settings.night
   and dark_scheme or light_scheme
 music_playing = stat(57)
 if settings.music_on and not music_playing then
  music(0)
 elseif not settings.music_on and music_playing then
  music(-1, 300)
 end
end

function draw_button(x,y,i,pressed,c1,c2,long)
 y += pressed and 1 or 0
 local w = long and 78 or 12
 rectfill(x,y,x+w,y+8,c1)
 if (not pressed) line(x,y+9,x+w,y+9,c2)
 if long then
   printc(i,x+w/2,y+2,scheme.btn_txt)
 else
   print(i,x+3,y+2,scheme.btn_txt)
 end
end

function button_col(selected, on)
 local _ENV = scheme
 if selected then
  return blue, blue_shad
 end
 if on then
  return red, red_shad
 end
 return btn_base, btn_shad
end

function draw_long_boy(e,x,y,selected,pressed)
  local c1,c2 = button_col(selected, true)
  draw_button(x-7,y,e.text,pressed,c1,c2,true)
end


-->8
-- bigint

bigint = {}
bigint__meta = {}

function bigint__rem_0s(b)
 local i = #b.coef
 while i > 0 and b.coef[i] == 0 do
  b.coef[i] = nil
  i -= 1
 end
end

function bigint__tokenise(s)
 -- extract sign
 local sign = true
 if sub(s,1,1) == "-" then
  s = sub(s,2)
  sign = false
 end

 -- strip leading 0s
 s = str_lstrip(s,"0")
 sign = sign or #s == 0

 -- strip , and terminate on .
 local ns = ""
 for i=1,#s do
  local c = sub(s,i,i)
  if c == "." then break
  elseif c~="," then
   ns ..= c
  end
 end
 ns = str_divvy(str_reverse(ns), 2)
 return sign,lmap(str_reverse,ns)
end

function bigint__add(b1,b2)
 if #b1.coef < #b2.coef then
  b1,b2 = b2, b1
 end

 b1 = deepcopy(b1) --bigint_copy(b1)

 local carry,c1,c2 = 0, b1.coef, b2.coef
 for i=1,#c1 do
  carry, c1[i] =
    divmod(c1[i]+c2[i]+carry,
           100)
  if carry == 0 and i >= #c2 then
   break
  end
 end
 if carry ~= 0 then
  c1[#c1+1] += carry
 end
 return b1
end

function bigint__sub(b1, b2)
 if b1 < b2 then
  return -bigint__sub(b2,b1)
 end

 b1 = deepcopy(b1)

 local carry,c1,c2 = 0, b1.coef, b2.coef
 for i=1,#c1 do
  carry, c1[i] =
    divmod(c1[i]-c2[i]+carry,
           100)
  if carry == 0 and i >= #c2 then
   break
  end
 end
 if carry ~= 0 then
  c1[#c2+1] += carry
 end
 -- remove leading 0s
 bigint__rem_0s(b1)
 return b1
end

function bigint__meta.__add(b1,b2)
 b1 = bigint_as_bigint(b1)
 b2 = bigint_as_bigint(b2)
 if b1.sign and not b2.sign then
  return b1-(-b2)
 elseif b2.sign and not b1.sign then
  return b2-(-b1)
 end
 return bigint__add(b1,b2)
end

function bigint__meta.__sub(b1, b2)
 b1 = bigint_as_bigint(b1)
 b2 = bigint_as_bigint(b2)
 if b1.sign and not b2.sign then
  return b1+(-b2)
 elseif b2.sign and not b1.sign then
  return -((-b1)+b2)
 end
 return bigint__sub(b1,b2)
end

-- better algorithms exist but
-- i simply do not know them
function bigint__meta.__mul(b1,b2)
 b2 = bigint_as_bigint(b2)
 b1 = deepcopy(b1) --bigint_copy(b1)
 b1.sign = not xor(b1.sign,b2.sign)

 local c1, c2 = b1.coef, b2.coef
 local l1,l2=#c1,#c2
 local lt = l1+l2
 local x, carry

 local buckets={}
 for i=1,lt do
  add(buckets,{})
 end

 for i=1,l1 do
  for j=1,l2 do
   carry,x = divmod(c1[i] * c2[j],100)
   add(buckets[i+j-1],x)
   add(buckets[i+j],carry)
  end
 end
 for i=1,lt do
  -- for very large numbers
  -- the lack of divmod per
  -- sum might cause overflow
  x=0
  for v in all(buckets[i]) do
   x+=v
  end
  carry, c1[i] = divmod(x,100)
  add(buckets[i+1],carry)
 end
 bigint__rem_0s(b1)
 return b1
end

function bigint__meta.__pow(b,n)
  acc = deepcopy(b) --bigint_copy(b)
 for i=2,n do
  acc *= b
 end
 return acc
end

function bigint__meta.__unm(b)
 if #b.coef == 0 then
  return b
 end
 b = deepcopy(b) --bigint_copy(b)
 b.sign = not b.sign
 return b
end

function bigint__meta.__eq(b1,b2)
 return not (b1 < b2 or b2 < b1)
end

function bigint__meta.__lt(b1,b2)
 b1 = bigint_as_bigint(b1)
 b2 = bigint_as_bigint(b2)
 if b1.sign != b2.sign then
  return not b1.sign and b2.sign
 end
 local c1, c2 = b1.coef, b2.coef
 if #c1 != #c2 then
  return not xor(b1.sign,
                 #c1 < #c2)
 end
 for i=#c1,1,-1 do
  if c1[i] != c2[i] then
   return
     not xor(b1.sign,
             c1[i]<c2[i])
  end
 end
 return false
end

function bigint__meta.__concat(x,y)
 return tostr(x)..tostr(y)
end

function bigint__meta.__tostring(b)
 return bigint_tostr(b, true)
end

function bigint_tostr(b, commas)
 if #b.coef == 0 then
  return "0"
 end
 local start = #b.coef
 local s = ""
 -- build string from components
 for i=start,1,-1 do
  local ss = tostr(b.coef[i])
  if #ss ~= 2 then
   s ..= "0"
  end
  s ..= ss
 end
 -- remove leading 0s
 s = str_lstrip(s,"0")

 local ns
 if commas then
  -- add commas
  ns = sub(s,-1,-1)
  for i=2,#s do
   if i % 3 == 1 then
    ns ..= ","
   end
   ns ..= sub(s,-i,-i)
  end
 else
  ns = str_reverse(s)
 end

 -- add negative
 if not b.sign then
  ns..="-"
 end
 return str_reverse(ns)
end

function bigint__new()
 local b = {coef={}, sign=true}
 setmetatable(b, bigint__meta)
 setmetatable(b.coef,{
  __index=function()return 0end})
 return b
end

function bigint_new(s)
 if type(s) == "number" then
  s = tostr(s)
 end
 -- assert(#s > 0)

 local ts
 local b = bigint__new()
 b.sign, ts = bigint__tokenise(s)
 for i=1,#ts do
  add(b.coef, tonum(ts[i]))
 end
 return b
end

function bigint_as_bigint(v)
 if type(v) == "number" or
    type(v) == "string" then
  return bigint_new(v)
 end
 return v
end

log10_lookup = {
  0.0, 0.3010299956639812, 0.47712125471966244, 0.6020599913279624, 0.6989700043360189, 0.7781512503836436, 0.8450980400142568, 0.9030899869919435, 0.9542425094393249
}

function poorlog10(b)
 --assert(b > 0)
 local str = bigint_tostr(b)
 return log10_lookup[tonum(sub(str, 1,1))] + #str - 1
end

-->8
-- saving

-- 256 bytes to play with
-- bits [0,15): last_name
-- bits [15,19]: setting flags

-- bits [20, 63]: unused

-- bytes [8,128): hiscore boards

-- bytes [128,139): saved game
-- - [128,136): board
-- - [136,140): bucket
--   - 4 bits for length
--   - 26 bits for pieces
--   - (13 x 2 bits each)
--   - first piece is next piece

-- bits [139*8 + 6, 140*8) unused

-- bytes [140, 152) hi-card histogram

-- byte 152: score history ring index
-- bytes [153,256): saved scores ring buffer
--  = 102 bytes
-- each score is 8 bits fixed-point xxx.xxxxx log10
-- so we get 102 scores


board_start_byte=8
max_boards=12
bytes_per_board=10

function load_data()
 return {
  settings=load_settings(),
  last_name=load_last_name(),
  boards = load_boards(),
  saved_scores = load_scores()
 }
end

function load_scores()
 -- load scores for graph
 return nil
end

function clear_save()
 memset(store_addr+128,0,8)
end

function save_grid(grid,start_byte)
 local b = grid2bytes(state.grid)
 b = conv_pack_bits(b,4)
 store_save_bytes(b, start_byte)
end

function load_grid(start_byte)
 local b = store_load_bytes(start_byte,8)
 b = conv_unpack_bits(b,4,16)
 if maximum(b) == 0 then
  return nil
 end
 return conv_bytes2grid(b,4,4)
end

function save_game()
 -- save the current game
  -- board + bucket
 -- (total 11 bytes):
 -- board: 8 bytes (16 * 4 bits)
 save_grid(state.grid,128)
 -- now save bucket
 -- 4 bits for length
 -- 26 bits for pieces
 -- (13 pieces, 2 bits per piece)
 -- total 4 bytes
 local np = state.next_pieces
 if type(np) == "table" then
  np = 4
 end

 -- todo: shift bucket -1
 --       and np -1
 --       to shave tokens
 local b = lmap(function(x) return x-1 end,
   state.piece_bucket)
 b = conv_pack_bits(
   joinlists({
     -- flip endianness of #b bc im dum
     {#b & 3, (#b>>>2) & 3, np-1, deli(b, 1)},
     b
   }), 2)

 store_save_bytes(b, 136)
end

function load_game()
 -- load current game
 local grid = load_grid(128)
 if not grid then
  return nil, nil
 end
 local b = store_load_bytes(136,4)
 local len = b[1] & 15
 -- +3 for l(2) and np(1)
 b = conv_unpack_bits(b,2,len+3)
 b = lmap(function(x) return x+1 end,b)
 -- ignore length
 deli(b,1)
 deli(b,1)
 -- first piece is np
 local np = deli(b,1)
 return grid, np, b
end

function save_board(board)
 local sb = board_start_byte
    + (board.save_slot-1)
      * bytes_per_board
 save_grid(board.grid,sb)
 save_name(board.name,sb+8)
end

function make_board(grid,name,save_slot)
 return {
  grid=grid,
  score=calculate_score(grid),
  max_val=maximum(grid),
  name=name,
  save_slot=save_slot
 }
end

function cmp_score(a,b)
 return a.score > b.score
end

function load_boards()
 -- load high score boards
 local boards = {}
 for i=1,max_boards do
  local sb = board_start_byte
    + (i-1)*bytes_per_board
  local grid = load_grid(sb)
  if not grid then
   break
  end
  add(boards, make_board(
    grid,load_name(sb+8),i))
 end
 boards = sort(boards,cmp_score)

 return boards
end

function load_settings()
 local b = store_load_bytes(1,2)
 local mus = b[1]&0x80==0
 b = conv_unpack_bits({b[2]},1,4)
 return {
  music_on=mus,
  sfx_on=b[1]==0,
  night=b[2]==1,
  autosign=b[3]==1,
  boost=b[4]==1
 }
end

function load_name(start_byte)
 local b = store_load_bytes(start_byte, 2)
 b = conv_unpack_bits(b,5,3)
 return conv_bytes2str(b,enc.abc)
end

function load_last_name()
 local s = load_name(0)
 return s ~= "aaa" and s or nil
end

function grid2bytes(grid)
 return joinlists(grid)
end

function bytes2grid(bytes, n, m)
 local grid = {}
 for j=1,n do
  add(grid,{})
  for i=1,m do
   add(grid[j], bytes[(j-1)*m+i])
  end
 end
 return grid
end


-- general purpose store library

enc = {}
conv = {}
store_addr = 0x5e00
enc.abc = {
 chr = {},
 ord = {}
}
_chr_str = "abcdefghijklmnopqrstuvwxyz ,.?!" .. [["]]

function store_init()
 cartdata("ones-data")

 for i=1,#_chr_str do
  enc.abc.chr[i-1] = sub(_chr_str,i,i)
 end

 for _,encoding in pairs(enc) do
  for i,c in pairs(encoding.chr) do
   encoding.ord[c] = i
  end
 end
end

function conv_bool2byte(b)
 return b==true and 1 or b==false and 0
end

function conv_pack_bits(bytes, n_bits)
 local packed = {}
 local mask = 2^n_bits - 1
 local acc = 0
 local bits_filled = 0
 for byte in all(bytes) do
  acc += (byte&mask)<<bits_filled
  bits_filled += n_bits
  if bits_filled >= 8 then
   add(packed, acc & 0xff)
   acc = (acc>>>8) & 0xff
   bits_filled %= 8
  end
 end
 if bits_filled > 0 then
  add(packed, acc)
 end
 return packed
end

function conv_unpack_bits(packed, n_bits, n_bytes)
 local bytes = {}
 local mask = 2^n_bits-1
 local j = 1
 local acc = packed[j]
 local bits_left = 8
 for i=1,n_bytes do
  local byte = acc & mask
  acc >>>= n_bits
  bits_left -= n_bits
  if bits_left <= 0 then
   local rmr = -bits_left
   j += 1
   acc = packed[j] or 0
   byte+=(acc & (2^rmr-1))<<(n_bits-rmr)
   acc >>>= rmr
   bits_left = 8 - rmr
  end
  add(bytes, byte)
 end
 return bytes
end

function conv_str2bytes(str, encd)
 encd = encd or enc.ascii
 local bytes = {}
 for i=1,#str do
  add(bytes, encd.ord[sub(str,i,i)])
 end
 return bytes
end

function conv_bytes2str(bytes,encd)
 encd = encd or enc.ascii
 local str = ""
 for b in all(bytes) do
  str ..= encd.chr[b]
 end
 return str
end
function conv_bytes2grid(bytes, n, m)
  local grid = {}
  for j=1,n do
    add(grid,{})
    for i=1,m do
      add(grid[j], bytes[(j-1)*m+i])
    end
  end
  return grid
end

function store_save_bytes(bytes,start_byte)
  for i=1,#bytes do
    poke(store_addr + start_byte
           + i - 1, bytes[i])
  end
end

function store_load_byte(start_byte)
 return store_load_bytes(start_byte, 1)[1]
end

function store_load_bytes(start_byte,n)
 local bytes = {}
 local last_byte = start_byte+n-1
 -- assert(start_byte >= 0
 --         and last_byte <= 0xff)
 for i=start_byte,last_byte do
   add(bytes,peek(store_addr+i))
 end
 return bytes
end
-->8
-- easing

ease = {i={},o={},io={}}

function ease.i.quad(x)
 return x*x
end

function ease.i.quart(x)
 return x^4
end

function ease.i.elastic(x)
 local c = 1 / 3

 return x == 0 and 0 or
       (x==1 and 1 or
        -2^((x-1)*10) * -sin((x * 10 - 10.75) * c))
end

function join(f1,f2,x1)
 x1 = x1 or .5
 return function(x)
  if x < x1 then
   return f1(x/x1)/2
  else
   return .5+f2((x-x1)/(1-x1))/2
  end
 end
end

for name, fn in pairs(ease.i) do
 ease.o[name] = function(x)
  return 1 - fn(1-x)
 end
end
ease.o.bounce, ease.i.bounce =
  ease.i.bounce, ease.o.bounce

for name, fn in pairs(ease.i) do
 ease.io[name] =
  join(fn, ease.o[name])
end

function tween(t, ease,
  x0, x1, finish)
 t = flr(t*30)-1
 ease = ease or easelinear
 x0 = x0 or 0
 x1 = x1 or 1
 return cocreate(function()
  local i,d,finished=0,1,false
  local v
  while true do
   if i <0 or i > t then
    finished=true
   end
   v = i/t
   yield({x0 + (x1-x0) * ease(v),
          v,
          finished})
   i+=d
   if i < 0 or i > t then
    if finish=="reflect" then
     d=-d
     i+=d
    elseif finish=="wrap" then
     i=0
    elseif finish=="stick" then
     i=t
    else
     break
    end
   end
  end
 end)
end

function animate(t, ease,
  x0, x1, fn, finish)
 return cocreate(function()
  local t = tween(t,ease,x0,x1,finish)
  local _, v = coresume(t)
  while coalive(t) do
   fn(v[1])
   yield(v[2])
   _, v = coresume(t)
  end
 end)
end

__gfx__
77700000770000007700000077000000707000000770000070000000777000007770000077700000000000000000000000000000000000000000000000000000
70700000070000000700000007700000777000000700000077700000007000000700000077700000000000000000000000000000000000000000000000000000
77700000777000000770000077000000007000007700000077700000007000007770000000700000000000000000000000000000000000000000000000000000
__sfx__
910800000c1500c1500c1500c1520c1420c1420c1320c1300c1200c1200c1200c1100c110181521b1521f1522415224130241202411500000000000000000000300003c000300003000030000300003000030000
910800000b1500b1500b1500b1520b1420b1420b1320b1300b1200b1200b1200b1100b1100e152131522115223152231302312023115000001400014000140001400013000000000f00000000000000000000000
910800000c1500c1500c1500c1520c1420c1420c1320c1300c1200c1200c1200c1100c110181521b1521f15224152241302412024115000000000000000000000e1500e1500e1520e1520e1520e1500e1500e150
910800000f1500f1500f1500f1520f1420f1420f1320f1300f1200f1200f1200f1100f1101b1521f15222152271522713027120271151a1001a1001a1001a1001a10000000000000000000000000000000000000
910800001115011150111501115211142111421113211130111201112011120111101111014152181521d152201522013020120201150000000000000001a1001a1001a1001a1001a1001a100000000000000000
910800000f1500f1500f1500f1520f1420f1420f1320f1300f1200f1200f1200f1100f11013152161521b1521f1521f1301f1201f1150040000000000001a1001a1001a1001a1001a1001a100000000000000000
910800000e1500e1500e1500e1520e1420e1420e1320e1300e1200e1200e1200e1200e11013152161521a1521f1521f1301f1201f1150e0000e0000e0000000000000000000c0000c0000c0000c0000000000000
c30800001072500000004000761500000006150000000000117250040000000076150000000615174001800007625000000761500000000000000019600004000762500400076150000000000076150000007615
cd080000045140040007524000000c524000000000000000045140040005524004001040000400174001800028614000000051400000196140040002524000000051400400025240000000524000000000000000
91080000000000000000000000000000000000000000000000000000000000000000000000000000000000000e0400e0400e03000000000000000000000000000c0300c0300c0300000000000000000000000000
910800000e0000e0000e000000000f0000f0000f000000000c0000c0000c000000000a0000a0000a000000000b000000000c00000000000000000000000000001a1201a1201a1201a1201a1201a1200000000000
910800001b1301b1301b1301b1301b120161201612016120131201312016120161201612000000000000000000000000000000000000000000000000000000001312013120131201312013120131201312013120
910800001413014130141301413014130000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
91080000000000000000000000000000000000000000000000000000000000000000000000000000000000001a1301a1301a13000000000000000000000000001812018120181201812018120181200000000000
9108000017140171401314013140131401114011140111400e1400e1400b1400b1400b14007140071400714000000000000000000000000000000000000000000000000000000000000000000000000000000000
010800000000000000000000000000000000000000000000182341823218235000000000000000000000000024700247002470000000000000000000000000001823418232182350000024700247002470000000
010800001873018720187150000000000000000000000000172341723217235000000000000000000000000018710187101871500000000000000000000000001723417230172301723217222172221721217215
01080000000000000000000000000000000000000000000018234182321823500000000000000000000000001b7501b7201b71500000000000000000000000001823418230182301823218222182221821218215
010800001b7301b7201b71500000000000000000000000001d2341d2321d235000000000000000000000000000000000000000000000000000000000000000001d2341d2321d2350000000000000000000000000
0108000000000000000000000000000000000000000000001b2341b2321b235000000000000000000000000000000000000000000000000000000000000000001b2341b2301b2301b2321b2221b2221b2121b215
0108000000000000000000000000000000000000000000001a2341a2321a235000000000000000000000000000000000000000000000000000000000000000001a2341a2321a2350000000000000000000000000
0108000000000000000000000000000000000000000000001a2341a2321a235000000000000000000000000026750267202671500000000000000000000000001a2341a2301a2301a2321a2221a2221a2121a215
a90800002360023600236002360023600236002360023600236002360023600236002360013540135401354018540185401854018540185400000000000000001a5401a5401a5401a5401a540000000000000000
c10800001b5401b5401b54000000000000000000000000001d5401d5401d54000000000000000000000000001e5401f5401f5401f5401f5401f54000000000001b5401b5401b5401b5401b5401b5401b5401b540
c10800000000000000000000000000000000000000000000000000000000000000000000000000000000000018540185401854018540185401854000000000001854018540185401854018540185400000000000
a908000018540185401854018540185401754017540175401754017540000000000000000000001a5401a5401a5401a5401a5401a540000000000000000000001854018540185401854018540000000000000000
a90800000000000000000000000000000000000000000000000000000000000000000000013530135301353018540185401854018540185400000000000000001a5401a5401a5401a5401a540000000000000000
a90800001b5301b5301b53000000000000000000000000001d5301d5301d53000000000000000000000000001f5401f5401f54000000000000000000000000002354024540245400000000000000000000000000
a90800002354024540245400000000000000000000000000205202052020520205200000000000000000000020520205202052020520000001f5201f5201f5201d5101d5101d51000000000001f5201f5201f520
a90800001f5201f5201f5201f5201f5201f52000000000001a5301a5301a530000000000000000000000000018530185301853018530185301853000000000001753017530175300000000000185301853018530
a9080000000000000000000000000000000000000000000018530185301853000000000000000000000000001a5401a5401a5401a5401a5401a54000000000001b5301b5301b5300000000000000000000000000
c10800001d5201d5201d52000000000001f5201f5201f52000000000000000000000000001b5201b5201b5201f5101f515000001b5001b5001b50000000000001854018540185400000000000000000000000000
a9080000185401854018540185401854000000000000000000000000000000000000000000000000000000001a5401a5401a5401a5401a5400000000000000001b5401b5401b5401b5001b5001a5401a5401a540
a90800001a5001a5001a5000000000000000001a5401a540175401754017540000000000000000000000000018540185401854000000000000000000000000001a5401a5401a5400000000000000000000000000
a9080000000000000000000000000000000000000000000018540185401854000000000000000000000000001a5401a5401a5401a5401a5400000000000000001b5401b5401b5401b5401b5401b5401b5001b500
a9080000000000000000000000000000000000000000000018520185201852000000000000000000000000001f5301f5301f5301f5201f5201f52000000000001d5101d510000000000000000000000000000000
a90800002052020520205202052020520205201f5201f520205202052020520000000000000000000001d5201d5201d5201d5201d5200000000000000001b5201b5201b5201b5201b520000001a5201a5201a520
a908000020500205002050020500205001a5301a5301a530135301353013530000000000000000000001d5001753017530175301753017530135301353013530185301853018530000001a5301a5301a53000000
a908000000000000000000000000000000000000000000000000000000000000000000000000000000000000185301853018530000000000000000000001b5301b5301b53000000000000000000000000001d530
a90800001d5301d5301d530000001a5301a5301a5301a530000000000000000000001b5201b5201b5201b52000000000000000000000000001d5301d5301d5301d5301d5301d530000000000000000000001f530
a90800001f5301f5301f5301f5301f5300000000000000000000000000000000000000000000001f5301f53024530245300000000000000000000000000000001f5301f5301f5300000000000000000000000000
a90800001d5301d5301d5301d5301f5301f5301f5301f5300000000000000000000018530185301853018530000000000000000195301a5301a5301a5301a530000000000000000000001b5301b5301b5301b530
a908000000000000000000000000000001d5301d5301d5301f5301f5301f53000000000001d5301d5301d530205302053020530000001f5301f5301f5301f5301d5301d5301d530000001f5301f5301f53000000
a908000000000000000000000000000001f5301f5301f5301b5301b5301b5301b530000000000000000000001a5301a5311753017530175300000000000000001a5301a5301a5300000000000175301753017530
a90800001855018550185501855000000000000000000000185501855018550185500000000000000000000014530145301453014530000000000000000000001453014530145301453000000000000000000000
a90800001355013550135501355000000000000000000000135501355013550135500000000000000000000011530115301153011530000000f5300f5300f5300e5300e5300e5300e5300e530000000000000000
912000000c0300c0300c0300c0300c0300c0300c0300c0300c0200c0200c0200c0200c0200c0200c0200c0200c0100c0100c0100c0100c0100c0100c0100c0100c0100c0100c0100c0100c0100c0100c0100c010
912000000f0300f0300f0300f0300f0300f0300f0300f0300f0200f0200f0200f0200f0200f0200f0200f0200f0100f0100f0100f0100f0100f0100f0100f0100f0100f0100f0100f0100f0100f0100f0100f010
912000001303013030130301303013030130301303013030130201302013020130201302013020130201302013010130101301013010130101301013010130101301013010130101301013010130101301013010
010800001f0101f0101f0201f0201f0301f0301f0201f0301f0301f0301f0301f0301f0401f0401f0401f04023050230502304023040230502305023060230602306023060230502305023070230702307023070
910800001f6001f6001f6001f6001f6001f6001f6001f6001f6101f6101f6101f6101f6101f6101f6101f61023610236102361023610236102361023620236202362023620236302363023630236402364023650
910800002364023640236302363023620236202362023620236202362023620236102361023610236102361523600236002360023600236002360023600236000000000000000000000000000000000000000000
010800000000000000000000000000000000000000000000000000000000000000000000000000000000000018750187201871500000000000000000000000000000000000000000000000000000000000000000
010800001873018720187150000000000000000000000000000000000000000000000000000000000000000018710187101871500000000000000000000000000000000000000000000000000000000000000000
01080000000000000000000000000000000000000000000000000000000000000000000000000000000000001b7501b7201b71500000000000000000000000000000000000000000000000000000000000000000
010800001b7301b7201b715000000000000000000000000000000000000000000000000000000000000000001d7501d7201d71500000000000000000000000000000000000000000000000000000000000000000
010800001d7301d7201d715000000000000000000000000000000000000000000000000000000000000000001d7101d7101d71500000000000000000000000000000000000000000000000000000000000000000
010800000000000000000000000000000000000000000000000000000000000000000000000000000000000013750137201371500000000000000000000000000000000000000000000000000000000000000000
010800001373013720137150000000000000000000000000000000000000000000000000000000000000000018750187201871500000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
051800000e7500f75011750137501475016750187501a7501b7501d7501f750207502275000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
911000000411011233176030a30300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200000000000000000000000000000000000e61014610196101a6201b6201b6301a6301a620196101861017610136103c60000600000000000000000000000000000000000000000000000000000000000000
020100000000000000000000000000000000000e6100f61011610136201362014630156301563025630276302f640326403c60000600000000000000000000000000000000000000000000000000000000000000
__music__
00 00074344
00 01074344
00 02074344
00 03074344
00 04074344
00 05074344
00 06090744
00 01074344
00 00074344
00 01074344
00 020a0744
00 030b0744
00 040c0744
00 05074344
00 060d0744
00 010e0744
00 00340744
00 01350744
00 02074344
00 03360744
00 04370744
00 05380744
00 06090744
00 01390744
00 000f3a07
00 01100744
00 020f0747
00 03110744
00 04120744
00 05130744
00 06140744
00 01153132
00 16334344
00 17424344
00 18424344
00 19424344
00 1a424344
00 1b424344
00 1c424344
00 1d424344
00 1e424344
00 1f424344
00 20424344
00 21424344
00 22424344
00 23424344
00 24424344
00 25424344
00 26424344
00 27424344
00 28424344
00 29424344
00 2a424344
00 2b424344
00 2c424344
00 2d424344
02 2e2f3044
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
02 41424344
