// code for gameplay

import x10.io.Console;
import x10.util.HashMap;

public class Go {
  
  public static var positionsSeen:HashMap[BoardState, Boolean] = new HashMap[BoardState, Boolean]();
  // TODO: get rid of magic numbers.
  public static var MCTNode gameTree = new MCTNode(null, new BoardState(19,19), FALSE); // FALSE gets flipped to TRUE so that black goes first.


  public static def generateNewMove():void {
    var tempNode = 
    gameTree = gameTree.UCTSearch(); // sets a new rooted pos of the game tree.
    while(positionsSeen.get(temp != null)) {
      possibleState = currRoot.UCTSearch();
    }

    // TODO: figure out how to get the computer to choose moves other than the already-seen positions...randomness *should* help us here.
  }


  public static def main():void {
    Console.OUT.println("Welcome to Go!");

    val HEIGHT = Int.parseInt(argv(0));
    val WIDTH = Int.parse(argv(1));    


    positionsSeen.clear();

    var tempState:BoardState = new BoardState(HEIGHT, WIDTH);
    gameTree = new MCTNode(null, tempState, FALSE); // FALSE gets flipped to TRUE so that black goes first.

    // mostly pseudocode & unimplemented stuff:
    positionsSeen.hash(gameTree.state);
    while(1) { // will break when game ends.
      // for now, the computer will play black.
      gameTree = gameTree.UCTSearch(positionsSeen); // guaranteed to return a unique move.
      positionsSeen.hash(gameTree.state);

      // TODO: consider a static val of the number of consecutive passes as the game over checker.  How do we represent a pass?  doMove() returns a board state, so we can check that the new board is the same as the old board, and call that a pass.
      if(gameOver()) {
        break;
      }

      b = b.humanMove();
      if(gameOver()) {
        break;
      }
    }
  }


}
