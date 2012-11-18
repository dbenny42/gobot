import x10.util.HashSet;

public class Chain {

  private val stone:Stone;
  private val members:HashSet[Int];
  private val adjacencies:HashSet[Int];
  private val liberties:HashSet[Int];

  /**
   * Constructs a new Chain from a singleton stone. Performs no merging.
   *
   * Args:
   *   idx: index at which the new chain starts.
   *   stone: Type of stone that comprises the new chain
   *   board: board on which the new chain sits
   */
  public def this(idx:Int, stone:Stone, board:BoardState) {
    this.stone = stone;
    this.members = new HashSet[Int]();
    this.adjacencies = new HashSet[Int]();
    this.liberties = new HashSet[Int]();

    this.members.add(idx);
    for (adjIdx in board.getAdjacentIndices(idx)) {
      this.adjacencies.add(adjIdx);
      if (Stone.canPlaceOn(board.stoneAt(adjIdx)))
	this.liberties.add(adjIdx);
    }    
  }

  /**
   * Copy ctor
   */
  public def this(toCopy:Chain) {
    this.stone = toCopy.getStone();
    this.members = toCopy.getMembers();
    this.adjacencies = toCopy.getAdjacencies();
    this.liberties = toCopy.getLiberties();
  }

  /**
   * Returns a copy of this Chain's member set
   *
   * Returns: A HashSet containing all board indices that are part of this set.
   */
  public def getMembers():HashSet[Int] {
    return this.members.clone();
  }

  /**
   * Returns the stone type that comprise this chain
   *
   * Returns:
   *  Member of stone enum that this chain is made of.
   */
  public def getStone():Stone {
    return this.stone;
  }

  /**
   * Returns a copy of this Chain's adjacency set
   *
   * Returns:
   *   A HashSet containing all board indices that are adjacent to
   *   this set.
   */
  public def getAdjacencies():HashSet[Int] {
    return this.adjacencies.clone();
  }

  /**
   * Returns a copy of this Chain's liberty set
   *
   * Returns:
   *   A HashSet containing all board indices that are part of this set's
   *   liberties.
   */
  public def getLiberties():HashSet[Int] {
    return this.liberties.clone();
  }

  /**
   * Returns true if this set has no liberties
   *
   * Returns:
   *   True if this set has no liberties.
   */
  public def isDead():Boolean {
    return this.liberties.isEmpty();
  }

  /**
   * Returns the cardinality of this chain's member set
   *
   * Returns:
   *   The number of stones in this set.
   */
  public def getSize():Int {
    return this.members.size();
  }

  /*
   * Merges two chains. Called after a new stone is placed and its chain
   * created to merge with same-colored adjacent chains.
   *
   * Args:
   *  connPt: index by which the merged chains are connected.
   *  toMerge: Chain to merge this chain with.
   */
  public def merge(connPt:Int, toMerge:Chain):Chain {

    val newChain = new Chain(this);

    newChain.members.addAll(toMerge.getMembers());
    newChain.liberties.addAll(toMerge.getLiberties());
    newChain.liberties.remove(connPt);
    newChain.adjacencies.addAll(toMerge.getAdjacencies());
    newChain.adjacencies.remove(connPt);

    return newChain;
  }

  /**
   * Adds several indices to this chains liberty set. Called after a chain
   * dies to inform neighbor chains of the new liberties. 
   *
   * Args:
   *  indices: Indices to add to the liberty set. May include nonadjacent
   *  indices which should not be added.
   */
  public def addLiberties(indices:HashSet[Int]):Chain {

    val newChain = new Chain(this);

    for (idx in indices) {
      if (newChain.adjacencies.contains(idx)) {
	newChain.liberties.add(idx);
      }
    }

    return newChain;
  }

  /**
   * Removes an index from this chain's liberty set. Called after a stone is
   * placed to inform neighbor chains of the lost liberty.
   *
   * Args:
   *  idx: Index to remove from liberty set
   */
  public def takeLiberty(idx:Int):Chain {
    val newChain = new Chain(this);
    newChain.liberties.remove(idx);
    return newChain;
  }

}
