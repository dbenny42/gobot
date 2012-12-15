// A single node in the Go game tree.

import x10.util.ArrayList;
import x10.util.Random;
import x10.util.Timer;
import x10.lang.Boolean;
import x10.util.HashSet;
import x10.util.concurrent.AtomicDouble;
import x10.util.concurrent.AtomicInteger;
import x10.util.concurrent.AtomicLong;

public class MCTNode {

  static public val rand:Random = new Random(System.nanoTime());

  // used to compute UCB during tree policy.
  static public val EXPLORE_PARAM:Double = .707; 


  // fields
  private val parent:MCTNode;
  private val turn:Stone;
  private val children:ArrayList[MCTNode];
  private val timesVisited:AtomicInteger;
  private val aggReward:AtomicDouble;
  private var state:BoardState;
  private var pass:Boolean;
  private var realMove:MCTNode;
  private val unexploredMoves:ArrayList[Int];
  private var expanded:Boolean;



  private val numAsyncsSpawned:AtomicInteger = new AtomicInteger(0);
  private static val x10_nthreads = 
    Int.parseInt(System.getenv().getOrElse("X10_NTHREADS", "1"));

  private static val MAX_ASYNCS:Int = (x10_nthreads * 1.1) as Int;
  private static val MAX_PLACES:Int = Place.MAX_PLACES;
  private static val BATCH_SIZE:Int = MAX_PLACES;
  private static val NODES_PER_PLACE:Int = BATCH_SIZE / MAX_PLACES;
  private static val MAX_DP_PATHS:Int = MAX_ASYNCS / NODES_PER_PLACE;

