pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- ones
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
     -- special case for tut & title
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
  next_pieces=np and piece_from_np(np,mv),
  moves=allowed_moves(grid),
  max_val=mv,
  finished=false
 }
end

play = {}
clearwarn = {}
transition = {}

function transition.init(target, source, dx, dy)
 btnsfx()
 init_mode(target)
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


function play.init()
 game = make_game(true)
end

function play.update()
 game_update()

 if btnp(4) then
  menu.prior = play
  transition.init(menu, play, 0, 1)
 end

 if btnp(5) then
  load("ones-extra.p8", "back to game")
 end
end

function play.draw()
 game_draw()
 draw_next_pieces(state.next_pieces)
 draw_top_buttons("MENU","▤", btn(4),
                  "STATS","∧", btn(5))
end

function make_game(saving)
 if not state or state.finished then
  state = new_state()
  if saving then
   save_game()
  end
 end
 -- disable btnp repeating
 poke(0x5f5c, 255)
 return {
  move=nil,
  saving=saving
 }
end

function game_draw()
 local active_move = game.move
 if active_move then
  draw_grid(state.grid,nil,
            state.moves[active_move.btn].move_mask,
            active_move.btn)
 else
  draw_grid(state.grid)
 end
end

function game_update()
 local active_move = game.move
 local valid_moves = keys(state.moves)
 if #valid_moves == 0 then
  init_mode(game_over)
  return
 end

 for move in all(valid_moves) do
   if btnp(move)
     and (not active_move
          or move != active_move.btn)
   then
     game.move = {btn=move, t=t()}
     break

   elseif active_move
     and active_move.btn == move
   then
     if btnp(active_move.btn) then
       state =
         next_state(move,state)
       game.move = nil
       slidesfx()
       if game.saving then
        save_game()
       end
       break
     elseif btn(active_move.btn) then
       active_move.t = t()
     elseif t() - active_move.t > 0.75 then
       game.move = nil
       mode.drawn = false
     end
   end
 end
end

function clearwarn.init()
end

function clearwarn.update()
 if btnp(4) then
  transition.init(menu, clearwarn, 0, -1)
 elseif btnp(5) then
  clear_save()
  state = nil
  transition.init(titlescreen, clearwarn, 0, -1)
 end
end


function clearwarn.draw()
 printc("are you sure?",64,title_y,scheme.txt)

 draw_long_boy({text="keep playing 🅾️"},
   30,76,false,btn(4))

 draw_long_boy({text="end game ❎"},
   30,96,true,btn(5))

 draw_ui_grid({{text="careful!\nyou will lose\nall progress on\nyour current board"}}, 0, true, 0)
end

btn_state = {}
function _update()
 --if btn(0) and btn(1) and btn(2) and btn(3) then
 -- for i=0,63 do
 --  dset(i,0)
 -- end
 --end

 for i=0,5 do
  if (btn_state[i] != btn(i)) mode.drawn=false
 end

 mode.update()

 for i=0,5 do
  btn_state[i] = btn(i)
 end
 if not mode.drawn and mode != transition then
  cls(scheme.bg)
  mode.draw()
  mode.drawn = true
 end
end

function init_mode(new_mode)
 mode = new_mode
 mode.drawn = false
 mode.init()
end

function _init()
 store_init()
 local loaded = load_data()
 data.last_name = loaded.last_name
 data.boards = loaded.boards

 settings = loaded.settings
 apply_settings()

 local grid, np, b = load_game()
 if grid then
  state = make_state(grid, np, b)
  init_mode(play)
 else
  init_mode(titlescreen)
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
}

