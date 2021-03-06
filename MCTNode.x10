// A single node in the Go game tree.

import x10.io.InputStreamReader;
import x10.util.StringBuilder;
import x10.util.ArrayList;
import x10.util.Random;
import x10.util.Timer;
import x10.lang.Boolean;
import x10.util.HashSet;
import x10.util.concurrent.AtomicDouble;
import x10.util.concurrent.AtomicInteger;
import x10.util.concurrent.AtomicLong;
import x10.util.concurrent.AtomicBoolean;

public class MCTNode {

  static public val rand:Random = new Random(System.nanoTime());

  // used to compute UCB during tree policy.
  static public val EXPLORE_PARAM:Double = .707; 

  // fields
  private var parent:MCTNode;
  private val turn:Stone;
  private var children:ArrayList[MCTNode];
  private var timesVisited:AtomicInteger;
  private var aggReward:AtomicDouble;
  private var state:BoardState;
  private var pass:Boolean;
  private var realMove:MCTNode;
  private var unexploredMoves:ArrayList[Int];
  private var expanded:Boolean;

  // DEBUG STUFF
  private static val DEBUG_MODE = 
    Int.parseInt(System.getenv().getOrElse("GOBOT_DEBUG", "0"));
  private static val UCT_DETAIL = 1<<0;
  private static val TP_DETAIL = 1<<1;
  private static val DP_DETAIL = 1<<2;
  private static val BP_DETAIL = 1<<3;
  private static val TP_ITR_DETAIL = 1<<4;
  private static val DP_ITR_DETAIL = 1<<5;
  private static val GBC_DETAIL = 1<<6;
  private static val BOARD_DETAIL = 1<<10;
  private static val skipWait = new AtomicBoolean(false);

  // Parallelism controls
  private val numAsyncsSpawned:AtomicInteger = new AtomicInteger(0);
  private static val x10Nthreads = 
    Int.parseInt(System.getenv().getOrElse("X10_NTHREADS", "1"));

  private static val MAX_ASYNCS:Int = (x10Nthreads * 1.1) as Int;
  private static val MAX_PLACES:Int = 1;
  private static val BATCH_SIZE:Int =     
    Int.parseInt(System.getenv().getOrElse("GOBOT_BATCH_SIZE", "1"));
  private static val NODES_PER_PLACE:Int = BATCH_SIZE / MAX_PLACES;
  private static val MAX_DP_PATHS:Int = MAX_ASYNCS / NODES_PER_PLACE;

  // Metric values
  private static val nodesProcessed:AtomicInteger = new AtomicInteger(0);
  private static val timeElapsed:AtomicLong = new AtomicLong(0);

  // in ms.
  private static val GOBOT_THINK_TIME:Int = 
    Int.parseInt(System.getenv().getOrElse("GOBOT_THINK_TIME", "3000"));
  private static val NANOS_PER_MILLI:Long = 1000000L;

  public static val totalNodesProcessed:AtomicInteger = new AtomicInteger(0);
  public static val totalTimeElapsed:AtomicLong = new AtomicLong(0);
  public static val dpTimeElapsed:AtomicLong = new AtomicLong(0);
  public static val bpTimeElapsed:AtomicLong = new AtomicLong(0);
  public static val tpTimeElapsed:AtomicLong = new AtomicLong(0);

  // constructors

  // the parent is in charge of generating board state, to make sure we
  // don't repeat ourselves.
  public def this(state:BoardState) {
    this(null, state, false);
  }

  public def this(parent:MCTNode, state:BoardState) {
    this(parent, state, false);
  }

  public def this(parent:MCTNode, state:BoardState, pass:Boolean) {
    this.parent = parent;
    this.state = state;
    this.turn = parent == null ? Stone.BLACK : Stone.getOpponentOf(parent.turn);
    this.pass = pass;
    this.timesVisited = null;
    this.aggReward = null;
    this.children = null;
    this.unexploredMoves = null;
    this.expanded = false;
   }

  public def this(toCopy:MCTNode) {
    this.parent = toCopy.parent;
    this.state = toCopy.state;
    this.turn = toCopy.turn;
    this.pass = toCopy.pass;

    if (toCopy.timesVisited != null)
      this.timesVisited = new AtomicInteger(toCopy.timesVisited.get());
    else
      this.timesVisited = null;

    if (toCopy.aggReward != null)
      this.aggReward = new AtomicDouble(toCopy.aggReward.get());
    else
      this.aggReward = null;

    if (toCopy.children != null)
      this.children = toCopy.children.clone();
    else
      this.children = null;
    if (toCopy.unexploredMoves != null)
      this.unexploredMoves = toCopy.unexploredMoves.clone();
    else
      this.unexploredMoves = null;
  }

