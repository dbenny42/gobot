// A single node in the Go game tree.

import x10.util.ArrayList;
import x10.util.Random;
import x10.util.Timer;
import x10.lang.Boolean;
import x10.util.HashSet;
import x10.util.concurrent.AtomicDouble;
import x10.util.concurrent.AtomicInteger;
import x10.util.concurrent.Lock;

public class MCTNode {

  static public val rand:Random = new Random(System.nanoTime());

  // used to compute UCB during tree policy.
  static public val EXPLORE_PARAM:Double = .707; 


  // fields
  private var parent:MCTNode;
  private val turn:Stone;
  private val children:ArrayList[MCTNode];
  private val childrenLock:Lock;
  private val timesVisited:AtomicInteger;
  private val aggReward:AtomicDouble;
  private var state:BoardState;
  private var pass:Boolean;
  private var realMove:MCTNode;
  private val unexploredMoves:ArrayList[Int];
  private val unexploredMovesLock:Lock;
  private var expanded:Boolean;



  private val numAsyncsSpawned:AtomicInteger = new AtomicInteger(0);
  private val x10_nthreads = 
    Int.parseInt(System.getenv().getOrElse("X10_NTHREADS", "1"));

  private static var MAX_ASYNCS:Int = (x10_nthreads * 1.1) as Int;
  private static var MAX_PLACES:Int = Place.MAX_PLACES;
  private static var BATCH_SIZE:Int = MAX_PLACES;
  private static var NODES_PER_PLACE:Int = BATCH_SIZE / MAX_PLACES;
  private static var MAX_DP_PATHS:Int = MAX_ASYNCS / NODES_PER_PLACE;


  public static def setMaxAsyncs(maxAsyncs:Int) {
    if (maxAsyncs <= 0)
      throw new RuntimeException("MAX_ASYNCS must be a positive integer");
    
    if ((maxAsyncs / (MCTNode.BATCH_SIZE / MCTNode.MAX_PLACES) <= 0))
      throw new RuntimeException("MAX_ASYNCS times MAX_PLACES cannot be less " +
				 "than BATCH_SIZE. MAX_PLACES is set to " +
				 MCTNode.MAX_PLACES + " " +
				 "and BATCH_SIZE is set to " + 
				 MCTNode.BATCH_SIZE);

    MCTNode.MAX_ASYNCS = maxAsyncs;
    MCTNode.MAX_DP_PATHS = MCTNode.MAX_ASYNCS / MCTNode.NODES_PER_PLACE;
  }

  public static def setMaxPlaces(maxPlaces:Int) {
    if (maxPlaces <= 0)
      throw new RuntimeException("MAX_PLACES must be a positive integer");
    
    if ((batchSize / MCTNode.MAX_PLACES) <= 0)
      throw new RuntimeException("MAX_PLACES cannot be larger than " +
				 "BATCH_SIZE. BATCH_SIZE is set to " +
				 MCTNode.BATCH_SIZE);

    if ((MCTNode.MAX_ASYNCS / (batchSize / MCTNode.MAX_PLACES) <= 0))
      throw new RuntimeException("MAX_PLACES times MAX_ASYNCS cannot be less " +
				 "than BATCH_SIZE. MAX_ASYNCS is set to " +
				 MCTNode.MAX_ASYNCS + " " +
				 "and BATCH_SIZE is set to " + 
				 MCTNode.BATCH_SIZE);

    MCTNode.MAX_PLACES:Int = maxPlaces;
    MCTNode.NODES_PER_PLACE = MCTNode.BATCH_SIZE / MCTNode.MAX_PLACES;
    MCTNode.MAX_DP_PATHS = MCTNode.MAX_ASYNCS / MCTNode.NODES_PER_PLACE;
  }

