import "lib/github.com/athas/matte/colour"


type cell = #sand f32 | #empty | #wall
type marg_pos = i64
let oob: cell = #empty
type hood = (cell,cell,cell,cell)
let hood_quadrants ((ul,ur,dl,dr): hood): (cell, cell, cell, cell) =
  (ul,ur,dl,dr)

let hood_from_quadrants (ul: cell) (ur: cell) (dl: cell) (dr: cell): hood =
  (ul,ur,dl,dr)

let hood_quadrant (h: hood) (i: marg_pos): cell =
  let (ul0, ur0, dl0, dr0) = hood_quadrants h in
  if      i == 0 then ul0
  else if i == 1 then ur0
  else if i == 2 then dl0
  else                dr0

let index_to_hood (offset: i64) (i: i64): (i64, i64) =
  if offset == 0 then (i / 2, i % 2)
  else ((i+1) / 2, (i+1) % 2)

let mk_hoods [h][w] (offset: i64) (pixels: [h][w]cell): [][]hood =
  let get (i, j) = if i >= 0 && i < h && j >= 0 && j < w
                   then #[unsafe] pixels[i,j] else oob
  in tabulate_2d (h/2-offset) (w/2-offset)
     (\i j -> hood_from_quadrants (get (i*2+offset,j*2+offset)) (get (i*2+offset,j*2+1+offset))
                                  (get (i*2+1+offset,j*2+offset)) (get (i*2+1+offset, j*2+1+offset)))

let world_index [h][w] (offset: i64) (elems: [h][w]hood) ((i,j): (i64,i64)): cell =
  let (hi,ii) = index_to_hood offset i
  let (hj,ij) = index_to_hood offset j

  in if hi < 0 || hi >= h || hj < 0 || hj >= w
     then oob
     else hood_quadrant (#[unsafe] elems[hi,hj]) (ii*2+ij)

let un_hoods [h][w] (offset: i64) (hoods: [h][w]hood): [][]cell =
  let particle_pixel i j =
    world_index offset hoods (i,j)
  in tabulate_2d ((h+offset)*2) ((w+offset)*2) particle_pixel

let is_wall (c: cell) = c == #wall
let weight (c: cell) : i32 =
  match c
  case #sand x -> 1+i32.f32 (x*1000)
  case #wall -> 0
  case #empty -> 0

let check_if_drop (above: cell) (below: cell): (cell, cell) =
  if is_wall above || is_wall below || weight below >= weight above
  then (above, below)
  else (below, above)

let gravity (h: hood): hood =
  let (ul, ur, dl, dr) = hood_quadrants h
  let (ul, dl) = check_if_drop ul dl
  let (ur, dr) = check_if_drop ur dr
  let (ul, dr) = check_if_drop ul dr
  let (ur, dl) = check_if_drop ur dl
  in hood_from_quadrants ul ur dl dr

let drop_sand [h][w] (i: i32) (world: [h][w]cell): [h][w]cell =
  let offset = (i64.i32 i % 2) - 1
  in (mk_hoods offset world |> map (map gravity) |> un_hoods offset) :> [h][w]cell

type~ World = ?[h][w].[h][w]cell

entry step (i: i32) (w: World): World =
  drop_sand i w

entry render (w: World) =
  let pixel (p: cell) =
    match p
    case #wall -> argb.white
    case #sand x -> argb.mix x argb.black 0.5 argb.yellow
    case #empty -> argb.black
  in map (map pixel) w

entry make (h: i64) (w: i64): World =
  tabulate_2d h w (\i j -> if i == w-1 then #wall else
                           if (i+j) % 2 == 0 then #empty
                      else #sand ((1+f32.sin (f32.i64 (i^j)))/2))