  private static val nodesProcessed:AtomicInteger = new AtomicInteger(0);
  private static val timeElapsed:AtomicLong = new AtomicLong(0);
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
    this.timesVisited = new AtomicInteger(0); // only gets incremented during backprop.
    this.aggReward = new AtomicDouble(0.0); // gets set during backprop.
    this.state = state;
    this.turn = parent == null ? Stone.BLACK : Stone.getOpponentOf(parent.turn);
    this.pass = pass;
    this.children = new ArrayList[MCTNode]();
    this.unexploredMoves = state.listOfEmptyIdxs();
    // Console.OUT.println("[this] num unexplored moves: " + this.unexploredMoves.size());
    // Console.OUT.println("[this] Stones of the new state: ");
    // for (var i:Int = 0; i < this.state.getSize(); i++) {
    //   Console.OUT.println("[this] idx: " + i + ", " + this.state.stoneAt(i));
    // }
    // Console.OUT.println("[this] num unexplored moves: " + this.unexploredMoves.size());
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
    // Console.OUT.println("[getBestChild] entering fn.");
    var bestVal:Double = Double.NEGATIVE_INFINITY;
    var bestValArg:MCTNode = null;
    for(var i:Int = 0; i < children.size(); i++) {
      val currChild:MCTNode = children(i);
      val currVal:Double = currChild.computeUcb(c);
      // Console.OUT.println("[getBestChild] times explored: " + currChild.timesVisited);
      // Console.OUT.println("[getBestChild] aggReward: " + currChild.aggReward);

      // Console.OUT.println("[getBestChild] current option: " + currVal);

      if (c == 0.0) {
        // Console.OUT.println("[getBestChild] board: ");
        // Console.OUT.println(currChild.getBoardState().print());
      }
      if(currVal > bestVal) {
        // Console.OUT.println("[getBestChild] new best val: " + currVal);
        bestVal = currVal;
        bestValArg = currChild;
      }

    }
    // Console.OUT.println("[getBestChild] returning best child with value: " + bestVal);
    return bestValArg;
  }


  /*
   * the node bound is calculated like this:
   * 1.1 * number of squares on the board approximates the number of moves
   * that a default policy will randomly generate to get to an end state.
   * We do a default policy for each square, so multiply by board size again.
   * Do 50 of those, for each square.
   */
  
  public def withinResourceBound(nodesProcessed:AtomicInteger):Boolean {
    // TODO: fix this formula / magic number / etc.
    val nodesProcessedBound = 10;//50 * 1.1 * this.state.getSize() * this.state.getSize();
    Console.OUT.println("[withinResourceBound] checking nodesProcessed: " + nodesProcessed.get());
    return nodesProcessed.get() < nodesProcessedBound;
  }


  // public def withinResourceBound(numDefaultPolicies:AtomicInteger,
  //       			 bound:Int):Boolean{
  //   return numDefaultPolicies.get() < bound;
  // }

  public def UCTSearch(val positionsSeen:HashSet[Int]):MCTNode {

    //val koTable:GlobalRef[HashSet[Int]] = new GlobalRef(positionsSeen);
    val MAX_DEFAULT_POLICIES:Int = Math.pow(state.getWidth() as Double, 3.0) as Int;

    // Console.OUT.println("max default policies: " + MAX_DEFAULT_POLICIES);
    // Console.OUT.println("max_dp_paths: " + MAX_DP_PATHS);
    val numDefaultPolicies:AtomicInteger = new AtomicInteger(0);
    val defaultPolicyDepth:Int = (state.getSize() / 
				  this.unexploredMoves.size()) * 30;


    val startTime:Long = Timer.nanoTime();
    numAsyncsSpawned.set(0);

    //while(withinResourceBound(numDefaultPolicies, MAX_DEFAULT_POLICIES)) { 
    // TODO: fix the validMovesLeft() hack here.
    if (!validMoveLeft()) {
      Console.OUT.println("no valid move found.");
      return new MCTNode(this, this.state, true);
    }
    while(withinResourceBound(nodesProcessed)) {
      // Select BATCH_SIZE new MCTNodes to simulate using TP
      val dpNodes:ArrayList[MCTNode] = new ArrayList[MCTNode](BATCH_SIZE);
      val treePolicyStartTime = Timer.nanoTime();
      for(childIdx in 0..(BATCH_SIZE - 1)) {
	val child:MCTNode = treePolicy(positionsSeen);
	if (child == this)
	  break;
	else
	  dpNodes.add(child);
      }

      tpTimeElapsed.addAndGet(Timer.nanoTime() - treePolicyStartTime);
      // Console.OUT.println("[tree policy] finished, yielding boards: ");
      //for(var i:Int = 0; i < dpNodes.size(); i++) {
        // Console.OUT.println("[tree policy] board: ");
        // Console.OUT.println(dpNodes(i).getBoardState().print());
        // Console.OUT.println("[tree policy] its unexplored moves: " + dpNodes(i).unexploredMoves.size());
        // Console.OUT.println("[tree policy] turn: " + dpNodes(i).turn);
      //}

      val dpNodeRegion:Region = Region.make(0, dpNodes.size()-1);
      val dpNodeResults:Array[Double] = new Array[Double](dpNodes.size());
      val dpStartTime = Timer.nanoTime();
      finish for (dpNodeIdx in dpNodeRegion) {
	val dpNode = dpNodes.get(dpNodeIdx(0));

        // Console.OUT.println("[default policy] BEFORE assignment of currBoardState.");
        for (var j:Int = 0; j < dpNode.state.getSize(); j++) {
          Stone.canPlaceOn(dpNode.state.stoneAt(j));
        }

        val currBoardState:BoardState = dpNode.state;

        // Console.OUT.println("[default policy] AFTER assignment of currBoardState.");
        for (var j:Int = 0; j < currBoardState.getSize(); j++) {
          Stone.canPlaceOn(currBoardState.stoneAt(j));
        }


        val dpValueTotal = new AtomicDouble(0.0);

        finish {
          for (var i:Int = 0; i < MAX_DP_PATHS; i++) {
            async {
              var currNode:MCTNode = new MCTNode(this, currBoardState);
              // Console.OUT.println("[default policy] node we're running on:");
              // Console.OUT.println("[default policy] currNode.turn: " + currNode.turn);
              // Console.OUT.println(currNode.getBoardState().print());
              var tempNode:MCTNode;
              var currDepth:Int = 0;
              val randomGameMoves:HashSet[Int] = positionsSeen.clone();
              randomGameMoves.add(currNode.state.hashCode());

              while(currNode != null && !currNode.isLeaf() &&
                    currDepth < defaultPolicyDepth) {
                nodesProcessed.incrementAndGet();
                // Console.OUT.println("[default policy] unexplored moves: " + currNode.unexploredMoves.size());
                tempNode = currNode.generateChildNoModify(randomGameMoves);
                //Console.OUT.println("[default policy] random child:");

                //Console.OUT.println(tempNode.getBoardState().print());
                if(tempNode != null) {
                  // Console.OUT.println("[default policy] non-null; adding it to the random game.");
                  currNode = tempNode;
                  randomGameMoves.add(currNode.state.hashCode());
                }
                currDepth++;
              }
              //Console.OUT.println("[default policy] yielding on this board: ");
              //Console.OUT.println(currNode.getBoardState().print());
              //Console.OUT.println("the leaf value of this board is " + currNode.leafValue());
              // TODO: this is the minimax error.
              dpValueTotal.getAndAdd(currNode.leafValue());
            }
          }
        }

        dpNodeResults(dpNodeIdx(0)) = dpValueTotal.get();

        // TODO: we do more than one default policy.  figure out how many to
        // increment this by.
        numDefaultPolicies.getAndAdd(1);
      }

      dpTimeElapsed.addAndGet(Timer.nanoTime() - dpStartTime);


      val bpStartTime = Timer.nanoTime();
      finish for (dpNodeIdx in dpNodeRegion) {
	val dpNode = dpNodes(dpNodeIdx(0));
        if(numAsyncsSpawned.get() < MAX_ASYNCS) {
          numAsyncsSpawned.incrementAndGet();
          async {
            val outcome:Double = dpNodeResults(dpNodeIdx);
            backProp(dpNode, outcome);
            numAsyncsSpawned.decrementAndGet();
          } 
        } else {
            val outcome:Double = dpNodeResults(dpNodeIdx);
          backProp(dpNode, outcome);
        }
      }

      bpTimeElapsed.addAndGet(Timer.nanoTime() - bpStartTime);
      
    } // end 'while within resource bound'


    Console.OUT.println("On this turn: ");
    Console.OUT.println("nodes processed: " + nodesProcessed.get());
    Console.OUT.println("time elapsed: " + (Timer.nanoTime() - startTime));

    totalNodesProcessed.getAndAdd(nodesProcessed.get());
    totalTimeElapsed.getAndAdd(Timer.nanoTime() - startTime);


    // Console.OUT.println("GAME TO NOW total nodes processed: " +
    //                     totalNodesProcessed.get());
    // Console.OUT.println("GAME TO NOW total computing time elapsed: " +
    //                     totalTimeElapsed.get());
    nodesProcessed.set(0);

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

        // uncomment to eliminate recursive descent:
        //return bc;

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


  public def generateChildNoModify(positionsSeen:HashSet[Int]):MCTNode {
    //generate the passing child
    // Console.OUT.println("[generateChildNoModify] inside fn.");
    val possibleMoves = unexploredMoves.clone();
    // Console.OUT.println("[generateChildNoModify] unexplored moves left: " + unexploredMoves.size());
    // Console.OUT.println("[generateChildNoModify] current turn: " + this.turn);
    while(!possibleMoves.isEmpty()) {
      var randIdx:Int;
      var possibleState:BoardState = BoardState.NONE;

      // TODO: should this be possibleMoves?
      // if it should be, this check is redundant:
      if (unexploredMoves.size() > 0) {
	randIdx = rand.nextInt(possibleMoves.size());
        // Console.OUT.println("[generateChildNoModify] randIdx is " + randIdx);
        // Console.OUT.println("[generateChildNoModify] possibleMoves(randIdx) is " + possibleMoves(randIdx));
	possibleState = state.doMove(possibleMoves(randIdx), turn);
	possibleMoves.removeAt(randIdx);
      }

      // if valid move (doMove catches invalid, save Ko) AND not seen
      // before (Ko)
      if(possibleState != BoardState.NONE &&
         !positionsSeen.contains(possibleState.hashCode())) {
        // Console.OUT.println("found a valid move with randidx");
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
      var possibleState:BoardState = BoardState.NONE;

      if (unexploredMoves.size() > 0) {
	randIdx = rand.nextInt(unexploredMoves.size());
	possibleState = state.doMove(unexploredMoves(randIdx), turn);
	unexploredMoves.removeAt(randIdx);
      }

      // if valid move (doMove catches invalid, save Ko) AND not seen
      // before (Ko)
      if(possibleState != BoardState.NONE &&
         !positionsSeen.contains(possibleState.hashCode())) {
        var newNode:MCTNode = new MCTNode(this, possibleState);
        return newNode;
      }
    }

    return null;
  }


  public def leafValue():Double {
    // Console.OUT.println("the current leader is " + state.currentLeader());
    //if (state.currentLeader() == turn)
    if (state.currentLeader() == Stone.BLACK)
      return 1.0;
    //else if (state.currentLeader() == Stone.getOpponentOf(turn))
    else if (state.currentLeader() == Stone.WHITE)
      return 0.0;
    else
      return 0.5;
  }


  // TODO: update this so it doesn't go all the way to the root.  a minor optimization.
  public def backProp(var currNode:MCTNode, val reward:Double):void {
    while(currNode != null) {
      // Console.OUT.println("[backProp] old timesVisited: " + currNode.timesVisited.get());
      // Console.OUT.println("[backProp] old aggReward: " + currNode.aggReward.get());
      currNode.timesVisited.addAndGet(MAX_DP_PATHS); // b/c we do
                                                     // MAX_DP_PATHS parallel default policies
      // TODO: fix this magic Stone.BLACK, like at leafValue()
      if (currNode.turn == Stone.WHITE)
        currNode.aggReward.addAndGet(reward);
      else
        currNode.aggReward.addAndGet(-1 * reward);
      // Console.OUT.println("[backProp] new timesVisited: " + currNode.timesVisited.get());
      // Console.OUT.println("[backProp] new aggReward: " + currNode.aggReward.get());

      // if (reward == 1.0) {
        // Console.OUT.println("[backProp] found a winning move.");
      // }
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

  // TODO: is there an O(1) way to do this
  public def validMoveLeft():Boolean {
    for(var i:Int = 0; i < state.getSize(); i++) {
      if(state.doMove(i, turn) != BoardState.NONE) {
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
