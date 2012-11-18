// A single node in the Go game tree.

import x10.util.ArrayList;
import x10.util.Random;
import x10.util.Timer;
import x10.lang.Boolean;
import x10.util.HashSet;

public class MCTNode {

  static public val rand:Random = new Random(System.nanoTime());
  static public val PASSFLOOR:Int = -1; // completely arbitrary at this point.
  static public val TREEPOLICYCONSTANT:Double = .5; // used to compute UCB during tree policy.  Half goes to exploration; half to exploitation.
  static public val CHILDINITSIZE:Int = 10;
  static public val TIMEBOUND:Long = 10000; // 10s (10000ms)\

  // fields
  public var parent:MCTNode;
  private val turn:Boolean; // Boolean.TRUE is black, FALSE is white ("little white lies")
  private var children:ArrayList[MCTNode];
  private var timesVisited:Int;
  private var aggReward:Double;
  private var state:BoardState;
  public var pass:Boolean;
  private var actionToTry:Int;
  private var realMove:MCTNode;

  private var numAsyncsSpawned:Int = 0;
  private val MAXASYNCS:Int = 24;

  // constructors

  // the parent is in charge of generating board state, to make sure we
  // don't repeat ourselves.
  public def this(var parent:MCTNode, var state:BoardState) {
    this.parent = parent;
    this.timesVisited = 0; // only gets incremented during backprop.
    this.aggReward = 0.0; // gets set during backprop.
    this.state = state;
    this.turn = parent == null ? Boolean.FALSE : parent.turn ^ Boolean.TRUE; // XOR T flips the bit.  TODO: optimize the inital setting so we don't have to check for null parent on every node generated.
    this.actionToTry = 0;
    this.children = new ArrayList[MCTNode](CHILDINITSIZE);
    this.pass = Boolean.FALSE;
  }

  public def this(var parent:MCTNode, var state:BoardState, var pass:Boolean) {
    this.parent = parent;
    this.timesVisited = 0; //only gets incremented during backprop.
    this.aggReward = 0.0; // gets set during backprop.
    this.state = state;
    this.turn = parent == null ? Boolean.TRUE : parent.turn ^ Boolean.TRUE; // XOR T flips the bit.  TODO: optimize the inital setting so we don't have to check for null parent on every node generated.
    this.pass = pass;
    this.children = new ArrayList[MCTNode](CHILDINITSIZE);
    this.actionToTry = 0;
   }

  public def this(var state:BoardState) {
    this.parent = null;
    this.timesVisited = 0; // only gets incremented during backprop.
    this.aggReward = 0.0; // gets set during backprop.
    this.state = state;
    this.turn = parent == null ? Boolean.TRUE : parent.turn ^ Boolean.TRUE; // XOR T flips the bit.  TODO: optimize the inital setting so we don't have to check for null parent on every node generated.
    this.pass = Boolean.FALSE;
    this.children = new ArrayList[MCTNode](CHILDINITSIZE);
    this.actionToTry = 0;
  }





  /* this function allows human moves to be added to the computer game
   * tree, so we don't have to recompute children in the computer game
   * tree.
   *
   * If the proper node is found in the opponent's game tree, it is
   * returned to be set as currNode. (to preserve computer's game tree structure)
   *
   * Otherwise, the humanMove node that was passed in is returned.
   */
  public def addHumanMoveToOpponentGameTree(val humanMove:BoardState):MCTNode {
    val existingNode:MCTNode = findMove(humanMove);
    if(existingNode != null) {
      return existingNode;
    } else {
      return new MCTNode(this, humanMove); // this constructor sets the parent.
    }
  }

  // TODO: update children to be a hashset, so this is a constant-time op.
  public def findMove(val stateToFind:BoardState) {
    for(var i:Int = 0; i < children.size(); i++) {
      if(children(i).state == stateToFind) {
        Console.OUT.println("FOUND THE MOVE");
        return children(i);
      } 
    }
    Console.OUT.println("did not find move in opponent's game tree.");
    return null;
  }



  public def getParent():MCTNode {
    return parent;
  }

  // methods
  public def computeUcb(val c:Double):Double{
    // calculation involves the parent.  TODO: make sure we don't try to
    // calc this for the root node.

    var ucb:Double = (aggReward / timesVisited) + (2 * c * Math.sqrt((2 * Math.log((parent.timesVisited as Double))) / timesVisited));
    if(pass) {
      // weight passing, so it's more attractive as the game progresses.
      var weight:Double = (((state.getWhiteScore() as Double)+ (state.getBlackScore() as Double)) / (4.0 * 4.0));
      ucb = ucb * weight;
    }
    return ucb;
  }


