fun out s = TextIO.output (TextIO.stdOut, s)

structure Terminal =
struct
  fun rawMode () =
    prim ("@raw_mode", ()) : unit
  fun cookedMode () =
    prim ("@cooked_mode", ()) : unit
  fun columns () =
    prim ("@columns", ()) : int
  fun lines () =
    prim ("@lines", ()) : int
  fun clearScreen () = out ("\027[2J")
  fun clearLine () = out ("\027[2K")
  fun default () = out ("\027[0m")
  fun hideCursor () = out ("\027[?25l")
  fun showCursor () = out ("\027[?25h")
  fun home () = out ("\027[H")
  fun fgRGB (r, g, b) =
    out
      ("\027[38;2;" ^ Int.toString r ^ ";" ^ Int.toString g ^ ";"
       ^ Int.toString b ^ "m")
  fun bgRGB (r, g, b) =
    out
      ("\027[48;2;" ^ Int.toString r ^ ";" ^ Int.toString g ^ ";"
       ^ Int.toString b ^ "m")
end

fun putPixels (h, w, pixels) =
  let
    fun loopCols i j =
      if j = w then
        ()
      else
        let
          val rgb = Word32Array.sub (pixels, i * w + j)
          fun getByte w i =
            Word32.toInt (Word32.andb (Word32.>> (rgb, i * 0w8), 0w255))
          val r = getByte rgb 0w2
          val g = getByte rgb 0w1
          val b = getByte rgb 0w0
        in
          Terminal.fgRGB (r, g, b);
          Terminal.bgRGB (r, g, b);
          out (" ");
          loopCols i (j + 1)
        end
    fun loopRows i =
      if i = h then ()
      else (loopCols i 0; Terminal.default (); out "\n"; loopRows (i + 1))
  in
    loopRows 0;
    TextIO.flushOut TextIO.stdOut
  end

fun loop (i, ctx, world) =
  let
    fun stop () = Sandstorm.Opaque.World.free world
    fun next () =
      let
        val new_world = Sandstorm.Entry.step ctx (Int32.fromInt i, world)
        val () = Sandstorm.Opaque.World.free world
      in
        loop (i + 1, ctx, new_world)
      end
    fun render () =
      let
        val pixels_fut = Sandstorm.Entry.render ctx world
        val pixels = Sandstorm.Word32Array2.values pixels_fut
        val (h, w) = Sandstorm.Word32Array2.shape pixels_fut
        val () = Sandstorm.Word32Array2.free pixels_fut
      in
        putPixels (h, w, pixels);
        Terminal.home ()
      end
  in
    case TextIO.input1 TextIO.stdIn of
      NONE => (render (); Process.sleep (Time.fromMilliseconds 0); next ())
    | SOME #"q" => stop ()
    | SOME c => next ()
  end

fun main () =
  let
    val lines = Terminal.lines () div 2 * 2
    val columns = Terminal.columns () div 2 * 2
    val ctx = Sandstorm.Context.new Sandstorm.Config.default
    val world = Sandstorm.Entry.make ctx (lines, columns)
  in
    TextIO.StreamIO.setBufferMode
      (TextIO.getOutstream TextIO.stdOut, IO.BLOCK_BUF);
    Terminal.rawMode ();
    Terminal.default ();
    Terminal.clearScreen ();
    Terminal.hideCursor ();
    Terminal.home ();
    (loop (0, ctx, world)
     handle Sandstorm.Error e =>
       ( Terminal.cookedMode ()
       ; out (e ^ "\n")
       ; OS.Process.exit OS.Process.failure
       ));
    Terminal.cookedMode ();
    Sandstorm.Context.free ctx

  end

val () = main ()