dark_scheme = --light_scheme
{
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

function get_letter(alpha,i)
 return alpha[i%(#alpha+1)]
end

function draw_sign_frame(xoff)
 xoff=xoff or 0
 local x0, x1 = 20+xoff, 108+xoff
 local cx = 64 + xoff
 local y0, y1 = 40, 128
 rectfill(x0,y0,
          x1,y1,
          scheme.go_rim)
 rectfill(x0+3,y0+3,
          x1-3,y1-3,
      scheme.go_base)
 print("signed by",
       x0+8, y0+10,
       scheme.btn_txt)
 for i=0,2 do
  line(x0+i,y0,cx,y0-10+i,
       scheme.go_rim)
  line(x1-i,y0)
 end
 circfill(cx,y0-7,4,
      scheme.go_base)
 printc("❎ to sign", cx,y1-10,6)
end

function draw_letter_block(x,y,alpha,i,loff,bcol,col)
 loff = loff or 0
 bcol = bcol or 7
 col = col or 0
 rectfill(x-3,y-4,
          x+3,y+8,bcol)
 color(col)
 clip(x-3,y-4,6,13)
 x -= 1  -- centre text
 print(get_letter(alpha,i),x,y+loff)
 print(get_letter(alpha,i-1),x,y-8+loff)
 print(get_letter(alpha,i+1),x,y+8+loff)
 clip()
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

function scoresfx(n)
 ifsfx(60, n-3, 1)
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

function printc(s,x,y,c)
 y = y-- or @0x5f27
 c = c-- or @0x5f25
 print(s,x-2*#s,y,c)
end
function printr(s,x,y,c)
 y = y-- or @0x5f27
 c = c-- or @0x5f25
 print(s,x-4*#s,y,c)
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
-- game over

game_over = {}

function make_letter_block(x,y,alpha,i)
 i = i or 0
 local function anim_fn(yoff)
  draw_letter_block(x,y,alpha,
    i,yoff,7,5)
 end
 local anim = animate(100,ease.o.quad,
   0,0,anim_fn,"stick")
 while true do
  if yield(alpha[i]) == true then
   if btnp(2) or btnp(3) then
    local d=1
    if btnp(2) then
     d = -1
    end
    i=(i+d)%(#alpha+1)
    anim = animate(1,
      ease.o.elastic,
      d*8,0, anim_fn, "stick")
   end
  end
  coresume(anim)
 end
end

function get_init_name_char(encd, i)
 encd = encd or enc.ascii
 return encd.ord[data.last_name and sub(data.last_name,i,i) or "a"]
end

function make_name_bar(x,y,n_letters,encd)
 encd = encd or enc.ascii
 local selected, letters = 1,{}
 spacing = 8
 for i=1,n_letters do
  local j = -n_letters\2+i
  add(letters, cocreate(make_letter_block))
  coresume(letters[i],x+j*spacing,y,
           encd.chr,
           get_init_name_char(encd, i))
 end
 yield("")
 while true do
  local current = {}
  for i=1,n_letters do
   j = -n_letters\2+i
   local c = selected==i and
       scheme.red or 6
   print("⬆️",x+j*spacing-3, y-10,
     c)
   print("⬇️",x+j*spacing-3, y+10,
     c)
   local _, l = coresume(
     letters[i],selected==i)
   add(current,l)
  end
  if btnp(0) then
   selected = ((selected-2)%n_letters) + 1
  elseif btnp(1) then
   selected = (selected%n_letters)+1
  end
  yield(str_concat(current))
 end
end

function name_prompt()
 local x, y = 64, 74
 local anim = animate(
   1, ease.o.quart,
   128, 0, function(dx)
    draw_sign_frame(dx)
    for i=-1,1 do
     draw_letter_block(
       x+i*8+dx,y,
       enc.abc.chr,
       get_init_name_char(enc.abc,i+2),
       0,7,5)
    end
   end, "stick")
 repeat
  yield()
  local _, ratio = coresume(anim)
 until ratio == 1

 local name_bar = cocreate(make_name_bar)
 coresume(name_bar,x,y,3,enc.abc)
 while true do
  draw_sign_frame()
  local _, s = coresume(name_bar)
  yield(s)
 end
end

function draw_tile_score(
  i,j,score,is_max,v)
 local lifetime,dy = 1.5, 10
 local cx, y = grid_pos(i,j)
 cx += 10
 y  -=  3
 score = tostr(score)
 cx -= 2*#score
 local col = is_max
  and scheme.high_txt
       or scheme.tile_score

 local function draw_t(y)
  print_border(score,cx,y,col)
 end

 local anim = animate(lifetime,
   ease.o.quart,
   y+dy, y, draw_t,"stick")
 local alive, ratio = true, 0
 yield(0)
 scoresfx(v)
 while not yield(ratio < 1/3) do
  alive, ratio =
    coresume(anim)
 end
 while true do
  draw_t(y)
  yield(false)
 end
end

--function print_list(l)
-- local s = "["
-- for v in all(l) do
--  s ..= tostr(v) .. ","
-- end
-- s ..= "]"
-- printh(s)
--end
--function print_table(t,pad_i)
-- local pad_i = pad_i or 0
-- local pad = ""
-- for i=1,pad_i do
--  pad ..= " "
-- end
--
--
-- for k, v in pairs(t) do
--  if type(v) == "table" then
--   printh(pad .. tostr(k)..": ")
--   print_table(v, pad_i+1)
--  else
--   printh(pad .. tostr(k)..": "..tostr(v))
--  end
-- end
--end

function score_list(grid,mv)
 local list = joinlists(mapgrid(
  function (i, j, v)
   local score = score_tile(v)

   if score > 0 then
    local c = cocreate(draw_tile_score)
    coresume(c,i,j,
             score,
             v>3and v==mv,
             v)
    local l = {c=c,i=i,j=j,score=score}
    return l
   end
  end,
  grid))

 list = filter(
  function (x) return x ~= nil end,
  list)

 list = sort(list,
             function(a,b)
               return (a.score < b.score
                       or (a.score == b.score
                           and a.j > b.j))
 end)
 return list
end

function tally_scores(scores)
 local bottom_txt="❎ to calculate your score"
 while not yield(true) do
   printc(bottom_txt,64,118,
          scheme.txt)
 end
 printc(bottom_txt,64,118,
        scheme.txt)

 -- score animation
 local done = false
 while not (yield(true) or done) do
  bottom_txt="❎ to skip"
  local score = 0
  done = true
  for s in all(scores) do
   local _, blocked = coresume(s.c)
   score += s.score
   if blocked then
    done = false
    break
   end
  end
  printc(tostr(score),64,30,
         scheme.score_txt)
  printc(bottom_txt,64,118,
         scheme.txt)
 end
 bottom_txt="❎ to sign your name"
 score = tostr(score)
 -- display forever
 local blocking = true
 while true do
  foreach(scores,function(s)
   coresume(s.c, true)
  end)
  printc(score, 64, 30,
         scheme.score_txt)
  printc(bottom_txt,64,118,
         scheme.txt)
  if blocking then
   blocking = not yield(true)
  else
   yield(false)
  end
 end
end

function game_over.init()
 local tally = cocreate(tally_scores)
 coresume(tally, score_list(state.grid, state.max_val))
 game_over.tally_scores = tally
 game_over.name_prompt = nil
 game_over.score = calculate_score(state.grid)
 game_over.complete = false
end

function game_over.update()
 game_over.drawn = false
end

function game_over.draw()
 printr("out of moves!",100,title_y,scheme.txt)

 draw_grid(state.grid)
 local _, blocked = coresume(game_over.tally_scores, btnp(5))
 local name
 if blocked then
  return
 end

 if settings.autosign and data.last_name ~= nil then
  name = data.last_name
 else
  game_over.name_prompt =
    game_over.name_prompt or cocreate(name_prompt)
  _, name = coresume(game_over.name_prompt)
  if not (btnp(5) and name) then
    return
  end
 end
 if not game_over.complete then
  data.last_name = name
  save_last_name(name)
  sign_board(state.grid,state.max_val,name)
  -- We need this flag to keep the drawing working!
  state.finished = true
  clear_save()
  game_over.complete = true
  menu.prior = game_over
  transition.init(menu, game_over, 0, 1)
 end
end

function sign_board(grid,max_val,name)
 local board =
   make_board(grid,name,nil)

 save_score(board.score)
 add_histogram(max_val)

 -- find save slot
 if #data.boards < max_boards then
  -- we have spare saves
  board.save_slot=#data.boards+1
 elseif data.boards[#data.boards].score
   < board.score then
  -- we're better than the worst save
  board.save_slot =
    data.boards[#data.boards].save_slot
 end

 if board.save_slot then
   save_board(board)
 end

 data.boards = load_boards()
 data.last_board = board
end
-->8
-- titlescreen

title_y = 20
titlescreen = {}

function titlescreen.init()

 local grid = make_grid(4,3)
 for i=3,max_ever_val() do
  k,j=divmod(i-3,4)
  grid[k+1][j+1]=i
 end

 state=make_state(grid, nil, {})

 game=make_game(false)
end

function titlescreen.update()
 game_update()
 state.next_pieces = nil
 if btnp(4) then
  menu.prior = titlescreen
  transition.init(menu, titlescreen, 0, 1)

 -- all this handles
 -- play/tutorial
 elseif btn(5) then
  if btnp(5) then
   btnsfx()
   titlescreen.play_t = t()
  elseif t() - titlescreen.play_t > 0.5 then
   state = nil -- clear our game
   init_mode(play)
  end
 elseif btn_state[5] then
  -- tutorial
  load("ones-extra.p8", "back to title")
 else
  titlescreen.play_t=nil
 end
end

function titlescreen.draw()
 print("o",55,title_y,scheme.red)
 print("n",59,title_y,scheme.blue)
 print("es!",63,title_y,scheme.txt)

 game_draw()

 draw_long_boy({text="hold ❎ to play"},
   32,104,true,btn(5))

 draw_top_buttons("MENU","▤",btn(4),
                  "LEARN","\^:00495d4900000000",btn(5))
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

-->8
-- menu

menu = {}
-- useful symbols:
--  credits/thanks ★
--  stats ∧
--  🅾️❎⬅️⬇️⬆️➡️
--  thanks ♥
--  home/title ⌂
--  loading ⧗
--  웃☉ˇ🐱
--  music ♪
--  on/off ☉🅾️❎◆

panel_width = 90

back_button = {
 icon="❎"
}


app_opts = {
 subtitle="app options",
 {
  text="music",
  icon="♪",
  toggle="music_on"
 }, {
  text="sfx",
  icon="ˇ",
  toggle="sfx_on"
 }, {
  text="night colors",
  icon="░",
  toggle="night"
 }
}
game_opts = {
 subtitle="game options",
 {
  text="autosign",
  icon="웃",
  toggle="autosign"
 }, {
  text="boost",
  icon="★",
  toggle="boost"
 }
}

credits = {
 {
  {
   text="3 people made 3s!\nthreesgame.com"
  }, {
   text="asher vollmer",
   prefix="DESIGNED BY"
  }, {
   text="greg wohlwend",
   prefix="ILLUSTRATED BY"
  }, {
   text="jimmy hinson",
   prefix="MUSIC BY"
  }
 }, {
  {
   text="1 eejit made 1s!\njamiebayne.co.uk"
  }, {
   text="jamie bayne",
   prefix="CLONED BY"
  }
 }
}
panels = {
 [0]={
  --app options
  title="options",
  ui=app_opts
 }, {
  --game options
  title="options",
  ui=game_opts
 }, {
 --credits
  title="credits",
  ui=credits[1]
 }, {
  title="credits",
  ui=credits[2]
 }
}
clear_panel={
 title="clear scores",
 ui={
  {
   text="clears the data\nnot the memories"
  }, {
   text="clear scores",
   action=function()
    for i=-1,menu.min_panel do
     menu.panel[i] = nil
    end
    clear_boards()
    menu.min_panel = 0
    shift_panel(0)
   end
  }
 }
}

titlescreen_button = {
 text="main menu",
 action=function()
  if menu.prior == game_over then
   return transition.init(titlescreen, menu, 0, -1)
  end
  transition.init(clearwarn, menu, 0, 1)
 end
}

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

function draw_finished_board(board, x_off)
 local cx=64+x_off

 if board == data.last_board then
  rectfill(28+x_off, 38, 100+x_off, 110, 10)
 end
 draw_grid(board.grid, x_off)

 print(board.name,
       84+x_off,110,
       scheme.txt)
 local score = tostr(board.score)
 printc(score, cx, 120,
        scheme.score_txt)

 local y2=32
 local x1,_=grid_pos(1,1)
 local x2,y1=grid_pos(gw+1,1)
 x1+=x_off+4
 x2+=x_off-4
 y1-=3
 line(x1,y1,cx,y2-2,
      scheme.frame_rim)
 line(x2,y1)
 circfill(cx,y2,2,
          scheme.frame_base)
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

function draw_text_back(x,y,rows)
 rows = rows or 1
 local r = 4
 local h=rows*2*r
 color(scheme.grid_base)
 rectfill(x,y,x+70,y+h)
 rectfill(x-r,    y+r,
          x,      y+h-r)
 rectfill(x+70,   y+r,
          x+70+r, y+h-r)
 circfill(x,y+r,r)
 circfill(x,y+h-r,r)
 circfill(x+70,y+r,r)
 circfill(x+70,y+h-r,r)
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

function draw_toggle(e,x,y,selected,pressed)
 local c1, c2 = button_col(selected,
   settings[e.toggle])
 local ico=settings[e.toggle] and "/" or "x"
 draw_text_back(x-3,y-2)
 circfill(x-1,y+2,3,c1)
 printc(ico,x,y,
        scheme.btn_txt)
 print(e.text, x+8,y,
       scheme.txt)
 draw_button(x+59,y-3,
             e.icon,pressed,c1,c2)
end

function draw_long_boy(e,x,y,selected,pressed)
 local c1,c2 = button_col(selected, true)
 draw_button(x-7,y,e.text,pressed,c1,c2,true)
end

function draw_ui_grid(ui, index, enabled, panel_x)
 index = index or 0
 enabled = enabled == nil and true or enabled
 local x_off=index*panel_width - panel_x
 local x,y,dy = 30+x_off,40,14
 if ui.subtitle then
  print(ui.subtitle, x, y,
        scheme.txt)
  y+=dy
 end
 local btn_index = 1
 for e in all(ui) do
  if is_btn(e) then
   local focus = ui.selected==btn_index
   local d = e.toggle
     and draw_toggle or draw_long_boy
   d(e,x,y,
     enabled and focus,
     enabled and btn(5) and focus
   )
   btn_index += 1
  else
   if e.prefix then
    print(e.prefix,x-2,y-3,
          scheme.txt)
    y += 5
   end
   local text = split(e.text,"\n")
   draw_text_back(x-3,y-2,#text)
   for i,line in ipairs(text) do
    print(line,x-2,y+(i-1)*8,
          scheme.txt)
   end
   y+=dy*(#text-1)
  end
  y+=dy
 end
end

function draw_panel(panel,i,panel_x)
 if panel.board then
  draw_finished_board(panel.board,i*panel_width-panel_x)
 elseif panel.ui then
  draw_ui_grid(panel.ui, i, menu.panel==i, panel_x)
 end
end

function shift_panel(d)
 local panel=mid(menu.min_panel,
                 menu.panel+d,
                 #menu.panels)
 if panel ~= menu.panel then
  slidesfx()
  menu.cam_anim = animate(
    0.5, ease.o.quart,
    menu.panel_x,
    panel*90,
    function (x)
      menu.panel_x = x
    end)
  if menu.panels[panel]["title"] ~=
      menu.panels[menu.panel]["title"] then
   local cam = menu.cam_anim
   menu.title_y=-20
   menu.cam_anim = cocreate(
    function()
     local a1, a2 = cam,
       animate(0.5,
         ease.o.quart,
         -20,title_y,
         function(y)
          menu.title_y = y
         end)
     local _,v = coresume(a1)
     coresume(a2)
     while coalive(a1) do
      yield(v)
      _,v = coresume(a1)
      coresume(a2)
     end
    end)
  end

  menu.panel=panel
 end
end

function is_btn(e)
 return e.toggle or e.action
end

function shift_selection(ui,d)
 ui.selected = mid(
   1,
   ui.selected + d,
   #filter(is_btn,ui))
end

function press_button(ui)
 btnsfx()
 local btn = filter(is_btn,ui)[ui.selected]
 if btn == nil then
  return
 end
 if btn.toggle then
  settings[btn.toggle] =
    not settings[btn.toggle]
  apply_settings()
  save_settings()
 elseif btn.action then
  btn.action()
 end
end

function is_last_board(board)
 return data.last_board and data.last_board.save_slot == board.save_slot
end

function menu.init()
  menu.cam_anim = nil
  menu.panel=0
  menu.panels = deepcopy(panels)
  menu.title_y = title_y
  if menu.prior ~= titlescreen then
    add(menu.panels[0].ui,
        titlescreen_button)
  end

  local back_panels = {}
  if menu.prior == game_over then
   add(back_panels, {
    board=data.last_board
   })
  end
  for i=1,#data.boards do
   board = data.boards[i]
   if menu.prior ~= game_over or not is_last_board(board) then
      --data.last_board.index ~= i then
    add(back_panels, {
     board=board
    })
   end
  end
  if #data.boards ~= 0 then
   add(back_panels, clear_panel)
  end
  for i=1,#back_panels do
   menu.panels[-i] = back_panels[i]
   menu.min_panel = -i
  end

  if menu.prior == game_over then
   menu.panel = -1
  end
  for _,p in pairs(menu.panels) do
    p.ui = p.ui or {}
    p.ui.selected = 1
  end
  menu.panel_x = menu.panel*panel_width
end

function menu.draw()
 for i,panel in pairs(menu.panels) do
  draw_panel(panel,i,menu.panel_x)
 end

 local title =
   menu.panels[menu.panel].title
 if title then
  printr(title,
         103, menu.title_y,
         scheme.txt)
 end
 draw_top_buttons(menu.prior == game_over
                   and "RETRY"
                   or "BACK","⬅️",btn(4))
end

function menu.update()
 local blocked = false
 if menu.cam_anim then
  local _, pct =
    coresume(menu.cam_anim)

  if coalive(menu.cam_anim) then
   blocked = pct < 0.3
   menu.drawn=false
  else
   menu.cam_anim = nil
  end
 end
 if not blocked then
  local cur_ui =
    menu.panels[menu.panel].ui

  menu.panel_x = menu.panel * 90
  if btnp(0) then
   shift_panel(-1)
  elseif btnp(1) then
   shift_panel(1)
  elseif btnp(2) then
   shift_selection(cur_ui,-1)
  elseif btnp(3) then
   shift_selection(cur_ui,1)
  elseif btnp(4) then
   if menu.prior==game_over then
    transition.init(play, menu, 0, -1)
   else
    transition.init(menu.prior, menu, 0, -1)
   end
  elseif btnp(5) then
    press_button(cur_ui)
  end
 end
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

function poorlog10(b)
 local lookup = {
   0.0, 0.3010299956639812, 0.47712125471966244, 0.6020599913279624, 0.6989700043360189, 0.7781512503836436, 0.8450980400142568, 0.9030899869919435, 0.9542425094393249
 }
 --assert(b > 0)
 local str = bigint_tostr(b)
 return lookup[tonum(sub(str, 1,1))] + #str - 1
end

-->8
-- saving

-- 256 bytes to play with
-- bits [0,15): last_name
-- bits [15,19]: setting flags

-- bits [20, 63]: unused
--   could use this for #games

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

function clear_boards()
 -- clear high score boards
 data.boards = {}
 memset(store_addr+8,0,120)
 memset(store_addr+140,0,116)
end

function clear_save()
 memset(store_addr+128,0,8)
end

function save_name(name, start_byte)
 local b = conv_str2bytes(name,enc.abc)
 b = conv_pack_bits(b,5)

 local last = store_load_byte(start_byte+1)
 b[2] = (127&b[2]) + (last&(1<<7))
 store_save_bytes(b,start_byte)
end

function add_histogram(v)
 local p = 140 + mid(0,v-3,12)
 local n = store_load_byte(p)
 store_save_bytes({min(0xff, n + 1)}, p)
end

function save_score(score)
 local i = store_load_byte(152)

 store_save_bytes({(poorlog10(score) << 5) & 0xff}, 153 + i)
 store_save_bytes({(i+1) % 102}, 152)
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

function save_settings()
 local b = store_load_bytes(1,2)
 b = conv_unpack_bits(b,1,16)
 local b2b = conv_bool2byte
 b[8]  = b2b(not settings.music_on)
 b[9]  = b2b(not settings.sfx_on)
 b[10] = b2b(settings.night)
 b[11] = b2b(settings.autosign)
 b[12] = b2b(settings.boost)
 b = conv_pack_bits(b,1)
 store_save_bytes(b,1)
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

function bitstr(b)
 s=""
 for i=0,7 do
  s..=(b>>>i)&1
 end
 return s
end

function save_last_name(name)
 save_name(name,0)
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

__label__
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777776666666666677777777777777777777777777777777777777777777777777777777feeeeeeeeff7777777777777777777777777
7777777777777777777776666ccccccc66777777777777777777777777777777777777777777777777777777777777feeeeeeeeeeff777777777777777777777
7777777777777777777666ccccccccc67777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeef7777777777777777777
7777777777777777766ccccccccccc6777777777777777777777777777777777777777777777777777777777777777777feeeeeeeeeeeef77777777777777777
77777777777777776cccccccccccc677777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeef777777777777777
7777777777777766ccccccccccccc677777777777777777777777777777777777777777777777777777777777777777777feeeeeeeeeeeeeef77777777777777
77777777777776cccccccccccccc67777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeef7777777777777
7777777777776ccccccccccccccc67777777777777777777777777777777777777777777777777777777777777777777777feeeeeeeeeeeeeeee777777777777
777777777776ccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeee77777777777
77777777776cccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeef7777777777
7777777776ccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeef777777777
7777777776ccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeef77777777
777777776cccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeee77777777
77777776ccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeef7777777
77777776ccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeee7777777
7777776cccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeef777777
7777776cccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeee777777
7777776cccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeef77777
777776ccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeef77777
777776ccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeee77777
777776ccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeee77777
777776ccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeef7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeef7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc677777777777777777777777777777766d100000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc677777777777777777777777766d500000000000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777770000000000000000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777770000000000000000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777770000000000000000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777770000000000000000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777770000000000000000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777770000000000000000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc677777777777777777777777000001d667600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777775d66777777600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777600000000006777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc677777777777777777777777d000000000000000000000000000000577777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc677777777777777777777777d000000000000000000000000000000577777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc677777777777777777777777d000000000000000000000000000000577777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc677777777777777777777777d000000000000000000000000000000577777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc677777777777777777777777d000000000000000000000000000000577777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc677777777777777777777777d000000000000000000000000000000577777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc677777777777777777777777d000000000000000000000000000000577777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc677777777777777777777777d000000000000000000000000000000577777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeee7777
77776cccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeef7777
777776ccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeeef7777
777776ccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeee77777
777776ccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeee77777
777776ccccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeef77777
7777776cccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeeef77777
7777776cccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeee777777
7777776cccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeeef777777
77777776ccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeeee7777777
77777776ccccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeeeee67777777
777777776cccccccccccccccccc6777777777777777777777777777777777777777777777777777777777777777777777777eeeeeeeeeeeeeeeeee4e77777777
7777777776ccccccccccccccccc6ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeeeeeeeee44e677777777
7777777776ccccccccccccccccc6ffaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaff44444444444444444e6777777777
77777777776ccccccccccccccccc6faaaaaaaaffaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaffaaaaaaafff4444444444444444e67777777777
777777777776cccccccccccccccc6ffaaaaaafff554ffaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaf455affaaaaaafffe44444444444444e677777777777
7777777777776ccccccccccccccc6ffaaaaaafa50054aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa45005afffaaaaafe44444444444444e6777777777777
77777777777776cccccccccccccc66faaaaafa5055154aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa4505505affaaaaafe4444444444444e67777777777777
7777777777777766ccccccccccccc6ffaaaaf4054a405afaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaafa50544505faaaaafe4444444444444e677777777777777
77777777777777776ccccccccccccc6ffaaaa454ffa45afffaa44444444444444444444444444aaaafa44affa54aaaaaffe44444444444ee6777777777777777
7777777777777777766ccccccccccc66faaafaaffaaaafffffa50000000000000000000000005aaaaffaaaaaffaaaafffeee44444444ee677777777777777777
7777777777777777777666ccccccccc66faaaaaafaaaffffffa44444444444444444444444444aaaaafaaaaaaaaaafffeee444444eee67777777777777777777
77777777777777777777776666ccccccd6fffffaaaaaaaaaaaaffafffffffffffffffffffffaaaaaaaaaaaaaaaffaff44444eeeee66777777777777777777777
777777777777777777777777766666666666fffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeee6667777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777

__sfx__
91080000011500115001150011520114201142011320113001120011200112001110011100d152101521415219152191301912019115000000000000000000002500031000250002500025000250002500025000
910800000015000150001500015200142001420013200130001200012000120001100011003152081521615218152181301812018115000000900009000090000900008000000000400000000000000000000000
91080000011500115001150011520114201142011320113001120011200112001110011100d152101521415219152191301912019115000000000000000000000315003150031520315203152031500315003150
91080000041500415004150041520414204142041320413004120041200412004110041101015214152171521c1521c1301c1201c1150f1000f1000f1000f1000f10000000000000000000000000000000000000
9108000006150061500615006152061420614206132061300612006120061200611006110091520d15212152151521513015120151150000000000000000f1000f1000f1000f1000f1000f100000000000000000
9108000004150041500415004152041420414204132041300412004120041200411004110081520b15210152141521413014120141150040000000000000f1000f1000f1000f1000f1000f100000000000000000
9108000003150031500315003152031420314203132031300312003120031200312003110081520b1520f15214152141301412014115030000300003000000000000000000010000100001000010000000000000
c30800001072500000004000761500000006150000000000117250040000000076150000000615174001800007625000000761500000000000000019600004000762500400076150000000000076150000007615
cd080000045140040007524000000c524000000000000000045140040005524004001040000400174001800028614000000051400000196140040002524000000051400400025240000000524000000000000000
91080000010000100001000010000100001000010000100001000010000100001000010000100001000010000f0400f0400f03001000010000100001000010000d0300d0300d0300100001000010000100001000
910800000f0000f0000f00001000100001000010000010000d0000d0000d000010000b0000b0000b000010000c000010000d00001000010000100001000010001b1201b1201b1201b1201b1201b1200100001000
910800001c1301c1301c1301c1301c120171201712017120141201412017120171201712001000010000100001000010000100001000010000100001000010001412014120141201412014120141201412014120
910800001513015130151301513015130010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000
91080000010000100001000010000100001000010000100001000010000100001000010000100001000010001b1301b1301b13001000010000100001000010001912019120191201912019120191200100001000
9108000018140181401414014140141401214012140121400f1400f1400c1400c1400c14008140081400814001000010000100001000010000100001000010000100001000010000100001000010000100001000
010800000100001000010000100001000010000100001000192341923219235010000100001000010000100025700257002570001000010000100001000010001923419232192350100025700257002570001000
010800002573025720257152500001000010000100001000182341823218235010000100001000010000100025710257102571501000010000100001000010001823418230182301823218222182221821218215
010800000100001000010000100001000010000100001000192341923219235010000100001000010000100028750287202871501000010000100001000010001923419230192301923219222192221921219215
0108000028730287202871501000010000100001000010001e2341e2321e235010000100001000010000100001000010000100001000010000100001000010001e2341e2321e2350100001000010000100001000
0108000001000010000100001000010000100001000010001c2341c2321c235010000100001000010000100001000010000100001000010000100001000010001c2341c2301c2301c2321c2221c2221c2121c215
0108000001000010000100001000010000100001000010001b2341b2321b235010000100001000010000100001000010000100001000010000100001000010001b2341b2321b2350100001000010000100001000
0108000001000010000100001000010000100001000010001b2341b2321b235010000100001000010000100027750277202771501000010000100001000010001b2341b2301b2301b2321b2221b2221b2121b215
a90800002460024600246002460024600246002460024600246002460024600246002460014540145401454019540195401954019540195400100001000010001b5401b5401b5401b5401b540010000100001000
c10800001c5401c5401c54001000010000100001000010001e5401e5401e54001000010000100001000010001f540205402054020540205402054001000010001c5401c5401c5401c5401c5401c5401c5401c540
c10800000100001000010000100001000010000100001000010000100001000010000100001000010000100019540195401954019540195401954001000010001954019540195401954019540195400100001000
a908000019540195401954019540195401854018540185401854018540010000100001000010001b5401b5401b5401b5401b5401b540010000100001000010001954019540195401954019540010000100001000
a90800000100001000010000100001000010000100001000010000100001000010000100014530145301453019540195401954019540195400100001000010001b5401b5401b5401b5401b540010000100001000
a90800001c5301c5301c53001000010000100001000010001e5301e5301e530010000100001000010000100020540205402054001000010000100001000010002454025540255400100001000010000100001000
a90800002454025540255400100001000010000100001000215202152021520215200100001000010000100021520215202152021520010002052020520205201e5101e5101e5100100001000205202052020520
a908000020520205202052020520205202052001000010001b5301b5301b530010000100001000010000100019530195301953019530195301953001000010001853018530185300100001000195301953019530
a9080000010000100001000010000100001000010000100019530195301953001000010000100001000010001b5401b5401b5401b5401b5401b54001000010001c5301c5301c5300100001000010000100001000
c10800001e5201e5201e520010000100020520205202052001000010000100001000010001c5201c5201c5202051020515010001c5001c5001c50001000010001954019540195400100001000010000100001000
a9080000195401954019540195401954001000010000100001000010000100001000010000100001000010001b5401b5401b5401b5401b5400100001000010001c5401c5401c5401c5001c5001b5401b5401b540
a90800001b5001b5001b5000100001000010001b5401b540185401854018540010000100001000010000100019540195401954001000010000100001000010001b5401b5401b5400100001000010000100001000
a9080000010000100001000010000100001000010000100019540195401954001000010000100001000010001b5401b5401b5401b5401b5400100001000010001c5401c5401c5401c5401c5401c5401c5001c500
a90800000100001000010000100001000010000100001000195201952019520010000100001000010000100020530205302053020520205202052001000010001e5101e510010000100001000010000100001000
a90800002152021520215202152021520215202052020520215202152021520010000100001000010001e5201e5201e5201e5201e5200100001000010001c5201c5201c5201c5201c520010001b5201b5201b520
a908000021500215002150021500215001b5301b5301b530145301453014530010000100001000010001e5001853018530185301853018530145301453014530195301953019530010001b5301b5301b53001000
a908000001000010000100001000010000100001000010000100001000010000100001000010000100001000195301953019530010000100001000010001c5301c5301c53001000010000100001000010001e530
a90800001e5301e5301e530010001b5301b5301b5301b530010000100001000010001c5201c5201c5201c52001000010000100001000010001e5301e5301e5301e5301e5301e5300100001000010000100020530
a90800002053020530205302053020530010000100001000010000100001000010000100001000205302053025530255300100001000010000100001000010002053020530205300100001000010000100001000
a90800001e5301e5301e5301e5302053020530205302053001000010000100001000195301953019530195300100001000010001a5301b5301b5301b5301b530010000100001000010001c5301c5301c5301c530
a908000001000010000100001000010001e5301e5301e53020530205302053001000010001e5301e5301e53021530215302153001000205302053020530205301e5301e5301e5300100020530205302053001000
a908000001000010000100001000010002053020530205301c5301c5301c5301c530010000100001000010001b5301b5311853018530185300100001000010001b5301b5301b5300100001000185301853018530
a90800001955019550195501955001000010000100001000195501955019550195500100001000010000100015530155301553015530010000100001000010001553015530155301553001000010000100001000
a90800001455014550145501455001000010000100001000145501455014550145500100001000010000100012530125301253012530010001053010530105300f5300f5300f5300f5300f530010000100001000
912000000d0300d0300d0300d0300d0300d0300d0300d0300d0200d0200d0200d0200d0200d0200d0200d0200d0100d0100d0100d0100d0100d0100d0100d0100d0100d0100d0100d0100d0100d0100d0100d010
912000001003010030100301003010030100301003010030100201002010020100201002010020100201002010010100101001010010100101001010010100101001010010100101001010010100101001010010
912000001403014030140301403014030140301403014030140201402014020140201402014020140201402014010140101401014010140101401014010140101401014010140101401014010140101401014010
010800002001020010200202002020030200302002020030200302003020030200302004020040200402004024050240502404024040240502405024060240602406024060240502405024070240702407024070
910800002060020600206002060020600206002060020600206102061020610206102061020610206102061024610246102461024610246102461024620246202462024620246302463024630246402464024650
910800002464024640246302463024620246202462024620246202462024620246102461024610246102461524600246002460024600246002460024600246000100001000010000100001000010000100001000
010800000100001000010000100001000010000100001000010000100001000010000100001000010000100025750257202571501000010000100001000010000100001000010000100001000010000100001000
010800002573025720257150100001000010000100001000010000100001000010000100001000010000100025710257102571501000010000100001000010000100001000010000100001000010000100001000
010800000100001000010000100001000010000100001000010000100001000010000100001000010000100028750287202871501000010000100001000010000100001000010000100001000010000100001000
01080000287302872028715010000100001000010000100001000013000130001000010000100001000010002a7502a7202a71501000010000100001000010000100001000010000100001000010000100001000
010800002a7302a7202a715010000100001000010000100001000010000100001000010000100001000010002a7102a7102a71501000010000100001000010000100001000010000100001000010000100001000
010800000100001000010000100001000010000100001000010000100001000010000100001000010000100020750207202071501000010000100001000010000100001000010000100001000010000100001000
010800002073020720207150100001000010000100001000010000100001000010000100001000010000100025750257202571501000010000100001000010000100001000010000100001000010000100001000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
051800000f7501075012750147501575017750197501b7501c7501e75020750217502375001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000
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
