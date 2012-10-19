// A single node in the Go game tree.

public class MCTNode {
  // fields
  public val parent:MCTNode;
  public val children:Rail[MCTNode];
  public val timesVisited:Int;
  public val aggReward:Int;
  public val state:BoardState;
  public var bestUcb:Double;
  public var bestChild:MCTNode;

  // constructors

  // the parent is in charge of generating board state, to make sure we
  // don't repeat ourselves.
  public def MCTNode(MCTNode parent, BoardState s):void {
    this.parent = parent;
    this.state = s;
    timesVisited = 0; // only gets incremented during backprop.
    aggReward = 
  }

  // default constructor.
  public def MCTNode(){}

  // methods

  // we need to explicitly generate children outside of constructor, so as
  // to avoid generating the whole game tree by constructing the root.
  public def generateChildren(){
    
  }
  
  public def computeUCB(){
    
  }

  public def pickNextChildToCompute(){
    
  }
};
