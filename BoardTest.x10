public class BoardTest {

  public static def main(argv:Array[String]{self.rank==1}) {

    if (argv.size < 2) {
      Console.OUT.println("Please gimme some args.");
      return;
    }

    val HEIGHT = Int.parseInt(argv(0));
    val WIDTH = Int.parse(argv(1));    

    val b = new BoardState(HEIGHT, WIDTH);
    Console.OUT.println(b.print());

  }
}