  public def getBestChild(val c:Double):MCTNode {
    //Console.OUT.println("inside getbestchild.");
    var bestVal:Double = -99;
    var bestValArg:MCTNode = null;
    for(var i:Int = 0; i < children.size(); i++) {
      var currVal:Double = children(i).computeUcb(c);
      
      if(currVal > bestVal) {
        bestVal = currVal;
        bestValArg = children(i);
      }
    }
    return bestValArg;
  }

  public def withinResourceBound(startTime:Long):Boolean{
    val diff:Long = Timer.milliTime() - startTime;
    return TIMEBOUND > diff;
  }

  public def UCTSearch(var positionsSeen:HashSet[Int], val player:Boolean):MCTNode{

    //Console.OUT.println("current pass is: " + pass);
    val startTime:Long = Timer.milliTime();
    var passChild:MCTNode = null;

    finish {
      while(withinResourceBound(startTime)) { // TODO: implement the resource bound.
        if(numAsyncsSpawned < MAXASYNCS) {
          atomic numAsyncsSpawned++;
          async {
            var child:MCTNode = treePolicy(positionsSeen);
            var outcome:Int = defaultPolicy(positionsSeen, child, player); // uses the nodes' best descendant, generates an action.
            backProp(child, outcome);
            atomic numAsyncsSpawned--;
          } // end async
        } else {
          var child:MCTNode = treePolicy(positionsSeen);
          var outcome:Int = defaultPolicy(positionsSeen, child, player); //uses the nodes' best descendant, generates an action.
          backProp(child, outcome);
        }
      } // end while.
    } // end finish


    var bestChild:MCTNode = getBestChild(0);
    if(bestChild.computeUcb(0) < PASSFLOOR) {
      //Console.OUT.println("best move below the passfloor.");
      return new MCTNode(this, state, Boolean.TRUE);
    } else {
      if((parent != null) && parent.pass && (leafValue(this, player) > 0)) {
        //Console.OUT.println("computer's about to win.");
        return new MCTNode(this, state, Boolean.TRUE);
      } else {
        return bestChild;
      }
    }

  }


  public def treePolicy(var positionsSeen:HashSet[Int]):MCTNode{

    //Console.OUT.println("looping in tree policy.");
    var child:MCTNode = generateChild(positionsSeen);
    //Console.OUT.println("successfully generated a child.");

    if(child == null) { // indicates a leaf OR all kids generated; couldn't generate a child.
      if(children.isEmpty()){
        //Console.OUT.println("no children.");
        return this; // this is the best already-expanded child.  cherish it.
      } else {
        // recursive descent through the tree, best choice at each step:
        //Console.OUT.println("about to recurse.");
        return getBestChild(TREEPOLICYCONSTANT).treePolicy(positionsSeen);
      }
    } else {
      children.add(child); // add to list.
      //Console.OUT.println("made a new child, returning.");

      return child;
    }
  }

  public def generateChild(var positionsSeen:HashSet[Int]):MCTNode {
    //Console.OUT.println("inside generate child.");
    var stone:Stone = stoneFromTurn();

    //generate the passing child
    if(actionToTry == state.getSize()) {
      //Console.OUT.println("generating the passing move.");
      atomic actionToTry++;
      return new MCTNode(this, state, Boolean.TRUE);
    }

    while(actionToTry < state.getSize()) {
      //Console.OUT.println("looping inside genchild");
      var possibleState:BoardState = state.doMove(actionToTry, stone);

      // if valid move AND not seen before
      if(possibleState != null && !positionsSeen.contains(possibleState.hashCode())) {
        var newNode:MCTNode = new MCTNode(this, possibleState);
        atomic actionToTry++;
        return newNode;
      }

      atomic actionToTry++;
    }
    
    // no more actions are possible.
    return null;
  }

