// A single node in the Go game tree.

// TODO: pass never gets set to "true" under the current circumstances

import x10.util.ArrayList
import x10.util.Random
import x10.util.Timer;

public class MCTNode {

  static val rand:Random = new Random(System.nanoTime());
  static val PASSFLOOR:Int = 3; // completely arbitrary at this point.

  private val CHILDINITSIZE = 10;
  // fields
  private val parent:MCTNode;
  private val turn:Boolean; // TRUE is black, FALSE is white ("little white lies")
  private var children:ArrayList[MCTNode];
  private var timesVisited:Int;
  private var aggReward:Int;
  private var state:BoardState;
  private var bestChildUcb:Double;
  private var bestChild:MCTNode;
  private var boolean:pass;
  private var actionToTry:Int;

  // constructors

  // the parent is in charge of generating board state, to make sure we
  // don't repeat ourselves.
  public def this(var parent:MCTNode, var state:BoardState):void {
    this.parent = parent;
    this.timesVisited = 0; // only gets incremented during backprop.
    this.aggReward = 0; // gets set during backprop.
    this.state = state;
    this.turn = parent == null ? FALSE : parent.turn ^ TRUE; // XOR T flips the bit.  TODO: optimize the inital setting so we don't have to check for null parent on every node generated.
    this.bestChildUcb = -99; // we'll always pick the best one to expand on...presumes we get through all the infinite-valued kids before performing the node expansion.
    this.bestChild = null;
    this.pass = FALSE;
    this.children = new ArrayList[MCTNode](CHILDINITSIZE);
    this.actionToTry = 0; // refers to the next index to be tried as a child action.
  }

  // methods
  public def computeUcb():Double{
    // calculation involves the parent.  TODO: make sure we don't try to
    // calc this for the root node.
    return (this.aggReward / this.timesVisited) + (2 * MAGICCONST * Math.sqrt((2 * Math.log(this.parent.timesVisited)) / this.timesVisited));
  }

  // this is going to have to get called when the child we simmed has its UCB diminished.
  // this can probably be private:
  public def updateBestChild(){
    var tempUcb:Double;

    // TODO: optimize this later on with something that does max accesses better.
    for(var i:Int = 0; i < children.size(); i++) {
      // TODO: if we're optimizing, we might get better results if we cache the last value of UCB, instead of computing it.
      tempUcb = children(i).computeUcb;
      if(tempUcb > bestUcb) {
        bestChildUcb = tempUcb;
        bestChild = children(i);
      }
    }
  }

  // generate the action to take, a unique MCTNode whose board state has not been seen before.
  public def UCTSearch(var positionsSeen:HashMap[BoardState, Boolean], val player:Boolean):MCTNode{
    while(withinResourceBound()) {
      var child:MCTNode treePolicy(positionsSeen);
      var outcome:Int = defaultPolicy(child, player); // uses the nodes' best descendant, generates an action.
      // no need to return anythinng, because
      backProp(child, outcome);
    }
    if(this.bestChildUcb < PASSFLOOR) {
      this.pass = TRUE;
      return null;
    } else {
      return this.bestChild;
    }
  }

  // TODO: change the name of this function.
  // find the most urgent expandable child, expand its children, pick one to simulate.
  public def treePolicy(var positionsSeen:HashMap[BoardState, Boolean]):MCTNode{
    var child:MCTNode = generateChild(positionsSeen);
    if(child == null) {
      if(this.children.isEmpty()){
        // dealing with a leaf
        return null; // TODO: force-pass, figure out how to code this.
      } else {
        return this.bestChild; // all kids generated; just return best one.
      }
    } else {
      this.children.add(child); // add to list.
      return child;
    }
  }

  public def generateChild(var positionsSeen:HashMap[BoardState, Boolean]):MCTNode {
    var stone:Stone;

    while(this.actionToTry < (this.state.height * this.state.width)) {
      var possibleState:BoardState = doMove(this.actionToTry, stone);
      if(possibleState != null && positionsSeen.get(possibleState) == null) {
        return MCTNode(this, possibleState);
      }
    }

    // no more actions are possible.
    return null;
  }

  public def defaultPolicy(var currNode:MCTNode, val player:Boolean):Int {
    while(!currNode.isLeaf()){
      currNode = currNode.generateRandomChildState();
    }
    return leafValue(currNode, player);
  }

  public def leafValue(var currNode:MCTNode, val player:Boolean):Int {
    // 'this' is the root of the current game subtree, so we know whose turn it is.
    if(!player) { // player is white
      if(this.state.currentLeader() == Stone.WHITE) {
        return 1;
      } else if(this.state.currentLeader() == Stone.BLACK) {
        return -1;
      } else {
        return 0;
      }
    } else { // player is black
      if(this.state.currentLeader() == Stone.WHITE) {
        return -1;
      } else if(this.state.currentLeader() == Stone.BLACK) {
        return 1;
      } else {
        return 0;
      }
    }
  }

  public def generateRandomChildState():MCTNode {
    var stone:Stone = stoneFromTurn(this.turn);
    var childState:BoardState = doMove(rand.nextInt(this.height * this.width), stone);
    while(childState == null || positionsSeen.get(childState) != null) {
      childState = doMove(rand.nextInt(this.height * this.width), stone);
    }
    return MCTNode(this, childState);
  }

  public def backProp(val currNode:MCTNode, val reward:Int):Int {
    while(currNode != null) {
      currNode.updateBestChild();
      currNode.timesVisited++;
      currNode.aggReward + reward;
      currNode = currNode.parent;
    }
  }

  public def isLeaf():Boolean {
    // something is a leaf when it either has no valid moves, or both the preceding boards were 'passes'.
    return isLeafOnPasses() || !validMoveLeft();
  }

  public def isLeafOnPasses():Boolean {
    return (this.parent != null && this.parent.parent != null && this.parent.pass && this.parent.parent.pass);
  }

  public def validMoveLeft():Boolean {
    var stone:Stone = stoneFromTurn(this.turn);
    for(var i:Int = 0; i < this.state.height * this.state.width; i++) {
      if(doMove(i, stone) != null) {
        return TRUE;
      }
    }
    return FALSE;
  }

  public def stoneFromTurn():Stone{
    if(this.turn) {
      stone = Stone.BLACK;
    } else {
      stone = Stone.WHITE;
    }
  }

  public def findOpponentMoveInChildren(BoardState b):MCTNode {
    for(var i:Int = 0; i < children.size(); i++) {
      if(children(i).state == b){
        
      }
    }
  }

}
