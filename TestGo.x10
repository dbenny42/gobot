class TestGo {

  public static def main(argv:Array[String]) {

    if (argv.size != 3) {
      Console.OUT.println("usage: ./Go <height> <width> <games to play>");
      return;
    }
    val height = Int.parseInt(argv(0));
    val width = Int.parseInt(argv(1));
    val gamesToPlay = Int.parseInt(argv(2));

    var gobotWins:Int = 0;
    var idiotBotWins:Int = 0;
    var ties:Int = 0;

    
    for (var i:Int = 0; i < gamesToPlay; i++) {
      val result:Int =
        Go.zeroPlayerGame(new MCTNode(new BoardState(height, width)));
      if (result == 1) {
        gobotWins++;
      } else if (result == -1) {
        idiotBotWins++;
      } else {
        ties++;
      }
    }

    Console.OUT.println("**************************************************");
    Console.OUT.println("Gobot % wins: " +
                        ((gobotWins as Double / gamesToPlay) * 100));
    Console.OUT.println("IdiotBot % wins: " +
                        ((idiotBotWins as Double / gamesToPlay) * 100));
    Console.OUT.println("% ties: " +
                        ((ties as Double / gamesToPlay) * 100));
    Console.OUT.println("**************************************************");
  }
}
