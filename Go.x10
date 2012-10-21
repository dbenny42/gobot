// code for gameplay

import x10.io.Console;
import x10.util.HashMap;

public class Go {
  
  public static var positionsSeen:HashMap[BoardState, Boolean] = new HashMap[BoardState, Boolean]();
  // TODO: get rid of magic numbers.
  public static var MCTNode gameTree = new MCTNode(null, new BoardState(19,19), FALSE); // FALSE gets flipped to TRUE so that black goes first.


  public static def isGameOver() {
    return gameTree.isLeaf();
  }


  // currently configured to play human against gobot.
  public static def main(var argv:Array[String]):void {

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
      if(gameTree != null) {
        positionsSeen.hash(gameTree.state);
      }

      // TODO: consider a static val of the number of consecutive passes as the game over checker.  How do we represent a pass?  doMove() returns a board state, so we can check that the new board is the same as the old board, and call that a pass.
      if(isGameOver()) {
        break;
      }

      b = b.humanMove(); // opponent sets a state.
      // TODO: how do we add the opponent's move to our gametree?
      var temp:MCTNode = gameTree.findOpponentMoveInChildren(b);
      if(temp != null) {
        gameTree = temp;
      } else {
        gameTree = new MCTNode(null, b, FALSE);
      }
      
      if(isGameOver()) {
        break;
      }
    }

    if(gameTree.state.currentLeader() == Stone.WHITE) {
      Console.OUT.println("White wins.  Black should go think about what a horrible Go player (s)he is.");
    } else if (gameTree.state.currentLeader() == Stone.BLACK) {
      Console.OUT.println("Black wins.  White should go die in a hole, as everyone wishes him/her to.");
    } else {
      Console.OUT.println("It was a tie.  Go think about the choices you've made in your pathetic life.");
    }
  }
}
