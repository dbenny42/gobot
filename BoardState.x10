import x10.util.StringBuilder;
import x10.util.HashSet;
import x10.util.Pair;

public class BoardState {

  private val height:Int;
  private val width:Int;
  private val stones:Array[Stone];
  private val chains:Array[Chain];

  private var whiteScore:Int;
  private var blackScore:Int;

  private var hash:Int;

  /**
   * Constructs a new BoardState for an empty board with the given dimensions.
   *
   * Args:
   *   height: Height of the new board
   *   width: Width of the new board
   */
  public def this(height:Int, width:Int) {
    this.height = height;
    this.width = width;
    this.stones = new Array[Stone](height*width, Stone.EMPTY);
    this.chains = new Array[Chain](height*width);

    this.whiteScore = 0;
    this.blackScore = 0;
  }

  /**
   * Constructs a copy of the provided BoardState
   *
   * Args:
   *   toCopy: BoardState to be copied
   */
  public def this(toCopy:BoardState) {
    this.height = toCopy.height;
    this.width = toCopy.width;
    this.stones = new Array[Stone](toCopy.stones);

    this.chains = new Array[Chain](toCopy.chains);

    this.whiteScore = toCopy.whiteScore;
    this.blackScore = toCopy.blackScore;
  }

  // assumes equal height and width
  public def equals(toTest:BoardState) {
    for(var i:Int = 0; i < getSize(); i++) {
      if(toTest.stones(i) != this.stones(i)) {
        return Boolean.FALSE;
      }
    }
    return Boolean.TRUE;
  }

  /**
   * Returns White's score for this board
   *
   * Returns:
   *   White's score
   */
  public def getWhiteScore():Int {
    return this.whiteScore;
  }

  /**
   * Returns Black's score for this board
   *
   * Returns:
   *   Black's score
   */
  public def getBlackScore():Int {
    return this.blackScore;
  }

  /**
   * Adds a given quantity to the score associated with a stone type.
   */
  private def addScore(toAdd:Int, stone:Stone) {
    if (stone == Stone.WHITE)
      this.whiteScore += toAdd;
    else {
      this.blackScore += toAdd;
    }
  }

  /**
   * Returns which kind of stone is currently leading in points on this board.
   *
   * Returns an empty stone in the case of a tie.
   *
   * Returns:
   *   Stone.BLACK, Stone.WHITE, or Stone.EMPTY depending on the leader
   */
  public def currentLeader():Stone{
    Console.OUT.println("inside 'currentLeader()'");
    if (this.blackScore > this.whiteScore) {
      Console.OUT.println("black is current leader");
      return Stone.BLACK;
    }
    
    else if (this.blackScore < this.whiteScore) {
      Console.OUT.println("white is current leader");
      return Stone.WHITE;
    }

    else {
      Console.OUT.println("empty is current leader?");
      return Stone.EMPTY;
    }
  }

  /**
   * Returns the size of the play board
   *
   * Returns:
   *   The number of spots on the board.
   */
  public def getSize():Int {
    return this.stones.size;
  }

  /**
   * Returns the type of stone located at the given board index
   *
   * Args:
   *   idx: Index on board to check
   *
   * Returns:
   *   The type of stone at the given index
   */
  public def stoneAt(idx:Int):Stone {
    return this.stones(idx);
  }

  /**
   * Returns true if the board has the given index.
   *
   * Args:
   *   idx: Index on board to check
   * 
   * Returns:
   *   True if the board has the given index.
   */
  public def hasIdx(idx:Int):Boolean {
    return idx < this.stones.size;
  }

  /**
   * Converts a row/column position into an index
   *
   * Args:
   *   row: Row of position to convert to an index
   *   col: Column of position to convert to an index
   *
   * Returns:
   *   The index of the row, col pair
   */
  private def getIdx(row:Int, col:Int):Int {
    if (row >= this.height || col >= this.width)
      return -1;
    else if (row < 0 || col < 0)
      return -1;
    else
      return row*this.width + col;
  }

  /**
   * Converts an index into a row/column pair
   *
   * Args:
   *   idx: Index to convert to a pair
   *
   * Returns:
   *   A Pair whose first element is the row and second element is the
   *   column number
   */
  public def getCoord(idx:Int):Pair[Int, Int] {
    val row = idx / this.width;
    val col = idx - (row * this.width);
    return new Pair[Int, Int](row, col);
  }

