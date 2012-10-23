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
  private var parent:MCTNode;
  private val turn:Boolean; // Boolean.TRUE is black, FALSE is white ("little white lies")
  private var children:ArrayList[MCTNode];
  private var timesVisited:Int;
  private var aggReward:Double;
  private var state:BoardState;
  private var pass:Boolean;
  private var actionToTry:Int;

  // constructors

  // the parent is in charge of generating board state, to make sure we
  // don't repeat ourselves.
  public def this(var parent:MCTNode, var state:BoardState) {
    this.parent = parent;
    this.timesVisited = 0; // only gets incremented during backprop.
    this.aggReward = 0.0; // gets set during backprop.
    this.state = state;
    this.turn = parent == null ? Boolean.FALSE : parent.turn ^ Boolean.TRUE; // XOR T flips the bit.  TODO: optimize the inital setting so we don't have to check for null parent on every node generated.
    //this.pass = Boolean.FALSE;
    this.actionToTry = 0;
    this.children = new ArrayList[MCTNode](CHILDINITSIZE);
    this.pass = Boolean.FALSE;
  }

  public def this(var state:BoardState, var pass:Boolean) {
    this.parent = null;
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


  public def addRealMoveAsChild(val realMove:MCTNode):void {
    // kills children, then makes this the only child of the above node, since this node actually happens.
    this.children.clear(); // TODO: optimize later by making the REAL gametree its own tree entirely.
    realMove.parent = this;
    this.children.add(realMove);
  }

  public def getParent():MCTNode {
    return this.parent;
  }

  // methods
  public def computeUcb(val c:Double):Double{
    // calculation involves the parent.  TODO: make sure we don't try to
    // calc this for the root node.
    return (this.aggReward / this.timesVisited) + (2 * c * Math.sqrt((2 * Math.log((this.parent.timesVisited as Double))) / this.timesVisited));
  }


  public def getBestChild(val c:Double):MCTNode {

    var bestVal:Double = -99;
    var bestValArg:MCTNode = null;
    for(var i:Int = 0; i < this.children.size(); i++) {
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
    val startTime:Long = Timer.milliTime();
    while(withinResourceBound(startTime)) { // TODO: implement the resource bound.
      var child:MCTNode = treePolicy(positionsSeen);
      if(child.pass) {
        return child; // return the passing node.
      }
      var outcome:Int = defaultPolicy(positionsSeen, child, player); // uses the nodes' best descendant, generates an action.
      backProp(child, outcome);
    }

    // done computing within the resource bound.

    var bestChild:MCTNode = getBestChild(0);
    if(bestChild.computeUcb(0) < PASSFLOOR) {
      return new MCTNode(this.state, Boolean.TRUE);
    } else {
      if((this.parent != null) && this.parent.pass && (leafValue(this, player) > 0)) {
        return new MCTNode(this.state, Boolean.TRUE);
      } else {
        return bestChild;
      }
    }
  }

  public def treePolicy(var positionsSeen:HashSet[Int]):MCTNode{
    var child:MCTNode = generateChild(positionsSeen);

    if(child == null) { // indicates a leaf OR all kids generated; couldn't generate a child.
      if(this.children.isEmpty()){
        return this; // this is the best already-expanded child.  cherish it.
      } else {
        // recursive descent through the tree, best choice at each step:
        return getBestChild(TREEPOLICYCONSTANT).treePolicy(positionsSeen);
      }
    } else {
      this.children.add(child); // add to list.

      return child;
    }
  }

  public def generateChild(var positionsSeen:HashSet[Int]):MCTNode {
    var stone:Stone = stoneFromTurn();
    while(actionToTry < this.state.getSize()) {
      var possibleState:BoardState = this.state.doMove(actionToTry, stone);
      // if valid move AND not seen before
      // TODO: generate output based on whether a move has been seen before or not, for our human users.
      if(possibleState != null && !positionsSeen.contains(possibleState.hashCode())) {
        this.actionToTry++;
        var newNode:MCTNode = new MCTNode(this, possibleState);
        return newNode;
      }
      this.actionToTry++;
    }
    
    // no more actions are possible.
    return null;
  }

  public def defaultPolicy(var positionsSeen:HashSet[Int], var currNode:MCTNode, val player:Boolean):Int {
    
    var randomGameMoves:HashSet[Int] = positionsSeen.clone();

    var tempNode:MCTNode = currNode;
    while(tempNode != null && !tempNode.isLeaf()){
      tempNode = currNode.generateRandomChildState(randomGameMoves);
      if(tempNode != null) {
        currNode = tempNode;
        randomGameMoves.add(currNode.state.hashCode());
      }
    }
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
    var emptyIdxs:ArrayList[Int] = this.state.listOfEmptyIdxs();
    var randIdx:Int = rand.nextInt(emptyIdxs.size());
    var childState:BoardState = this.state.doMove(emptyIdxs.get(randIdx), stone);
    emptyIdxs.removeAt(randIdx);

    while(!emptyIdxs.isEmpty()) {
      if((childState != null) && !randomGameMoves.contains(childState.hashCode())) {
        return new MCTNode(this, childState);        
      }
      else {
        randIdx = rand.nextInt(emptyIdxs.size());
        childState = this.state.doMove(emptyIdxs.get(randIdx), stone);
        emptyIdxs.removeAt(randIdx);
      }
    }

    return null;
  }

  public def backProp(var currNode:MCTNode, val reward:Int):void {
    while(currNode != null) {
      currNode.timesVisited++;
      currNode.aggReward += reward;
      currNode = currNode.parent;
    }
  }

  public def isLeaf():Boolean {
    // something is a leaf when it either has no valid moves, or both the preceding boards were 'passes'.
    
    return isLeafOnPasses() || !validMoveLeft();
  }

  public def isLeafOnPasses():Boolean {
    val res:Boolean = (this.parent != null && this.parent.parent != null && this.parent.pass && this.parent.parent.pass);
    return res;
  }

  public def validMoveLeft():Boolean {
    var stone:Stone = stoneFromTurn();
    for(var i:Int = 0; i < this.state.getSize(); i++) {
      if(this.state.doMove(i, stone) != null) {
        return Boolean.TRUE;
      }
    }
    return Boolean.FALSE;
  }

  public def stoneFromTurn():Stone{
    if(this.turn) {
      return Stone.BLACK;
    } else {
      return Stone.WHITE;
    }
  }

  public def findOpponentMoveInChildren(val b:BoardState):MCTNode {
    for(var i:Int = 0; i < children.size(); i++) {
      if(this.state.equals(children(i))) {
        return children(i);
      }
    }
    return null;
  }

  // done when two consecutive turns are passes.
  public def gameIsOver():Boolean {
    return this.pass && this.parent.pass;
  }

  public def getBoardState():BoardState {
    return this.state;
  }

}
