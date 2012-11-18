// code for gameplay

import x10.io.Console;
import x10.util.HashSet;
import x10.lang.Boolean;

public class Go {
  
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

  public static def printWinner(var currNode:MCTNode) {
    if(currNode.getBoardState().currentLeader() == Stone.WHITE) {
      Console.OUT.println("White wins.  Black should go think about what a horrible Go player (s)he is.");
    } else if (currNode.getBoardState().currentLeader() == Stone.BLACK) {
      Console.OUT.println("Black wins.  White should go die in a hole, as everyone wishes him/her to.");
    } else {
      Console.OUT.println("It was a tie.  Go think about the choices you've made in your pathetic life.");
    }
  }

  public static def computerTurn(var currNode:MCTNode, var positionsSeen:HashSet[BoardState], toMove:Stone):MCTNode {
    var nodeToAdd:MCTNode;
    Console.OUT.println("the gobot is thinking....");

    //nodeToAdd = currNode.UCTSearch(positionsSeen, toMove);
    nodeToAdd = currNode.UCTSearch(positionsSeen);


    Console.OUT.println("about to add a child node.  its pass value: " + nodeToAdd.getPass() + ", and its parent's pass value: " + nodeToAdd.getParent().getPass());

    //currNode.addRealMoveAsChild(nodeToAdd);
    
    currNode = nodeToAdd;

    // if(!currNode.getChildren().isEmpty()) {
    //   Console.OUT.println("the computer node has children, and here is one:");
    //   Console.OUT.println("**************************************************");
    //   Console.OUT.println(currNode.getChildren()(1).getBoardState().print());
    //   Console.OUT.println("**************************************************");
    // } else {
    //   Console.OUT.println("the computer node has no children.");
    // }
    
    Console.OUT.println("finished gobot turn.");
    return currNode;
  }


  public static def humanTurn(var currNode:MCTNode, var positionsSeen:HashSet[BoardState], var toMove:Stone, val HEIGHT:Int, val WIDTH:Int):MCTNode {
    var moveIdx:Int = 0;
    var moveStr:String = "";
    var tempState:BoardState = null;
    while(tempState == null || positionsSeen.contains(tempState)) {

      Console.OUT.println("please enter your move.");
      moveStr = Console.IN.readLine();
      
      if(moveStr.equals("")) {
        Console.OUT.println("you appear to be passing.  We'll take that into account.");

        //var passNode:MCTNode = new MCTNode(currNode, currNode.getBoardState(), Boolean.TRUE);
        var passNode:MCTNode = currNode.addHumanMoveToOpponentGameTree(currNode.getBoardState());
        passNode.setPass(Boolean.TRUE);
        currNode = passNode;

        // if(!currNode.getChildren().isEmpty()) {
        //   Console.OUT.println("the human node has children, and here is one:");
        //   Console.OUT.println("**************************************************");
        //   Console.OUT.println(currNode.getChildren()(1).getBoardState().print());
        //   Console.OUT.println("**************************************************");
        // } else {
        //   Console.OUT.println("the human node has no children.");
        // }

        return currNode;
      }

      // TODO: change these magic numbers after testing.
      moveIdx = parseMove(moveStr, HEIGHT, WIDTH);
      tempState = currNode.getBoardState().doMove(moveIdx, toMove);



      if(tempState == null) {
        Console.OUT.println("this move is invalid.  try again.");
        continue;
      }


      if(positionsSeen.contains(tempState)) {
        Console.OUT.println("this move has been seen before.");
        continue; // repeats loop without changing which player's turn it is.
      }
    }

    
    // takes care of all of the game tree business:
    var nodeToAdd:MCTNode = currNode.addHumanMoveToOpponentGameTree(tempState);
    currNode = nodeToAdd;

    // if(!currNode.getChildren().isEmpty()) {
    //   Console.OUT.println("the human node has children, and here is one:");
    //   Console.OUT.println("**************************************************");
    //   Console.OUT.println(currNode.getChildren()(1).getBoardState().print());
    //   Console.OUT.println("**************************************************");
    // } else {
    //   Console.OUT.println("the human node has no children.");
    // }

  
    return currNode;
  }