  /**
   * Returns true if the given row/column pair exists on the board
   *
   * Args:
   *   row: Row index of position
   *   col: Column index of position
   *
   * Returns:
   *   True if the row/col pair is a valid board position.
   */
  private def hasCoord(row:Int, col:Int):Boolean {
    return (this.getIdx(row, col) == -1);
  }

  /**
   * Returns true if there is no stone at the given board index
   *
   * Args:
   *   idx: Index to check for emptiness at.
   * Returns:
   *   True if there is no stone at the given board index.
   */
  public def isEmptyAt(idx:Int):Boolean {
    return (this.stoneAt(idx) == Stone.EMPTY);
  }

  /**
   * Place a stone at the given position, updating the board as necessary.
   *
   * This function returns a new BoardState object, or null if the move was
   * invalid.
   *
   * Args:
   *   row: Row index at which the new stone should be placed
   *   col: Column index at which the new stone should be placed
   *   stone: Stone to place
   *
   * Returns:
   *   A new BoardState object, or null if the move was invalid
   */
  public def doMove(row:Int, col:Int, stone:Stone):BoardState {
    val idx = getIdx(row, col);
    return doMove(idx, stone);
  }

  /**
   * Place a stone at the given index, updating the board as necessary.
   *
   * This function returns a new BoardState object, or null if the move was
   * invalid.
   *
   * Args:
   *   idx: Index at which the new stone should be placed
   *   stone: Stone to place
   *
   * Returns:
   *   A new BoardState object, or null if the move was invalid
   */
  public def doMove(idx:Int, stone:Stone):BoardState {

    val p:Pair[Int, Int] = getCoord(idx);
    val row = p.first;
    val col = p.second;

    // Make sure we're not trying to push an emtpy stone
    if (stone == Stone.EMPTY)
      return null;
    
    // Make sure we ARE pushing ONTO an empty stone
    if (this.stoneAt(idx) != Stone.EMPTY)
      return null;

    // Copy the board so we can start modifying
    val newBoard:BoardState = new BoardState(this);

    // Push the stone into place
    newBoard.stones(idx) = stone;
    newBoard.addScore(1, stone);

    // Console.OUT.println("inside doMove, here's the board:");
    // Console.OUT.println(newBoard.print());

    // Update chains
    val newChain = newBoard.makeChain(row, col, stone);

    // Opponent chains adjacent to the new stone will need to
    // be notified of lost liberties
    for (oppChain in newBoard.getChainsAt(getAdjacentIndices(row, col))) {
      for(i in oppChain.getLiberties()) {
        Console.OUT.println("before removing liberties: " + i);
      }
      takeLibertyAndUpdate(oppChain, idx);
      for(i in oppChain.getLiberties()) {
        Console.OUT.println("after removing liberties: " + i);
      }
      if (oppChain.isDead()) {
        Console.OUT.println("killing an opponent chain.");
	newBoard.killChain(oppChain);
      }
    }

    // Validate suicide prevention
    if (newChain.isDead()) {
      return null;
    }

    Console.OUT.println("board at the end of doMove:");
    Console.OUT.println(newBoard.print());

    return newBoard;
  }


  // TODO: remove after testing.
  public def printAllLiberties() {
    for(var idx:Int = 0; idx < this.getSize(); idx++) {
      for (chain in getChainsAt(this.getAdjacentIndices(idx))) {
        for(x in chain.getLiberties()) {
          Console.OUT.println("LIBERTY: " + x);
        }
      }
    }
  }

  /**
   * Returns a HashSet of all the chains that exist in a given set of indices.
   *
   * Args:
   *   indices: Board indices to look for chains on.
   *
   * Returns:
   *   HashSet of unique chains found on all indices.
   */
  private def getChainsAt(indices:HashSet[Int]):HashSet[Chain] {
    val chainSet:HashSet[Chain] = new HashSet[Chain]();
    for (index in indices) {
      if (this.chains(index) != null) {
	chainSet.add(this.chains(index));
      }
    }

    return chainSet;
  }

  /**
   * Makes a chain by adding a stone to the given row/col position,
   * merging and updating other chains as necessary.
   *
   * Args:
   *   row: Row index of the new stone
   *   col: Column index of the stone
   *   stone: Type of stone added.
   *
   * Return:
   *   The created chain
   */
  private def makeChain(row:Int, col:Int, stone:Stone):Chain {
    // Create new chain
    val idx = getIdx(row, col);
    val newChain = new Chain(idx, stone, this);
   
    // Merge with matches
    val adjIndices = getAdjacentIndices(row, col);

    for (adjChain in getChainsAt(adjIndices)) {
      if (adjChain != null && adjChain.getStone() == stone) {
	    mergeAndUpdate(newChain, idx, adjChain);
      }
    }

    this.chains(idx) = newChain;

    // Update chain membership
    for (memberIdx in newChain.getMembers()) {
      this.chains(memberIdx) = newChain;
    }

    return newChain;
  }
  
