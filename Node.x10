// A single node in the Go game tree.

import x10.util.ArrayList

public class MCTNode {

  private val MAXINT = 999999; // TODO: find out what this is actually called.
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

  // constructors

  // the parent is in charge of generating board state, to make sure we
  // don't repeat ourselves.
  public def this(var parent:MCTNode, var state:BoardState, val turn:Int):void {
    this.parent = parent;
    this.timesVisited = 0; // only gets incremented during backprop.
    this.aggReward = 0; // gets set during backprop.
    this.state = state;
    this.turn = turn ^ TRUE; // XOR T flips the bit.
    this.bestChildUcb = MAXINT; // we'll always pick the best one to expand on...presumes we get through all the infinite-valued kids before performing the node expansion.
    this.bestChild = null;
    // we'll not set the children using generateChildren() in the constructor--this would generate the entire game tree.
  }

  // default constructor.
  public def this(){}

  // methods

  // we need to explicitly generate children outside of constructor, so as
  // to avoid generating the whole game tree by constructing the root.
  public def generateChildren(){
    this.children = new ArrayList[MCTNode](CHILDINITSIZE);
    // walk over the board, if the space is
    var tempState = new BoardState(); // TODO: I don't think this is the write way to do the ref work...I think I'm just tired.
    for(var s:Int = 0; s < this.state.spaces.length; s++) {
      if(this.state.spaces(s) == 0) {
        // generate the BoardState that is derived from placing a piece here, then
          // row, column, stone
        tempState = this.state.doMove(s, coords);
        if(tempState) { // if the tempState is non-null, so is valid.
          children.add(tempState);
        }
      }
    }
  }
  
  public def computeUcb():Double{
    // calculation involves the parent.  TODO: make sure we don't try to
    // calc this for the root node.
    return this.aggReward + (2 * MAGICCONST * Math.sqrt((2 * Math.log(this.parent.timesVisited)) / this.timesVisited)); // TODO: is it aggRewards that we want?
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

  // from the given node, simulate gameplay until a win is reached.
  // public def simulate() {
    
  // }

}