  // methods
  public def computeUcb(val c:Double):Double{
    // calculation involves the parent.  TODO: make sure we don't try to
    // calc this for the root node.

    if (parent == null || timesVisited == null || timesVisited.get() == 0) {
      return Double.POSITIVE_INFINITY;
    }


    var ucb:Double = (aggReward.get() / timesVisited.get()) + (2 * c * Math.sqrt((2 * Math.log((parent.timesVisited.get() as Double))) / timesVisited.get()));
    var weight:Double;

    if(pass) {
      // weight passing, so it's more attractive as the game progresses.
      // if the opponent passed and the computer is winning, it should pass and win
      if(parent.pass && (getMyScore() < getOppScore())) {
        weight = 1000; // computer should automatically win.
      } else {
        weight = (((state.getWhiteScore() as Double) + 
		   (state.getBlackScore() as Double)) / 
		  ((state.getHeight() as Double) * 
		   (state.getWidth() as Double)));
      }
      ucb = ucb * weight;
    }
    return ucb;
  }

  public def getBestChild(val c:Double):MCTNode {
    var bestVal:Double = Double.NEGATIVE_INFINITY;
    var bestValArg:MCTNode = null;
    for(var i:Int = 0; i < children.size(); i++) {
      val currChild:MCTNode = children(i);
      val currVal:Double = currChild.computeUcb(c);

      if(currVal > bestVal) {
        bestVal = currVal;
        bestValArg = currChild;
      }

    }

    return bestValArg;
  }



  public def withinResourceBound(val startTime:Long):Boolean {
    return (Timer.nanoTime() - startTime) < ((GOBOT_THINK_TIME as Long) * NANOS_PER_MILLI);
  }

  public def UCTSearch(val positionsSeen:HashSet[Int]):MCTNode {
    val MAX_DEFAULT_POLICIES:Int = Math.pow(state.getWidth() as Double, 3.0) as Int;
    val MAX_NODES_PROCESSED:Int = 10000;

    this.parent = null; // make sure backprop stops at this node.

    val numDefaultPolicies:AtomicInteger = new AtomicInteger(0);
    val defaultPolicyDepth:Int = state.getSize() * 2;

    val startTime:Long = Timer.nanoTime();
    numAsyncsSpawned.set(0);
    while(withinResourceBound(startTime)) {
      // Select BATCH_SIZE new MCTNodes to simulate using TP
      val dpNodes:ArrayList[MCTNode] = new ArrayList[MCTNode](BATCH_SIZE);

      // Tree Policy Start
      val treePolicyStartTime = Timer.nanoTime();
      for(childIdx in 0..(BATCH_SIZE - 1)) {
	val child:MCTNode = treePolicy(positionsSeen);
	if (child == this)
	  break;
	else
	  dpNodes.add(child);
      }
      tpTimeElapsed.addAndGet(Timer.nanoTime() - treePolicyStartTime);
      // Tree Policy End
      val dpNodeResults:Array[AtomicDouble] = (
	new Array[AtomicDouble](dpNodes.size(), 
				(x:Int)=>new AtomicDouble()));

      // Default Policy Start
      val dpStartTime = Timer.nanoTime();
      finish for (dpNodeIdx in 0..(dpNodes.size()-1)) {

	async {
	  val dpNode = dpNodes.get(dpNodeIdx);

	  // DP fields were lazy-evaluated. Time to set them for real.
	  if (dpNode.aggReward == null) {
	    dpNode.timesVisited = new AtomicInteger(0);
	    dpNode.aggReward = new AtomicDouble(0.0);
	  }

          val currBoardState:BoardState = dpNode.state;

          // TODO: the issue is the at.  it appears to be changing the values.
          // inlined default policy:
          finish {
            for (var i:Int = 0; i < MAX_DP_PATHS; i++) {
              async {
		var currParent:MCTNode = new MCTNode(dpNode);
		var currNode:MCTNode = new MCTNode(dpNode);
		var tempNode:MCTNode;
		var currDepth:Int = 0;
		val randomGameMoves:HashSet[Int] = positionsSeen.clone();
		randomGameMoves.add(currNode.state.hashCode());

		while(currNode != null && !currNode.isLeaf() &&
                      currDepth < defaultPolicyDepth) {
                  nodesProcessed.incrementAndGet();
                  tempNode = currNode.dpGenerateChild(randomGameMoves);

                  if(tempNode != null) {
                    currParent = currNode; // old currNode value is this.
                    currNode = tempNode;
                    currNode.setParent(currParent);
                    randomGameMoves.add(currNode.state.hashCode());
                  }
                  currDepth++;
		}

		dpNodeResults(dpNodeIdx).getAndAdd(currNode.leafValue());
              }
            }
	  }
        }

        numDefaultPolicies.getAndAdd(1);
      }


      dpTimeElapsed.addAndGet(Timer.nanoTime() - dpStartTime);
      // Default Policy End

      // Back Propagate Start
      val bpStartTime = Timer.nanoTime();
      finish for (dpNodeIdx in 0..(dpNodes.size()-1)) {
	val dpNode = dpNodes(dpNodeIdx);
        if(numAsyncsSpawned.get() < MAX_ASYNCS) {
          numAsyncsSpawned.incrementAndGet();
          async {
            val outcome:Double = dpNodeResults(dpNodeIdx).get();
            backProp(dpNode, outcome);
            numAsyncsSpawned.decrementAndGet();
          } 
        } else {
          val outcome:Double = dpNodeResults(dpNodeIdx).get();
          backProp(dpNode, outcome);
        }
      }

      bpTimeElapsed.addAndGet(Timer.nanoTime() - bpStartTime);
      // Back Propagate End

    } // end 'while within resource bound'

    totalNodesProcessed.getAndAdd(nodesProcessed.get());
    totalTimeElapsed.getAndAdd(Timer.nanoTime() - startTime);
    val bestChild:MCTNode = getBestChild(0);

    skipWait.getAndSet(false);
    
    nodesProcessed.set(0);
    return bestChild;
  }
    

