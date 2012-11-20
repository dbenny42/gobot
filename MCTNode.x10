// A single node in the Go game tree.

import x10.util.ArrayList;
import x10.util.Random;
import x10.util.Timer;
import x10.lang.Boolean;
import x10.util.HashSet;
import x10.util.concurrent.AtomicDouble;
import x10.util.concurrent.AtomicInteger;

public class MCTNode {

  static public val rand:Random = new Random(System.nanoTime());

  // used to compute UCB during tree policy.
  static public val EXPLORE_PARAM:Double = .707; 


  // fields
  private var parent:MCTNode;
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


    while(withinResourceBound(numDefaultPolicies, MAX_DEFAULT_POLICIES)) { 

      // Select BATCH_SIZE new MCTNodes to simulate using TP
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
      val da:DistArray[Double] =
        DistArray.make[Double](Dist.makeBlock(dpNodeRegion, 0));

      finish for (dpNodeIdx in dpNodeRegion) {
	val dpNode = dpNodes.get(dpNodeIdx(0));

        val currBoardState:BoardState = dpNode.state;
	at (da.dist(dpNodeIdx(0))) {
	  async {
	    // da(dpNodeIdx(0)) = defaultPolicy(positionsSeen,
            //                                  currBoardState,
            //                                  defaultPolicyDepth);


            val dp_value_total = new AtomicDouble(0.0);

            finish {
              for (var i:Int = 0; i < MAX_DP_PATHS; i++) {
                async {
                  var currNode:MCTNode = new MCTNode(currBoardState);
                  var tempNode:MCTNode;
                  var currDepth:Int = 0;
                  val randomGameMoves:HashSet[Int] = positionsSeen.clone();
                  randomGameMoves.add(currNode.state.hashCode());
                  while(currNode != null && !currNode.isLeaf() &&
                        currDepth < defaultPolicyDepth) {

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

            da(dpNodeIdx(0)) = dp_value_total.get();



	  }
	}
      }

      // Console.OUT.println("Here's the distarray: ");
      // for(dpNodeIdx in dpNodeRegion) {
      //   //at(da.dist(dpNodeIdx(0))) {
      //     Console.OUT.print(da(dpNodeIdx(0)) + ", ");
      //   //}
      // }
      // Console.OUT.println();



      numDefaultPolicies.incrementAndGet();



      finish for (dpNodeIdx in dpNodeRegion) {
	val dpNode = dpNodes.get(dpNodeIdx(0));
        if(numAsyncsSpawned.get() < MAX_ASYNCS) {
          numAsyncsSpawned.incrementAndGet();
          async {
            val outcome:Double =
              //at(da.dist(dpNodeIdx(0)))
                da(dpNodeIdx(0));
            backProp(dpNode, outcome);
            numAsyncsSpawned.decrementAndGet();
          } 
        } else {
            val outcome:Double =
              //at(da.dist(dpNodeIdx(0)))
                da(dpNodeIdx(0));
            backProp(dpNode, outcome);
        }
      }

    } // end 'while within resource bound'

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

  // public def defaultPolicy(val positionsSeen:HashSet[Int],
  //       		   val startState:BoardState,
  //       		   val maxDepth:Int):Double {

  //   val dp_value_total = new AtomicDouble(0.0);

  //   finish {
  //     for (var i:Int = 0; i < MAX_DP_PATHS; i++) {
  //       async {
  //         var currNode:MCTNode = new MCTNode(startState);
  //         var tempNode:MCTNode;
  //         var currDepth:Int = 0;
  //         val randomGameMoves:HashSet[Int] = positionsSeen.clone();
  //         randomGameMoves.add(currNode.state.hashCode());
  //         while(currNode != null && !currNode.isLeaf() && currDepth < maxDepth) {
  //           // TODO: does this really need to be generateRandomChildState()?
  //           tempNode = currNode.generateChildNoModify(randomGameMoves);
  //           if(tempNode != null) {
  //             currNode = tempNode;
  //             randomGameMoves.add(currNode.state.hashCode());
  //           }
  //           currDepth++;
  //         }
  //         dp_value_total.getAndAdd(leafValue(currNode));
  //       }
  //     }
  //   }
  //   return dp_value_total.get();
  // }


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
