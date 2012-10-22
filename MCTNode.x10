// A single node in the Go game tree.

// TODO: pass never gets set to "true" under the current circumstances

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
  private val parent:MCTNode;
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
    this.children = new ArrayList[MCTNode](CHILDINITSIZE);
    this.actionToTry = 0; // refers to the next index to be tried as a child action.
  }

  public def this(var state:BoardState, var pass:Boolean) {
    this.parent = null;
    this.timesVisited = 0; //only gets incremented during backprop.
    this.aggReward = 0.0; // gets set during backprop.
    this.state = state;
    this.turn = parent == null ? Boolean.TRUE : parent.turn ^ Boolean.TRUE; // XOR T flips the bit.  TODO: optimize the inital setting so we don't have to check for null parent on every node generated.
    this.pass = pass;
     this.children = new ArrayList[MCTNode](CHILDINITSIZE);
    this.actionToTry = 0; // refers to the next index to be tried as a child action.
   }

  public def this(var state:BoardState) {
    //Console.OUT.println("inside the state MCTNode constructor."); 
    this.parent = null;
    this.timesVisited = 0; // only gets incremented during backprop.
    this.aggReward = 0.0; // gets set during backprop.
    this.state = state;
    this.turn = parent == null ? Boolean.TRUE : parent.turn ^ Boolean.TRUE; // XOR T flips the bit.  TODO: optimize the inital setting so we don't have to check for null parent on every node generated.
    this.pass = false;
    this.children = new ArrayList[MCTNode](CHILDINITSIZE);
    this.actionToTry = 0; // refers to the next index to be tried as a child action.
    //Console.OUT.println("exiting the state MCTNode constructor.");
  }


  // methods
  public def computeUcb(val c:Double):Double{
    // calculation involves the parent.  TODO: make sure we don't try to
    // calc this for the root node.
    //Console.OUT.println("inside computeUcb.  this.aggReward: " + this.aggReward + ", this.timesVisited: " + this.timesVisited);
    return (this.aggReward / this.timesVisited) + (2 * c * Math.sqrt((2 * Math.log((this.parent.timesVisited as Double))) / this.timesVisited));
  }


  public def getBestChild(val c:Double):MCTNode {
    //Console.OUT.println("inside getBestChild(), the number of children is: " + this.children.size());
    //Console.OUT.println("the constant is: " + c);
    var bestVal:Double = -99;
    var bestValArg:MCTNode = null;
    for(var i:Int = 0; i < this.children.size(); i++) {
      //Console.OUT.println("current child:\n" + children(i).state.print());
      //Console.OUT.println("loop of the getBestChild");
      var currVal:Double = children(i).computeUcb(c);
      //Console.OUT.println("currVal: " + currVal + ", bestVal: " + bestVal);
      //Console.OUT.println("timesVisited: " + children(i).timesVisited + ", aggReward: " + children(i).aggReward);
      if(currVal > bestVal) {
        //Console.OUT.println("found a better child with value: " + currVal);
        //Console.OUT.println(children(i).state.print());
        bestVal = currVal;
        bestValArg = children(i);
      }
    }
    return bestValArg;
  }

  public def withinResourceBound(startTime:Long):Boolean{
    val diff:Long = Timer.milliTime() - startTime;
    //Console.OUT.println("The time diff is " + diff);
    return TIMEBOUND > diff;
  }

  // generate the action to take, a unique MCTNode whose board state has not been seen before.
  public def UCTSearch(var positionsSeen:HashSet[BoardState], val player:Boolean):MCTNode{
    //Console.OUT.println("inside UCTSearch");
    val startTime:Long = Timer.milliTime();
    while(withinResourceBound(startTime)) { // TODO: implement the resource bound.
      //Console.OUT.println("about to do a tree policy.");
      var child:MCTNode = treePolicy(positionsSeen);
      if(child == null) {
        return null; // tree policy was dealing with a leaf. 
      }
      //Console.OUT.println("about to do a default policy.");
      var outcome:Int = defaultPolicy(positionsSeen, child, player); // uses the nodes' best descendant, generates an action.
      // no need to return anything, because
      //Console.OUT.println("about to do a backprop.");
      //Console.OUT.println("outcome determined: " + outcome);
      backProp(child, outcome);
    }

    //Console.OUT.println("about to get a bestChild.");
    var bestChild:MCTNode = getBestChild(0);
    if(bestChild.computeUcb(0) < PASSFLOOR) {
      //Console.OUT.println("we're going to pass.");
      this.pass = Boolean.TRUE;
      return this; // TODO: deal with this.
    } else {
      //Console.OUT.println("not a passing turn.  HERE ARE THE LIBERTIES");
      //bestChild.state.printAllLiberties();
      return bestChild;
    }
  }

  // TODO: change the name of this function.
  // find the most urgent expandable child, expand its children, pick one to simulate.
  public def treePolicy(var positionsSeen:HashSet[BoardState]):MCTNode{
    //Console.OUT.println("about to try and generate a child.");
    var child:MCTNode = generateChild(positionsSeen);
    if(child == null) {
      //Console.OUT.println("child generated was null.");
      if(this.children.isEmpty()){
        // dealing with a leaf
        return null; // TODO: force-pass, figure out how to code this.
      } else {
        //Console.OUT.println("all kids were already generated.");
        return getBestChild(TREEPOLICYCONSTANT); // all kids generated; just return best one.
      }
    } else {
      //Console.OUT.println("successfully generated a new kid.");
      this.children.add(child); // add to list.
      //Console.OUT.println("GENERATED A CHILD, HERE ARE ITS LIBERTIES:");
      //child.state.printAllLiberties();

      return child;
    }
  }

  public def generateChild(var positionsSeen:HashSet[BoardState]):MCTNode {
    //Console.OUT.println("inside generateChild");
    var stone:Stone = stoneFromTurn();
    while(this.actionToTry < this.state.getSize()) {
      //Console.OUT.println("ABOUT TO GENERATE AN ACTION.");
      var possibleState:BoardState = this.state.doMove(this.actionToTry, stone);
      // if valid move AND not seen before
      // TODO: generate output based on whether a move has been seen before or not, for our human users.
      if(possibleState != null && !positionsSeen.contains(possibleState)) {
        this.actionToTry++; // TODO: this is bad.
        return new MCTNode(this, possibleState);
      }
      this.actionToTry++;
    }
    
    //Console.OUT.println("unable to generate a valid, unseen action.");
    // no more actions are possible.
    return null;
  }

  public def defaultPolicy(var positionsSeen:HashSet[BoardState], var currNode:MCTNode, val player:Boolean):Int {
    
    var randomGameMoves:HashSet[BoardState] = positionsSeen.clone();

    //Console.OUT.println("inside the default policy function.");
    var tempNode:MCTNode = currNode;
    while(tempNode != null && !tempNode.isLeaf()){
      tempNode = currNode.generateRandomChildState(randomGameMoves);
      if(tempNode != null) {
        currNode = tempNode;
        randomGameMoves.add(currNode.state);
      }
    }
    //Console.OUT.println(currNode.state.print());
    //Console.OUT.println("about to return the leaf value.");
    return leafValue(currNode, player);
  }

  public def leafValue(var currNode:MCTNode, val player:Boolean):Int {
    // 'this' is the root of the current game subtree, so we know whose turn it is.
    if(!player) { // player is white
      if(currNode.state.currentLeader() == Stone.WHITE) {
        //Console.OUT.println("player is white, winner is white.");
        return 1;
      } else if(currNode.state.currentLeader() == Stone.BLACK) {
        //Console.OUT.println("player is white, winner is black.");
        return -1;
      } else {
        //Console.OUT.println("draw from white perspective, jerkwads.");
        return 0;
      }
    } else { // player is black
      if(currNode.state.currentLeader() == Stone.WHITE) {
        //Console.OUT.println("player is black, winner is white.");
        return -1;
      } else if(currNode.state.currentLeader() == Stone.BLACK) {
        //Console.OUT.println("player is black, winner is black.");
        return 1;
      } else {
        //Console.OUT.println("draw from black perspective, jerkwads.");
        return 0;
      }
    }
  }

  public def generateRandomChildState(var randomGameMoves:HashSet[BoardState]):MCTNode {

    var stone:Stone = stoneFromTurn();

    // TODO: HERE'S THE PROBLEM: WE'RE SPINNING AT THIS POINT.
    // 1: get an arraylist of the empty squares, generate one of THOSE randomly, remove it if it's an invalid move, and 
    var emptyIdxs:ArrayList[Int] = this.state.listOfEmptyIdxs();
    var randIdx:Int = rand.nextInt(emptyIdxs.size());
    var childState:BoardState = this.state.doMove(emptyIdxs.get(randIdx), stone);
    emptyIdxs.removeAt(randIdx);

    while(!emptyIdxs.isEmpty()) {
      if((childState != null) && !randomGameMoves.contains(childState)) {
        //Console.OUT.println("VALID MOVE ACHIEVED.");
        return new MCTNode(this, childState);        
      }
      else {
        //Console.OUT.println("size of list: " + emptyIdxs.size());
        //Console.OUT.println("HERE WE ARE.");
        randIdx = rand.nextInt(emptyIdxs.size());
        childState = this.state.doMove(emptyIdxs.get(randIdx), stone);
        emptyIdxs.removeAt(randIdx);
      }
    }

    //Console.OUT.println("RETURNING NULL ***************************************************************");
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
    //Console.OUT.println("we're here in isLeaf()");
    
    return isLeafOnPasses() || !validMoveLeft();
  }

  public def isLeafOnPasses():Boolean {
    val res:Boolean = (this.parent != null && this.parent.parent != null && this.parent.pass && this.parent.parent.pass);
    //Console.OUT.println("inside isLeafOnPasses: " + res);
    return res;
  }

  public def validMoveLeft():Boolean {
    var stone:Stone = stoneFromTurn();
    for(var i:Int = 0; i < this.state.getSize(); i++) {
      if(this.state.doMove(i, stone) != null) {
        //Console.OUT.println("inside validMoveLeft(): " + Boolean.TRUE);
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

  public def isGameOver():Boolean {
    return isLeaf();
  }

  public def getBoardState():BoardState {
    return this.state;
  }

}
