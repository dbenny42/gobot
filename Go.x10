// code for gameplay

import x10.io.Console;
import x10.util.HashMap;

public class Go {
  
  public static positionsSeen:HashMap[BoardState, Boolean] = new HashMap[BoardState, Boolean]();

  public static def main():void {
    positionsSeen.clear();

    Console.OUT.println("Welcome to Go!");

  }
}