  /**
   * Removes the stones in a given chain from the board.
   *
   * Args:
   *   toDie: Chain to kill.
   */
  private def killChain(toDie:Chain) {

    for (memberIdx in toDie.getMembers()) {
      this.stones(memberIdx) = Stone.EMPTY;
      this.chains(memberIdx) = null;
    }

    /* Subtract this chain's value from the appropriate score */
    this.addScore(-1*toDie.getSize(), toDie.getStone());

    /* Inform this chain's neighbors of its death */
    for (adjChain in getChainsAt(toDie.getAdjacencies())) {
      addLibertiesAndUpdate(adjChain, toDie.getMembers());
    }
  }

  /**
   * Returns the indices on the board that are adjacent to the given index.
   *
   * Args:
   *   idx: Index of position to check
   *
   * Returns:
   *   A hash set of indeices that are adjacent to the given index
   */
  public def getAdjacentIndices(idx:Int):HashSet[Int] {
    val c = getCoord(idx);
    return getAdjacentIndices(c.first, c.second);
  }

  /**
   * Returns the indices on the board that are adjacent to the given row/col
   * pair
   *
   * Args:
   *   row: Row index of position
   *   col: Column index of position
   *
   * Returns:
   *   A hash set of indeices that are adjacent to the position
   */
  private def getAdjacentIndices(row:Int, col:Int):HashSet[Int] {
    val adjIndices = new HashSet[Int](4);
    
    val cNorth = this.getIdx(row+1, col);
    val cSouth = this.getIdx(row-1, col);
    val cEast = this.getIdx(row, col+1);
    val cWest = this.getIdx(row, col-1);

    if (cNorth != -1) {
      adjIndices.add(cNorth);
    }

    if (cEast != -1) {
      adjIndices.add(cEast);
    }

    if (cSouth != -1) {
      adjIndices.add(cSouth);
    }

    if (cWest != -1) {
      adjIndices.add(cWest);
    }
    
    return adjIndices;
  }


  public def addLibertiesAndUpdate(toUpdate:Chain, indices:HashSet[Int]) {
    val newChain = toUpdate.addLiberties(indices);
    for (member in toUpdate.getMembers()) {
      this.chains(member) = newChain;
    }
  }

  public def takeLibertyAndUpdate(toUpdate:Chain, idx:Int) {
    val newChain = toUpdate.takeLiberty(idx);
    for (member in toUpdate.getMembers()) {
      this.chains(member) = newChain;
    }
  }

  public def mergeAndUpdate(toUpdate:Chain, idx:Int, toMerge:Chain) {
    val newChain = toUpdate.merge(idx, toMerge);
    for (member in toUpdate.getMembers()) {
      this.chains(member) = newChain;
    }    
  }




  /**
   * Returns the board drawn as a string.
   *
   * Returns:
   *   A human-readable string representation of the board.
   */
  public def print():String {
    val sb = new StringBuilder();
    var idx:Int = 0;
    var rowChar:Char = 'a';
    var colNum:Int = 0;
      

    for (var col:Int = 0; col < this.height; col++) {

      // Put the row label
      sb.add(rowChar);
      sb.add('\t');

      // Add the row
      for (var row:Int = 0; row < this.width; row++) {
	sb.add(this.stones(idx).token());

	if (row+1 < width) {
	  sb.add("--");
	}
	idx++;
      }

      sb.add("\n\t");

      // Add the connecting verticals
      if (col+1 < height) {
	for (var row:Int = 0; row < this.width; row++) {
	  sb.add('|');

	  if (row+1 < width) {
	    sb.add("  ");
	  }
	}
      } 

      sb.add('\n');
      rowChar = rowChar + 1;
    }

    /* Add the column numbers */
    sb.add("\n\t");
    for (var row:Int = 0; row < this.width; row++) {
      sb.add(row);
      
      if (row+1 < width) {
	sb.add("  ");
      }
    }

    sb.add("\n");
    sb.add("Score:\n");
    sb.add("-----------\n");
    sb.add("Black: " + this.blackScore + "\n");
    sb.add("White: " + this.whiteScore + "\n");
    
    return sb.result();
  }
}