  public static def setBatchSize(batchSize:Int) {
    if ((batchSize / MCTNode.MAX_PLACES) <= 0)
      throw new RuntimeException("BATCH_SIZE must be at least as large as " +
				 "MAX_PLACES. MAX_PLACES is set to " +
				 MCTNode.MAX_PLACES);

    if ((MCTNode.MAX_ASYNCS / (batchSize / MCTNode.MAX_PLACES) <= 0))
      throw new RuntimeException("BATCH_SIZE cannot be larger than " +
				 "MAX_PLACES times MAX_ASYNCS. " +
				 "MAX_PLACES is set to " +
				 MCTNode.MAX_PLACES + " " +
				 "and MAX_ASYNCS is set to " + 
				 MCTNode.MAX_ASYNCS);

    MCTNode.BATCH_SIZE = batchSize;
    MCTNode.NODES_PER_PLACE = MCTNode.BATCH_SIZE / MCTNode.MAX_PLACES;
    MCTNode.MAX_DP_PATHS = MCTNode.MAX_ASYNCS / MCTNode.NODES_PER_PLACE;
  }
	 

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
    this.timesVisited = new AtomicInteger(0); // only gets incremented during backprop.
    this.aggReward = new AtomicDouble(0.0); // gets set during backprop.
    this.state = state;
    this.turn = parent == null ? Stone.BLACK : Stone.getOpponentOf(parent.turn);
    this.pass = pass;
    this.children = new ArrayList[MCTNode]();
    this.childrenLock = new Lock();
    this.unexploredMoves = state.listOfEmptyIdxs();
    this.unexploredMovesLock = new Lock();
    this.expanded = false;
   }

  // methods
  public def computeUcb(val c:Double):Double{
    // calculation involves the parent.  TODO: make sure we don't try to
    // calc this for the root node.

    if (timesVisited.get() == 0) {
      return Double.POSITIVE_INFINITY;
    }

    var ucb:Double = (aggReward.get() / timesVisited.get()) + (2 * c * Math.sqrt((2 * Math.log((parent.timesVisited.get() as Double))) / timesVisited.get()));
    var weight:Double;

    if(pass) {
      // weight passing, so it's more attractive as the game progresses.
      // if the opponent passed and the computer is winning, it should pass and win
      if(parent != null && parent.pass && (getMyScore() < getOppScore())) {
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

  public def withinResourceBound(numDefaultPolicies:AtomicInteger,
				 bound:Int):Boolean{
    return numDefaultPolicies.get() < bound;
  }

  public def UCTSearch(val positionsSeen:HashSet[Int]):MCTNode{

    //val koTable:GlobalRef[HashSet[Int]] = new GlobalRef(positionsSeen);
    val MAX_DEFAULT_POLICIES:Int = Math.pow(state.getWidth() as Double, 3.0) as Int;

    val numDefaultPolicies:AtomicInteger = new AtomicInteger(0);
    val defaultPolicyDepth:Int = (state.getSize() / 
				  this.unexploredMoves.size()) * 30;


    val startTime:Long = Timer.milliTime();
    numAsyncsSpawned.set(0);

    /*
    val dp_result_region:Region = Region.make(0, MAX_DEFAULT_POLICIES);
    val dp_results:DistArray[MCTNode] = 
      DistArray.make[MCTNode](Dist.makeBlock(dp_result_region, 0));
    val dp_nodes:ArrayList[MCTNode] = new ArrayList[MCTNode](MAX_DEFAULT_POLICIES);
    for(childIdx in dp_result_region) {
      var child:MCTNode = treePolicy(positionsSeen);
      if (child == this)
	break;
      else
	dp_nodes.add(child);
    }

    finish {
      for(dp_node_idx in 0..dp_nodes.size()) {
	val start:MCTNode = dp_nodes.get(dp_node_idx);
	at (dp_results.dist(dp_node_idx)) {
	  async {
	    val outcome:Double = defaultPolicy(positionsSeen, 
					       start, defaultPolicyDepth);
	    at (Place.FIRST_PLACE) {
	      backProp(start, outcome);
	    }
	    dp_results(dp_node_idx) = start;
	  }
	}
      }
    }*/

    /*finish {
      while(withinResourceBound(numDefaultPolicies, MAX_DEFAULT_POLICIES)) { 

        // Console.OUT.println("the number of default policies is: " + 
	// 		    numDefaultPolicies);

        if(numAsyncsSpawned.get() < MAX_ASYNCS) {
          numAsyncsSpawned.incrementAndGet();
          async {
            var child:MCTNode = treePolicy(positionsSeen);
	    Console.OUT.println("treePolicy output - null = " + (child == null));

	    // uses the nodes' best descendant, generates an action.
            var outcome:Double = defaultPolicy(positionsSeen, child,
					       defaultPolicyDepth);
            numDefaultPolicies.incrementAndGet();
            backProp(child, outcome);
            numAsyncsSpawned.decrementAndGet();
          } 
        } else {

          var child:MCTNode = treePolicy(positionsSeen);
	  Console.OUT.println("treePolicy output - null = " + (child == null));
          var outcome:Double = defaultPolicy(positionsSeen, child,
					     defaultPolicyDepth); 
          numDefaultPolicies.incrementAndGet();
          backProp(child, outcome);
        }
      } 
    }*/

    while(withinResourceBound(numDefaultPolicies, MAX_DEFAULT_POLICIES)) { 

      Console.OUT.println("Starting TP/DP/BP cycle");

      // Select BATCH_SIZE new MCTNodes to simulate using TP
      Console.OUT.println("TP");
      val dpNodes:ArrayList[MCTNode] = new ArrayList[MCTNode](BATCH_SIZE);
      for(childIdx in 0..(BATCH_SIZE - 1)) {
	val child:MCTNode = treePolicy(positionsSeen);
	if (child == this)
	  break;
	else
	  dpNodes.add(child);
      }

      val dpNodeRegion:Region = Region.make(0, dpNodes.size()-1);
      val d:Dist = Dist.makeBlock(dpNodeRegion, 0);

      Console.OUT.println("DP/BP");

      finish for (dpNodeIdx in dpNodeRegion) {
	val dpNode = dpNodes.get(dpNodeIdx(0));
	//at (d(dpNodeIdx)) {
	  async {
	    val outcome:Double = defaultPolicy(positionsSeen, dpNode,
					       defaultPolicyDepth);
	    numDefaultPolicies.incrementAndGet();
	    backProp(dpNode, outcome);
	  }
	//}
      }
    }

    var bestChild:MCTNode = getBestChild(0);
    return bestChild;
  }


  public def treePolicy(positionsSeen:HashSet[Int]):MCTNode{
    var child:MCTNode;
    child = generateChild(positionsSeen);

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

        //.OUT.println("[treePolicy] returning recursive descent");
        if(bc == null) {
          //.OUT.println("bc is null.");
        }
        return bc.treePolicy(newPositionsSeen);
      }
    } else {
      children.add(child);
      return child;
    }
  }


  public def generateChildNoModify(positionsSeen:HashSet[Int]):MCTNode {
    //generate the passing child

    val possibleMoves = unexploredMoves.clone();
    while(!possibleMoves.isEmpty()) {
      var randIdx:Int;
      var possibleState:BoardState = null;

      if (unexploredMoves.size() > 0) {
	randIdx = rand.nextInt(possibleMoves.size());
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

  public def generateChild(positionsSeen:HashSet[Int]):MCTNode {
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

  public def defaultPolicy(val positionsSeen:HashSet[Int],
			   val startNode:MCTNode,
			   val maxDepth:Int):Double {

    //Console.OUT.println("playing a default policy.");
    val dp_value_total = new AtomicDouble(0.0);

    finish {
      for (var i:Int = 0; i < MAX_DP_PATHS; i++) {
	async {
	  var currNode:MCTNode = startNode;
	  var tempNode:MCTNode;
	  var currDepth:Int = 0;
	  val randomGameMoves:HashSet[Int] = positionsSeen.clone();
	  randomGameMoves.add(currNode.state.hashCode());
	  while(currNode != null && !currNode.isLeaf() && currDepth < maxDepth) {
	    // TODO: does this really need to be generateRandomChildState()?
	    tempNode = currNode.generateChildNoModify(randomGameMoves);
	    if(tempNode != null) {
              currNode = tempNode;
              randomGameMoves.add(currNode.state.hashCode());
	    }
	    currDepth++;
	  }
	  dp_value_total.getAndAdd(leafValue(currNode));
	}
      }
    }
    return dp_value_total.get();
  }


  public def leafValue(var currNode:MCTNode):Double {
    if (currNode.state.currentLeader() == turn)
      return 1.0;
    else if (currNode.state.currentLeader() == Stone.getOpponentOf(turn))
      return 0.0;
    else
      return 0.5;
  }

/*
  public def generateRandomChildState(var randomGameMoves:HashSet[Int]):MCTNode {
    var emptyIdxs:ArrayList[Int] = state.unexploredMoves();
    var randIdx:Int = rand.nextInt(emptyIdxs.size());
    var childState:BoardState = state.doMove(emptyIdxs.get(randIdx), turn);
    emptyIdxs.removeAt(randIdx);

    while(!emptyIdxs.isEmpty()) {
      //Console.OUT.println("working through generate random child state.");
      if((childState != null) && 
	 !randomGameMoves.contains(childState.hashCode())) {
        //Console.OUT.println("about to return a new child node");
        return new MCTNode(this, childState);
      }
      else {
        //Console.OUT.println("about to generate a new random child");
        randIdx = rand.nextInt(emptyIdxs.size());
        childState = state.doMove(emptyIdxs.get(randIdx), turn);
        emptyIdxs.removeAt(randIdx);
      }
    }
    //Console.OUT.println("finished with generate random child state.");
    return null;
  }*/

  // TODO: update this so it doesn't go all the way to the root.  a minor optimization.
  public def backProp(var currNode:MCTNode, val reward:Double):void {
    while(currNode != null) {
      currNode.timesVisited.addAndGet(MAX_DP_PATHS); // b/c we do
                                                     // MAX_DP_PATHS parallel default policies
      currNode.aggReward.addAndGet(reward);
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
    for(var i:Int = 0; i < children.size(); i++) {
      if(children(i).equals(stateToFind)) {
        return children(i);
      } 
    }
    return null;
  }

  // TODO: Make sure !validMoveLeft() is still OK
  public def isLeaf():Boolean {
    // leaf: no valid moves or two preceding moves were passes    
    return isLeafOnPasses() || !validMoveLeft();
  }

  public def isLeafOnPasses():Boolean {
    return (parent != null && 
	    parent.parent != null && 
	    parent.pass && 
	    parent.parent.pass);
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
      Console.OUT.println("[gameIsOver] pass: " + pass + "parent.pass: " + parent.pass);
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

  public def getChildren():ArrayList[MCTNode] {
    return children;
  }

  public def getParent():MCTNode {
    return parent;
  }

  public def getPass():Boolean {
    return pass;
  }

  public def setPass(val b:Boolean):void {
    pass = b;
  }
}