  /*
   * A game between one human player and one computer player.
   */
  public static def singlePlayerGame(humanStone:Stone, gameTree:MCTNode, HEIGHT:Int, WIDTH:Int) {

    var toMove:Stone = Stone.BLACK;
    var compuStone:Stone = (humanStone == Stone.BLACK) ? Stone.WHITE : Stone.BLACK;
    // tracks current position in the game tree.
    var currNode:MCTNode = new MCTNode(gameTree.getBoardState());
    var positionsSeen:HashSet[BoardState] = new HashSet[BoardState]();
    positionsSeen.clear();

    positionsSeen.add(gameTree.getBoardState());

    // if human is going first.
    // if(humanStone == Stone.BLACK) {
    //   Console.OUT.println(currNode.getBoardState().print());
    //   currNode = humanTurn(currNode, positionsSeen, Stone.BLACK);
    //   toMove = Stone.WHITE;
    // }

    while(!currNode.gameIsOver()) {
      Console.OUT.println(currNode.getBoardState().print());
      if(toMove == humanStone) {
        currNode = humanTurn(currNode, positionsSeen, toMove, HEIGHT, WIDTH);
      } else {
        currNode = computerTurn(currNode, positionsSeen, toMove);
      }
      positionsSeen.add(currNode.getBoardState());
      toMove = changeToMove(toMove);
    }
    printWinner(currNode);
  }


  /*
   * A Game between two human players.
   */
  public static def twoPlayerGame(var gameTree:MCTNode, var positionsSeen:HashSet[BoardState], HEIGHT:Int, WIDTH:Int) {
    var toMove:Stone = Stone.BLACK;
    var currNode:MCTNode = new MCTNode(gameTree.getBoardState());
    positionsSeen.add(gameTree.getBoardState());

    while(!currNode.gameIsOver()) {
      Console.OUT.println(currNode.getBoardState().print());
      currNode = humanTurn(currNode, positionsSeen, toMove, HEIGHT, WIDTH);
      positionsSeen.add(currNode.getBoardState());
      toMove = changeToMove(toMove);
    }
    printWinner(currNode);
  }





  // currently configured to play human against gobot.
  public static def main(var argv:Array[String]):void {

    Console.OUT.println("Welcome to Go!");

    if(argv.size != 3) {
      Console.OUT.println("usage: ./Go <height> <width> <1 or 2 humans>");
      return;
    }

    val HEIGHT = Int.parseInt(argv(0));
    val WIDTH = Int.parse(argv(1));
    val NUMHUMANS = Int.parse(argv(2));

    var positionsSeen:HashSet[BoardState] = new HashSet[BoardState]();
    positionsSeen.clear();
    var tempState:BoardState = new BoardState(HEIGHT, WIDTH);
    var gameTree:MCTNode = new MCTNode(tempState);

    positionsSeen.add(gameTree.getBoardState());

    if(NUMHUMANS == 1) {
      //Console.OUT.println("It looks like you're about to start a single-player game.  Enter 1 to play as black, 0 to play as white.");
      //var color:String = Console.IN.readLine();
      //var humanStone:Stone = (Int.parse(color) == 1 ? Stone.BLACK : Stone.WHITE);
      //Console.OUT.println("it looks like you chose " + humanStone.repr());
      var humanStone:Stone = Stone.WHITE;
      singlePlayerGame(humanStone, gameTree, HEIGHT, WIDTH);
    }
    else if(NUMHUMANS == 2) {
      twoPlayerGame(gameTree, positionsSeen, HEIGHT, WIDTH);
    } else {
      Console.OUT.println("invalid argument for number of humans.");
    }
  }
}
