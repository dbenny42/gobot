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
}