  public def treePolicy(positionsSeen:HashSet[Int]):MCTNode{

    // TP fields were lazy-evaluated. Time to set them for real.
    if (this.children == null) {
      this.children = new ArrayList[MCTNode]();
      this.unexploredMoves = this.state.listOfEmptyIdxs();
      
      if (this.aggReward == null) {
	this.timesVisited = new AtomicInteger(0);
	this.aggReward = new AtomicDouble(0.0);
      }
    }

    var child:MCTNode;
    child = tpGenerateChild(positionsSeen);

    // no children (leaf or all children)
    if(child == null) { 
      if(children.isEmpty()){
        return this;
      } else {
        // recursive descent through the tree, best choice at each step:
	val bc = getBestChild(EXPLORE_PARAM);

	// Remember to add this node to the new list of positions seen
	val newPositionsSeen:HashSet[Int] = positionsSeen.clone();
	newPositionsSeen.add(this.state.hashCode());

        return bc.treePolicy(newPositionsSeen);
      }
    } else {
      children.add(child);
      return child;
    }
  }


  public def dpGenerateChild(positionsSeen:HashSet[Int]):MCTNode {
    //generate the passing child
    val possibleMoves = this.state.listOfEmptyIdxs();

    // when you're opponent has passed and you're winning, you should pass
    // and win.
    if (this.pass && (this.state.currentLeader() == this.turn)) {
      return new MCTNode(this, state, true); 
    }
    while(!possibleMoves.isEmpty()) {
      var randIdx:Int;
      var possibleState:BoardState = null;

      if (possibleMoves.size() > 0) {
	randIdx = rand.nextInt(possibleMoves.size());

	pdebug("dpGenerateChild", DP_ITR_DETAIL,
	       "Move " + randIdx + " selected. Options were " + 
	       printPossible(possibleMoves));
	
	possibleState = state.doMove(possibleMoves(randIdx), turn);
	possibleMoves.removeAt(randIdx);

      }

      // if valid move (doMove catches invalid, save Ko) AND not seen
      // before (Ko)
      if(possibleState != null && !positionsSeen.contains(possibleState.hashCode())) {
        var newNode:MCTNode = new MCTNode(this, possibleState);
        return newNode;
      }
    }

    // no more actions are possible.
    return new MCTNode(this, state, true);
  }

  public def tpGenerateChild(positionsSeen:HashSet[Int]):MCTNode {
    //generate the passing child
    if(unexploredMoves.isEmpty() && !expanded) {
      expanded = true;
      return new MCTNode(this, state, true);
    }

    while(!unexploredMoves.isEmpty()) {
      var randIdx:Int;
      var possibleState:BoardState = null;

      if (unexploredMoves.size() > 0) {
	randIdx = rand.nextInt(unexploredMoves.size());
	possibleState = state.doMove(unexploredMoves(randIdx), turn);
	unexploredMoves.removeAt(randIdx);
      }

      // if valid move (doMove catches invalid, save Ko) AND not seen
      // before (Ko)
      if(possibleState != null && !positionsSeen.contains(possibleState.hashCode())) {
        var newNode:MCTNode = new MCTNode(this, possibleState);
        return newNode;
      }
    }

    return null;
  }


  public def leafValue():Double {
    // TODO: fix these so AI can be white
    if (state.currentLeader() == Stone.BLACK)
      return 1.0;
    else if (state.currentLeader() == Stone.WHITE)
      return 0.0;
    else
      return 0.5;
  }

