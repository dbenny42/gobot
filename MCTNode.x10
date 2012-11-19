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
  private val turn:Stone; // Boolean.TRUE is black, FALSE is white ("little white lies")
  private var children:ArrayList[MCTNode];
  private var timesVisited:Int;
  private var aggReward:Double;
  private var state:BoardState;
  private var pass:Boolean;
  private var realMove:MCTNode;
  private var listOfEmptyIdxs:ArrayList[Int];
  private var expanded:Boolean;

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
    this.turn = parent == null ? Stone.BLACK : Stone.getOpponentOf(parent.turn);
    this.listOfEmptyIdxs = state.listOfEmptyIdxs();
    this.children = new ArrayList[MCTNode](CHILDINITSIZE);
    this.pass = Boolean.FALSE;
    this.expanded = Boolean.FALSE;
  }

  public def this(var parent:MCTNode, var state:BoardState, var pass:Boolean) {
    this.parent = parent;
    this.timesVisited = 0; //only gets incremented during backprop.
    this.aggReward = 0.0; // gets set during backprop.
    this.state = state;
    this.turn = parent == null ? Stone.BLACK : Stone.getOpponentOf(parent.turn);
    this.pass = pass;
    this.children = new ArrayList[MCTNode](CHILDINITSIZE);
    this.listOfEmptyIdxs = state.listOfEmptyIdxs();
    this.expanded = Boolean.FALSE;
   }

  public def this(var state:BoardState) {
    this.parent = null;
    this.timesVisited = 0; // only gets incremented during backprop.
    this.aggReward = 0.0; // gets set during backprop.
    this.state = state;
    this.turn = parent == null ? Stone.BLACK : Stone.getOpponentOf(parent.turn);
    this.pass = Boolean.FALSE;
    this.children = new ArrayList[MCTNode](CHILDINITSIZE);
    this.listOfEmptyIdxs = state.listOfEmptyIdxs();
    this.expanded = Boolean.FALSE;
  }


  // methods
  public def computeUcb(val c:Double):Double{
    // calculation involves the parent.  TODO: make sure we don't try to
    // calc this for the root node.

    var ucb:Double = (aggReward / timesVisited) + (2 * c * Math.sqrt((2 * Math.log((parent.timesVisited as Double))) / timesVisited));
    var weight:Double;

    if(parent != null) {
      if(turn == Stone.BLACK) {
        //Console.OUT.println("my stone: black");
      } else {
        //Console.OUT.println("my stone: white");
      }
      //Console.OUT.println("pass: " + pass + ", parent.pass: " + parent.pass + ", my score: " + getMyScore() + ", opp score: " + getOppScore());
    }
    if(pass) {
      // weight passing, so it's more attractive as the game progresses.

      // if the opponent passed and the computer is winning, it should pass and win
      if(parent != null && parent.pass && (getMyScore() < getOppScore())) {
        //Console.OUT.println("I SHOULD WIN NOW");
        weight = 1000; // computer should automatically win.
      } else {
        //Console.OUT.println("NON-WINNER.");
        weight = (((state.getWhiteScore() as Double) + (state.getBlackScore() as Double)) / ((state.getHeight() as Double) * (state.getWidth() as Double)));
      }

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
      //Console.OUT.println("children(" + i + ") ucb: " + currVal);
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

  public def UCTSearch(var positionsSeen:HashSet[BoardState]):MCTNode{

    //Console.OUT.println("current pass is: " + pass);
    val startTime:Long = Timer.milliTime();

    finish {
      while(withinResourceBound(startTime)) { // TODO: implement the resource bound.
        if(numAsyncsSpawned < MAXASYNCS) {
          atomic numAsyncsSpawned++;
          async {
            var child:MCTNode = treePolicy(positionsSeen);

            var outcome:Double = defaultPolicy(positionsSeen, child); // uses the nodes' best descendant, generates an action.
            backProp(child, outcome);
            atomic numAsyncsSpawned--;
          } // finish async
        } else {
          var child:MCTNode = treePolicy(positionsSeen);
          var outcome:Double = defaultPolicy(positionsSeen, child); //uses the nodes' best descendant, generates an action.
          backProp(child, outcome);
        }
      } // end while.
    } // end finish


    var bestChild:MCTNode = getBestChild(0);

    // if(bestChild.computeUcb(0) < PASSFLOOR) {
    //   //Console.OUT.println("best move below the passfloor.");
    //   return new MCTNode(this, state, Boolean.TRUE);
    // } else {
    //   if((parent != null) && parent.pass && (leafValue(this, stone) > 0)) {
    //     //Console.OUT.println("computer's about to win.");
    //     return new MCTNode(this, state, Boolean.TRUE);
    //   } else {
    //     return bestChild;
    //   }
    // }

    return bestChild;
  }


  public def treePolicy(var positionsSeen:HashSet[BoardState]):MCTNode{

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



  public def generateChild(var positionsSeen:HashSet[BoardState]):MCTNode {
    //Console.OUT.println("inside generate child.");
    //generate the passing child
    if(listOfEmptyIdxs.isEmpty() && !expanded) {
      //Console.OUT.println("generating the passing move.");
      expanded = Boolean.TRUE;
      return new MCTNode(this, state, Boolean.TRUE);
    }

    while(!listOfEmptyIdxs.isEmpty()) {
      //Console.OUT.println("looping inside genchild");
      var randIdx:Int = rand.nextInt(listOfEmptyIdxs.size());
      var possibleState:BoardState = state.doMove(listOfEmptyIdxs(randIdx), turn);
      listOfEmptyIdxs.removeAt(randIdx);

      // if valid move (doMove catches invalid, save Ko) AND not seen
      // before (Ko)
      if(possibleState != null && !positionsSeen.contains(possibleState)) {
        var newNode:MCTNode = new MCTNode(this, possibleState);
        return newNode;
      }
    }
    
    // no more actions are possible.
    return null;
  }

  public def defaultPolicy(var positionsSeen:HashSet[BoardState], var currNode:MCTNode):Double {
    //Console.OUT.println("playing a default policy.");
    var randomGameMoves:HashSet[BoardState] = positionsSeen.clone();
    randomGameMoves.add(currNode.state);

    var tempNode:MCTNode = currNode;
    while(tempNode != null && !tempNode.isLeaf()){
      //Console.OUT.println("looping in default policy.");
      tempNode = currNode.generateRandomChildState(randomGameMoves);
      if(tempNode != null) {
        //Console.OUT.println("updating currnode in default policy.");
        currNode = tempNode;
        randomGameMoves.add(currNode.state);
      }
    }
    //Console.OUT.println("about to return the leaf value.");
    return leafValue(currNode);
  }


  public def leafValue(var currNode:MCTNode):Double {

    // 'this' is the root of the current game subtree, so we know whose turn it is.
    if(turn == Stone.WHITE) { // stone is white
      if(currNode.state.currentLeader() == Stone.WHITE) {
        return 1.0;
      } else if(currNode.state.currentLeader() == Stone.BLACK) {
        return 0.0;
      } else {
        return 0.5;
      }
    } else { // stone is black
      if(currNode.state.currentLeader() == Stone.WHITE) {
        return 0.0;
      } else if(currNode.state.currentLeader() == Stone.BLACK) {
        return 1.0;
      } else {
        return 0.5;
      }
    }
  }

  public def generateRandomChildState(var randomGameMoves:HashSet[BoardState]):MCTNode {
    // 1: get an arraylist of the empty squares, generate one of THOSE randomly, remove it if it's an invalid move, and 
    var emptyIdxs:ArrayList[Int] = state.listOfEmptyIdxs();
    var randIdx:Int = rand.nextInt(emptyIdxs.size());
    var childState:BoardState = state.doMove(emptyIdxs.get(randIdx), turn);
    emptyIdxs.removeAt(randIdx);

    while(!emptyIdxs.isEmpty()) {
      //Console.OUT.println("working through generate random child state.");
      if((childState != null) && !randomGameMoves.contains(childState)) {
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
  }

  // TODO: update this so it doesn't go all the way to the root.  a minor optimization.
  public def backProp(var currNode:MCTNode, val reward:Double):void {
    //Console.OUT.println("inside backprop.");
    while(currNode != null) {
      //Console.OUT.println("backprop while loop.");
      atomic currNode.timesVisited++;
      atomic currNode.aggReward += reward;
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
        //Console.OUT.println("FOUND THE MOVE");
        return children(i);
      } 
    }
    //Console.OUT.println("did not find move in opponent's game tree.");
    return null;
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
    for(var i:Int = 0; i < state.getSize(); i++) {
      if(state.doMove(i, turn) != null) {
        return Boolean.TRUE;
      }
    }
    return Boolean.FALSE;
  }


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




  public def getMyScore():Int {
    return (turn == Stone.BLACK ? state.getBlackScore() : state.getWhiteScore());
  }

  public def getOppScore():Int {
    return (turn == Stone.BLACK ? state.getWhiteScore() : state.getBlackScore());
  }


  // getters 

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

  // setters

  public def setPass(val b:Boolean):void {
    pass = b;
  }
}
