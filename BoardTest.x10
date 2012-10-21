public class BoardTest {

  public static def parseMove(move:String, height:Int, width:Int):Int {

    if (move.length() < 2)
      return -1;
    
    val rowChar = move.charAt(0);
    val rowOff = (rowChar - 'a')*width;
    val colAdd = Int.parseInt(move.substring(1));
    
    return rowOff + colAdd;
  }

  public static def main(argv:Array[String]{self.rank==1}) {

    if (argv.size < 2) {
      Console.OUT.println("Please gimme some args.");
      return;
    }

    val HEIGHT = Int.parseInt(argv(0));
    val WIDTH = Int.parse(argv(1));    

    var toMove:Stone = Stone.BLACK;
    var move:String;
    var moveIdx:Int;

    var b:BoardState = new BoardState(HEIGHT, WIDTH);

    b=b.doMove(3, 3, Stone.WHITE);
    b=b.doMove(3, 4, Stone.WHITE);
    b=b.doMove(2, 5, Stone.WHITE);
    b=b.doMove(1, 5, Stone.WHITE);
    b=b.doMove(4, 5, Stone.WHITE);
    b=b.doMove(5, 5, Stone.WHITE);
    b=b.doMove(3, 6, Stone.WHITE);
    b=b.doMove(3, 7, Stone.WHITE);

    b=b.doMove(3, 2, Stone.BLACK);

    b=b.doMove(2, 4, Stone.BLACK);
    b=b.doMove(2, 3, Stone.BLACK);
    b=b.doMove(2, 6, Stone.BLACK);
    b=b.doMove(2, 7, Stone.BLACK);

    b=b.doMove(4, 4, Stone.BLACK);
    b=b.doMove(4, 3, Stone.BLACK);
    b=b.doMove(4, 6, Stone.BLACK);
    b=b.doMove(4, 7, Stone.BLACK);

    b=b.doMove(3, 8, Stone.BLACK);

    b=b.doMove(5, 4, Stone.BLACK);
    b=b.doMove(5, 6, Stone.BLACK);


    

    while (true) {
      Console.OUT.println(b.print());
      Console.OUT.println("");

      Console.OUT.print(toMove.desc() + " to move: ");
      Console.OUT.flush();
      move = Console.IN.readLine();
      
      if (move.equals("")) {
	toMove = (toMove == Stone.BLACK)?Stone.WHITE:Stone.BLACK;
	continue;
      }

      moveIdx = parseMove(move, HEIGHT, WIDTH);
      b = b.doMove(moveIdx, toMove);
      if (b == null) {
	continue;
      }

      toMove = (toMove == Stone.BLACK)?Stone.WHITE:Stone.BLACK;
    }
  }  
}