  public def backProp(var currNode:MCTNode, val reward:Double):void {
    while(currNode != null) {

      currNode.timesVisited.addAndGet(MAX_DP_PATHS); // b/c we do
                                                     // MAX_DP_PATHS parallel default policies

      // TODO: fix this magic Stone.BLACK, like at leafValue()
      if (currNode.turn == Stone.WHITE)
        currNode.aggReward.addAndGet(reward);
      else
        currNode.aggReward.addAndGet(-1 * reward);

      currNode = currNode.parent;
    }
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
    if (children != null) {
      for(var i:Int = 0; i < children.size(); i++) {
	if(children(i).getBoardState().equals(stateToFind)) {
          return children(i);
	} 
      }
    }
    return null;
  }

  public def isLeaf():Boolean {
    // leaf: no valid moves or two preceding moves were passes    
    return isLeafOnPasses();// || !validMoveLeft();
  }

  public def isLeafOnPasses():Boolean {
    return (parent != null &&
            parent.pass &&
            this.pass);
  }                                       

  public def validMoveLeft():Boolean {
    for(var i:Int = 0; i < state.getSize(); i++) {
      if(state.doMove(i, turn) != null) {
        return true;
      }
    }
    return false;
  }

  public def gameIsOver():Boolean {
    if(parent != null) {
      return pass && parent.pass;
    } else {
      return false;
    }
  }

  public def getMyScore():Int {
    return (turn == Stone.BLACK ? state.getBlackScore() : state.getWhiteScore());
  }

  public def getOppScore():Int {
    return (turn == Stone.BLACK ? state.getWhiteScore() : state.getBlackScore());
  }

  public def getBoardState():BoardState {
    return state;
  }

  public def getUnexploredMoves():ArrayList[Int] {
    return this.unexploredMoves;
  }

  public def getChildren():ArrayList[MCTNode] {
    return children;
  }

  public def getParent():MCTNode {
    return parent;
  }

  public def setParent(mctn:MCTNode):void {
    this.parent = mctn;
  }

  public def getPass():Boolean {
    return pass;
  }

  public def setPass(val b:Boolean):void {
    pass = b;
  }

  // Debug Methods
  private def pdebug(val prefix:String, val flag:Int, val msg:String):Boolean {
    if (((DEBUG_MODE & flag) == flag) || flag == 0) {
      Console.OUT.println();
      Console.OUT.println("["+prefix+"] - "+ msg);
      return true;
    }
    return false;
  }

  private def pdebugWait(val prefix:String, val flag:Int, val msg:String) {
    if (pdebug(prefix, flag, msg) && !skipWait.get()) {
      Console.OUT.println("\nHit [Enter] to continue");
      val skip = Console.IN.readLine();
      if (skip.equals("finish"))
	skipWait.getAndSet(true);
      Console.OUT.println("\nProceeding");
    }
  }

  private def printSearchTree():String {

    val sb = new StringBuilder();    
    depthFirstTraverse(this, 0, sb);
    return ("\tSearch Tree: \n" + 
	    "\t---------------------------------------------------------\n" +
	    sb.result());
  }

  private def depthFirstTraverse(val start:MCTNode, val indent:Int,
				 val sb:StringBuilder):void {
    for (i in 0..indent) {
      sb.add("\t");
    }
    sb.add(printNode(start));
    if (start.children != null) {
      for (child in start.children) {
	sb.add("\n");
	depthFirstTraverse(child, indent + 1, sb);
      }
    }
  }

  private def printTPResults(val nodes:ArrayList[MCTNode]):String {
    val sb = new StringBuilder();
    sb.add("\t[");
    
    for (node in nodes) {
      sb.add(printNode(node));
      sb.add(" (parent: " + printNode(node.parent) + "),\n\t");
    }

    sb.add("]");
    return sb.result();
  }

  private def printDPResults(val nodes:ArrayList[MCTNode],
			    val results:Array[AtomicDouble]):String {
    val sb = new StringBuilder();
    sb.add("Nodes \n\t[");
    
    for (node in nodes) {
      sb.add(printNode(node) + ",\n\t");      
    }

    sb.add("]\n");
    sb.add("Scores \n\t[");
    
    for (result in results.values()) {
      sb.add(result + ",\n\t");
    }

    sb.add("]\n");
    return sb.result();
  }

  private def printPossible(val idxs:ArrayList[Int]):String{
    val sb = new StringBuilder();
    sb.add("\n\t[");
    
    for (idx in idxs) {
      sb.add(idx + ",\n\t");      
    }

    sb.add("]\n");
    return sb.result();
  }

  private def printNode(val node:MCTNode):String{
    return ("<" + node.hashCode() + 
	    " Reward=" + node.aggReward.get() + 
	    " Visited=" + node.timesVisited.get() + 
	    " UCB_ex=" + node.computeUcb(EXPLORE_PARAM) + 
	    " UCB_de=" + node.computeUcb(0) + ">");
  }
}
