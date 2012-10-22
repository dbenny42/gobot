// code for gameplay

import x10.io.Console;
import x10.util.HashSet;
import x10.lang.Boolean;

public class Go {
  
  // TODO: get rid of magic numbers.

  // issue TODO: we get rid of parents when we go to check out isLeaf(), so we'll have nulls, usually.  We need to keep a counter of the number of passes we've just seen.

  public static def parseMove(move:String, height:Int, width:Int):Int {

    if (move.length() < 2)
      return -1;
    
    val startChar = 'a';
    val rowChar = move.charAt(0);
    val rowNum:Int = (rowChar.ord() - startChar.ord());
    val rowOff = rowNum*width;
    val colAdd = Int.parseInt(move.substring(1));
    
    return rowOff + colAdd;
  }

  public static def changeToMove(toMove:Stone):Stone {
    return (toMove == Stone.BLACK) ? Stone.WHITE : Stone.BLACK;
  }

  public static def gobotTurn(toMove:Stone) {

  }

  public static def humanTurn(toMove:Stone) {
    
  }

  public static def singlePlayerGame(humanStone:Stone) {
    var positionsSeen:HashSet[BoardState] = new HashSet[BoardState]();
    positionsSeen.clear();
    var tempState:BoardState = new BoardState(HEIGHT, WIDTH);
    var toMove:Stone = Stone.BLACK;
    var moveIdx:Int = 0;

    var gameTree:MCTNode = new MCTNode(tempState); // FALSE gets flipped to TRUE so that black goes first.

    positionsSeen.add(gameTree.getBoardState());

    if(humanStone == Stone.BLACK) {
      humanTurn(Stone.BLACK);
      toMove = Stone.WHITE;
    }

    while(!positionsSeen.gameisOver()) {
      computerTurn();
    }

  }

  public static def twoPlayerGame() {
    
  }

  // currently configured to play human against gobot.
  public static def main(var argv:Array[String]):void {

    Console.OUT.println("Welcome to Go!");

    if(argv.size != 4) {
      Console.OUT.println("usage: ./Go <height> <width> <1 or 2 humans>");
      return;
    }

    val HEIGHT = Int.parseInt(argv(0));
    val WIDTH = Int.parse(argv(1));
    val NUMHUMANS = Int.parse(argv(2));

    //Console.OUT.println("parsed height / width.");
    var positionsSeen:HashSet[BoardState] = new HashSet[BoardState]();
    positionsSeen.clear();
    //Console.OUT.println("created positions hashmap.");
    var tempState:BoardState = new BoardState(HEIGHT, WIDTH);
    var move:String = "";
    var toMove:Stone = Stone.BLACK;
    var moveIdx:Int = 0;

    //Console.OUT.println("about to generate game tree root.");
    var gameTree:MCTNode = new MCTNode(tempState); // FALSE gets flipped to TRUE so that black goes first.
    //Console.OUT.println("generated game tree root.");

    positionsSeen.add(gameTree.getBoardState());
    //Console.OUT.println("added gameTree root to the positions map.");

    if(NUMHUMANS == 1) {
      Console.OUT.println("It looks like you're about to start a single-player game.  Enter 1 to play as black, 0 to play as white."); 
      move = Console.IN.readLine();
      var humanStone:Stone = (Int.parse(move) == 1 ? Stone.BLACK : Stone.WHITE);
      singlePlayerGame(humanStone);
    }
    else if(NUMHUMANS == 2) {
      twoPlayerGame();
    } else {
      Console.OUT.println("invalid argument for number of humans.");
    }



    while(Boolean.TRUE) { // will break when game ends.
      Console.OUT.println(gameTree.getBoardState().print());

      // for now, the computer will play black.
      if(toMove == Stone.BLACK) {
        Console.OUT.println("the gobot is thinking....");
        gameTree = gameTree.UCTSearch(positionsSeen, Boolean.TRUE); // guaranteed to return a unique move.
        Console.OUT.println("finished gobot turn.");
        //gameTree.getBoardState().printAllLiberties();

      } else {
        Console.OUT.println("beginning a human turn.");
        // human sets a move.
        Console.OUT.println("please enter your move.");
        move = Console.IN.readLine();

        // TODO: handle cmd-line "passing".
        if(move.equals("")) {
          Console.OUT.println("you appear to be passing.  We'll take that into account.");
          toMove = (toMove == Stone.BLACK) ? Stone.WHITE : Stone.BLACK;
          gameTree = new MCTNode(gameTree.getBoardState(), Boolean.TRUE); // generate a passing node.
          continue; // TODO: our current game tree implementation does generate 'pass' children nodes, so there's no reason to try and find this node in our game tree.
        }

        //Console.OUT.println("about to try and parse move.");
        moveIdx = parseMove(move, HEIGHT, WIDTH);
        //Console.OUT.println("board before your move is implemented: ");
        //Console.OUT.println(gameTree.getBoardState().print());
        //Console.OUT.println("about to create a board state from your input.");
        tempState = gameTree.getBoardState().doMove(moveIdx, toMove);

        //Console.OUT.println("board after your piece gets placed:");
        //Console.OUT.println(tempState.print());

        if(tempState == null) {
          Console.OUT.println("invalid move, you'll get another chance.");
          continue;
        } else {
          Console.OUT.println("about to place your move in the game tree.");
          var existingNode:MCTNode = gameTree.findOpponentMoveInChildren(tempState);
          if(existingNode != null) {
            //Console.OUT.println("found your node in the game tree.");
            gameTree = existingNode;
          } else {
            //Console.OUT.println("did not find your node in the game tree.");
            gameTree = new MCTNode(tempState); // TODO: fix coloring here, when we go to generalized version.
          }

        }
        Console.OUT.println(gameTree.getBoardState().print());
        Console.OUT.println("there's the result of your move.  Hit enter for the gobot to play.");
        Console.IN.readLine();
      }

      //Console.OUT.println("board after turn swap: ");
      //Console.OUT.println(gameTree.getBoardState().print());

      //Console.OUT.println("about to switch whose turn it is.");
      toMove = changeToMove(toMove);
      positionsSeen.add(gameTree.getBoardState());

      if(gameTree.isGameOver()) {
        Console.OUT.println("the game appears to be over.");
        break;
      }
    }

    if(gameTree.getBoardState().currentLeader() == Stone.WHITE) {
      Console.OUT.println("White wins.  Black should go think about what a horrible Go player (s)he is.");
    } else if (gameTree.getBoardState().currentLeader() == Stone.BLACK) {
      Console.OUT.println("Black wins.  White should go die in a hole, as everyone wishes him/her to.");
    } else {
      Console.OUT.println("It was a tie.  Go think about the choices you've made in your pathetic life.");
    }
  }
}