  public def defaultPolicy(var positionsSeen:HashSet[Int], var currNode:MCTNode, val player:Boolean):Int {
    //Console.OUT.println("playing a default policy.");
    var randomGameMoves:HashSet[Int] = positionsSeen.clone();

    var tempNode:MCTNode = currNode;
    while(tempNode != null && !tempNode.isLeaf()){
      //Console.OUT.println("looping in default policy.");
      tempNode = currNode.generateRandomChildState(randomGameMoves);
      if(tempNode != null) {
        //Console.OUT.println("updating currnode in default policy.");
        currNode = tempNode;
        randomGameMoves.add(currNode.state.hashCode());
      }
    }
    //Console.OUT.println("about to return the leaf value.");
    return leafValue(currNode, player);
  }

  public def leafValue(var currNode:MCTNode, val player:Boolean):Int {
    // 'this' is the root of the current game subtree, so we know whose turn it is.
    if(!player) { // player is white
      if(currNode.state.currentLeader() == Stone.WHITE) {
        return 1;
      } else if(currNode.state.currentLeader() == Stone.BLACK) {
        return -1;
      } else {
        return 0;
      }
    } else { // player is black
      if(currNode.state.currentLeader() == Stone.WHITE) {
        return -1;
      } else if(currNode.state.currentLeader() == Stone.BLACK) {
        return 1;
      } else {
        return 0;
      }
    }
  }

  public def generateRandomChildState(var randomGameMoves:HashSet[Int]):MCTNode {
    
    var stone:Stone = stoneFromTurn();

    // TODO: HERE'S THE PROBLEM: WE'RE SPINNING AT THIS POINT.
    // 1: get an arraylist of the empty squares, generate one of THOSE randomly, remove it if it's an invalid move, and 
    var emptyIdxs:ArrayList[Int] = state.listOfEmptyIdxs();
    var randIdx:Int = rand.nextInt(emptyIdxs.size());
    var childState:BoardState = state.doMove(emptyIdxs.get(randIdx), stone);
    emptyIdxs.removeAt(randIdx);

    while(!emptyIdxs.isEmpty()) {
      //Console.OUT.println("working through generate random child state.");
      if((childState != null) && !randomGameMoves.contains(childState.hashCode())) {
        //Console.OUT.println("about to return a new child node");
        return new MCTNode(this, childState);
      }
      else {
        //Console.OUT.println("about to generate a new random child");
        randIdx = rand.nextInt(emptyIdxs.size());
        childState = state.doMove(emptyIdxs.get(randIdx), stone);
        emptyIdxs.removeAt(randIdx);
      }
    }
    //Console.OUT.println("finished with generate random child state.");
    return null;
  }

  // TODO: update this so it doesn't go all the way to the root.  a minor optimization.
  public def backProp(var currNode:MCTNode, val reward:Int):void {
    //Console.OUT.println("inside backprop.");
    while(currNode != null) {
      //Console.OUT.println("backprop while loop.");
      atomic currNode.timesVisited++;
      atomic currNode.aggReward += reward;
      currNode = currNode.parent;
    }
  }

  public def isLeaf():Boolean {
    // something is a leaf when it either has no valid moves, or both the preceding boards were 'passes'.
    
    return isLeafOnPasses() || !validMoveLeft();
  }

  public def isLeafOnPasses():Boolean {
    val res:Boolean = (parent != null && parent.parent != null && parent.pass && parent.parent.pass);
    return res;
  }

  public def validMoveLeft():Boolean {
    var stone:Stone = stoneFromTurn();
    for(var i:Int = 0; i < state.getSize(); i++) {
      if(state.doMove(i, stone) != null) {
        return Boolean.TRUE;
      }
    }
    return Boolean.FALSE;
  }

  public def stoneFromTurn():Stone{
    if(turn) {
      return Stone.BLACK;
    } else {
      return Stone.WHITE;
    }
  }

  // public def findOpponentMoveInChildren(val b:BoardState):MCTNode {
  //   for(var i:Int = 0; i < children.size(); i++) {
  //     if(state.equals(children(i))) {
  //       return children(i);
  //     }
  //   }
  //   Console.OUT.println("returning null.");
  //   return null;
  // }

  // done when two consecutive turns are passes.
  public def gameIsOver():Boolean {
    if(parent != null) {
      //Console.OUT.println("pass: " + pass + ", and parent.pass: " + parent.pass);
      return pass && parent.pass;
    } else {
      //Console.OUT.println("parent is null.");
      return false;
    }
  }



  // getters / setters

  public def getBoardState():BoardState {
    return state;
  }

  public def getChildren():ArrayList[MCTNode] {
    return children;
  }

  public def setPass(val b:Boolean):void {
    pass = b;
  }

}
