public struct Stone {
  private val repr:Int;
  private val token:Char;
  private val desc:String;

  private def this(repr:Int, token:Char, desc:String) {
    this.repr = repr;
    this.token = token;
    this.desc = desc;
  }

  public def repr():Int=repr;
  public def token():Char=token;
  public def desc():String=desc;

  public static val EMPTY = Stone(0, '+', "empty");
  public static val BLACK = Stone(1, 'O', "black");
  public static val WHITE = Stone(2, '@', "white");
  public static val TERR_B = Stone(3, '\"', "black territory");
  public static val TERR_W = Stone(4, '\'', "white terriroty");
  public static val INVALID = Stone(-1, '?', "invalid");

  public def hashCode():Int {
    return this.repr;
  }

  public static def canPlaceOn(s:Stone):Boolean {
    // Console.OUT.println("[canPlaceOn] the stone is " + s.desc);
    // Console.OUT.println("[canPlaceOn] unformatted: " + s);
    // Console.OUT.println("[canPlaceOn] unformatted val: " + Stone.BLACK);
    // Console.OUT.println("[canPlaceOn] empty: " + (s == Stone.EMPTY));
    // Console.OUT.println("[canPlaceOn] terr_b: " + (s == Stone.TERR_B));
    // Console.OUT.println("[canPlaceOn] terr_w: " + (s == Stone.TERR_W));
    // Console.OUT.println("[canPlaceOn] black: " + (s == Stone.BLACK));
    // Console.OUT.println("[canPlaceOn] white: " + (s == Stone.WHITE));
    // Console.OUT.println("[canPlaceOn] invalid: " + (s == Stone.INVALID));
    return (s == Stone.EMPTY) ||
            (s == Stone.TERR_B) ||
              (s == Stone.TERR_W);
  }

  public static def getOpponentOf(s:Stone):Stone {
    if (s == Stone.BLACK)
      return Stone.WHITE;
    else if (s == Stone.WHITE)
      return Stone.BLACK;
    else
      return Stone.INVALID;
  }

  public static def getTerritoryOf(s:Stone):Stone {
    if (s == Stone.BLACK)
      return Stone.TERR_B;
    else if (s == Stone.WHITE)
      return Stone.TERR_W;
    else
      return Stone.INVALID;
  }

  public static def getPieceOf(s:Stone):Stone {
    if (s == TERR_B)
      return Stone.BLACK;
    else if (s == Stone.TERR_W)
      return Stone.WHITE;
    else
      return Stone.INVALID;
  }
}
