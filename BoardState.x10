import x10.util.StringBuilder;
import x10.util.HashSet;
import x10.util.Pair;
import x10.util.ArrayList;
import x10.util.Stack;

public class BoardState {

  private val HASH_NUM_WIDTH:Int = 20;
  private val HASH_NUM_BASE:Int = 3;
  private val MAX_BOARD_SIZE:Int = 400;

  private val height:Int;
  private val width:Int;
  
  private val hashNums:Array[Int];

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
    val numSpaces:Int = height*width;

    if (numSpaces > MAX_BOARD_SIZE) {
      throw new RuntimeException("Board sizes with > " + MAX_BOARD_SIZE + 
				 " intersections are unsupported.");
    }

    this.stones = new Array[Stone](numSpaces, Stone.EMPTY);
    this.chains = new Array[Chain](numSpaces);

    this.whiteScore = 0;
    this.blackScore = 0;

    val numHashNums:Int = Math.ceil((numSpaces as Double)/HASH_NUM_WIDTH) as Int;
    this.hashNums = new Array[Int](numHashNums, 0);
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

    this.hashNums = new Array[Int](toCopy.hashNums);
  }

  // assumes equal height and width
  public def equals(toTest:BoardState) {
    if (toTest.getSize() != this.getSize()) {
      return Boolean.FALSE;
    }

    for(var i:Int = 0; i < hashNums.size; i++) {
      if(toTest.hashNums(i) != this.hashNums(i)) {
        return Boolean.FALSE;
      }
    }
    return Boolean.TRUE;
  }

  /*
  public def equals(toTest:BoardState) {
    for(var i:Int = 0; i < getSize(); i++) {
      if(toTest.stones(i) != this.stones(i)) {
        return Boolean.FALSE;
      }
    }
    return Boolean.TRUE;
  }*/

  public def hashCode() {
    var hash:Int = 0;
    for(var i:Int = 0; i < hashNums.size; i++) {
      hash+=hashNums(i);
    }
    return hash;
  }
  /*
  public def hashCode() {
    var str:String = "";
    for(s in this.stones.region) {
      str = str + stones(s).repr();
    }

    return str.hashCode();
  }*/

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


  /*
   * Returns:
   * Board Height
   */

  public def getHeight():Int {
    return this.height;
  }

  /*
   * Returns:
   * Board Width
   */

  public def getWidth():Int {
    return this.width;
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

  public def listOfEmptyIdxs():ArrayList[Int] {
    val spots:ArrayList[Int] = new ArrayList[Int]();
    for (var idx:Int = 0; idx < this.stones.size; idx++) {
      if (Stone.canPlaceOn(this.stones(idx)))
	spots.add(idx);
    }
    return spots;
  }

  public def countStones(s:Stone) {
    var count:Int = 0;
    for (var idx:Int = 0; idx < this.stones.size; idx++) {
      if (this.stones(idx) == s)
	count++;
    }
    return count;
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
    if (this.blackScore > this.whiteScore) {
      return Stone.BLACK;
    }
    
    else if (this.blackScore < this.whiteScore) {
      return Stone.WHITE;
    }

    else {
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
    return (Stone.canPlaceOn(this.stoneAt(idx)));
  }

  public def addPiece(idx:Int, newPiece:Stone) {
    if (Stone.canPlaceOn(newPiece)) {
      throw new RuntimeException("Tried to add an empty-type stone.");
    }
    if (!Stone.canPlaceOn(this.stoneAt(idx))) {
      throw new RuntimeException("Tried to add on top of non-empty-type " +
				 "stone.");
    }

    val hashNumIdx = idx/HASH_NUM_WIDTH;
    val hashNumOffset = idx%HASH_NUM_WIDTH;

    val pieceValue:Int;
    if (newPiece == Stone.BLACK)
      pieceValue = 1;
    else
      pieceValue = 2;

    this.hashNums(hashNumIdx) = (this.hashNums(hashNumIdx) + 
				 pieceValue * 
				 (Math.pow(HASH_NUM_BASE, 
					   hashNumOffset) as Int));
    this.stones(idx) = newPiece;
  }

  public def removePiece(idx:Int, newPiece:Stone) {
    if (!Stone.canPlaceOn(newPiece)) {
      throw new RuntimeException("Tried to remove with non-empty-type stone.");
    }
    if (Stone.canPlaceOn(this.stoneAt(idx))) {
      throw new RuntimeException("Tried to remove empty-type stone");
    }
    
    val hashNumIdx = idx/HASH_NUM_WIDTH;
    val hashNumOffset = idx%HASH_NUM_WIDTH;

    val oldPiece = this.stoneAt(idx);
    val pieceValue:Int;
    if (oldPiece == Stone.BLACK)
      pieceValue = 1;
    else
      pieceValue = 2;

    this.hashNums(hashNumIdx) = (this.hashNums(hashNumIdx) - 
				 pieceValue *
				 (Math.pow(HASH_NUM_BASE, 
					   hashNumOffset) as Int));
    this.stones(idx) = newPiece;
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
    val oldStone:Stone = this.stoneAt(idx);
    //Console.OUT.println("canPlaceOn is " + Stone.canPlaceOn(oldStone));
    if (!Stone.canPlaceOn(oldStone))
      return null;

    // Copy the board so we can start modifying
    val newBoard:BoardState = new BoardState(this);

    // Push the stone into place
    newBoard.addPiece(idx, stone);

    // Update chains
    var newChain:Chain = newBoard.makeChain(row, col, stone);

    // Opponent chains adjacent to the new stone will need to
    // be notified of lost liberties
    var capturePoints:Int = 0;
    for (oppChain in newBoard.getChainsAt(getAdjacentIndices(row, col))) {
      capturePoints += newBoard.takeLibertyAndUpdate(oppChain, idx);
    }

    newChain = newBoard.chains(idx);
    // Validate suicide prevention
    if (newChain == null || newChain.isDead()) {
      //Console.OUT.println("Failed because of suicide rule");
      return null;
    }

    // Compute changes to territory and score

    // If we placed in our territory then there's no need to recompute territory
    // even score stayes the same because we trade territory for a piece
    if (oldStone == Stone.getTerritoryOf(stone)) {
      // do nothing
    }

    // If we placed in the opponent's territory, the opponent loses that
    // territory block
    else if (oldStone == Stone.getTerritoryOf(Stone.getOpponentOf(stone))) {
      //Console.OUT.println("Starting fill on opponent territory");
      val stonesFilled:Int = newBoard.doFill(row, col, oldStone, Stone.EMPTY);
      newBoard.addScore(-1*stonesFilled, Stone.getOpponentOf(stone));
      newBoard.addScore(-1, Stone.getOpponentOf(stone));
      newBoard.addScore(1, stone);
    }

    // If we placed on an empty space, we should check to see if it buys us any
    // new territory
    else if (oldStone == Stone.EMPTY) {
      //Console.OUT.println("Starting fill on empty");
      val stonesFilled:Int = newBoard.doFill(row, col, Stone.EMPTY,
					     Stone.getTerritoryOf(stone));
      newBoard.addScore(stonesFilled, stone);
      newBoard.addScore(1, stone);
    }

    // Account for capture points
    newBoard.addScore(capturePoints, stone);
    newBoard.addScore(-1*capturePoints, Stone.getOpponentOf(stone));
    return newBoard;
  }

  /**
   * Attempts to do a territory fill at (row, col). If a boundary stone is found
   * that indicates the fill is unwarranted, no change occurs.
   * 
   * Args:
   *   row: Row at which the fill is centered
   *   col: Column at which the fill is centered
   *   oldStone: Stone type of contiguous region that is being filled
   *   newStone: Stone type to which the region should be filled
   * Returns:
   *   The number of stones modified.
   */
  private def doFill(row:Int, col:Int, oldStone:Stone, newStone:Stone):Int {
    val expectedBound:Stone = Stone.getPieceOf(newStone);
    var numModified:Int = 0;

    //Console.OUT.println("Starting doFill");

    // Check bounds and gather indices
    val examined:HashSet[Int] = new HashSet[Int]();
    for (startIdx in getAdjacentIndices(row, col)) {
      if (!examined.contains(startIdx)) {
	val inFill:HashSet[Int] = this.fillSearch(startIdx, oldStone,
						  expectedBound, examined);
	if (inFill != null) {
	  for (fillMemberIdx in inFill) {
	    this.stones(fillMemberIdx) = newStone;
	    numModified++;
	  }
	}
      }
    }

    return numModified;
  }


  private def fillSearch(startIdx:Int, oldStone:Stone, expectedBound:Stone,
			 examined:HashSet[Int]):HashSet[Int] {
    val fringe:Stack[Int] = new Stack[Int]();
    val inFill:HashSet[Int] = new HashSet[Int]();

    examined.add(startIdx);
    if (this.stones(startIdx) != oldStone)
      return null;
    
    // Fill search
    fringe.push(startIdx);
    while(!fringe.isEmpty()) {
      var toExpand:Int = fringe.pop();
      for(adj in this.getAdjacentIndices(toExpand)) {

	// If adjacent stone is part of fill region
	if (this.stones(adj) == oldStone) {
	  if (!inFill.contains(adj)) {
	    fringe.push(adj);
	  }
	}
	    
	// If adjacent stone is an unexpected boundary piece
	else if (expectedBound != Stone.INVALID && 
		 this.stones(adj) != expectedBound) {
		   
	  return null;
	}
      }
      inFill.add(toExpand);
      examined.add(toExpand);
    }

    return inFill;
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
    var newChain:Chain = new Chain(idx, stone, this);
    this.chains(idx) = newChain;   

    // Merge with adjacent chains
    val adjIndices = getAdjacentIndices(row, col);
    for (adjChain in getChainsAt(adjIndices)) {
      if (adjChain != null && adjChain.getStone() == stone) {
	    mergeAndUpdate(this.chains(idx), idx, adjChain);
      }
    }

    newChain = this.chains(idx);

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
  private def killChain(toDie:Chain):Int {

    for (memberIdx in toDie.getMembers()) {
      // Captured stones become opponent territory
      this.removePiece(memberIdx, 
		       Stone.getTerritoryOf(Stone.getOpponentOf(toDie.getStone())));
      this.chains(memberIdx) = null;
    }

    /* Inform this chain's neighbors of its death */
    for (adjChain in getChainsAt(toDie.getAdjacencies())) {
      addLibertiesAndUpdate(adjChain, toDie.getMembers());
    }

    return toDie.getSize();
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
    for (member in newChain.getMembers()) {
      this.chains(member) = newChain;
    }
  }

  public def takeLibertyAndUpdate(toUpdate:Chain, idx:Int) {
    val newChain = toUpdate.takeLiberty(idx);
    var spacesCaptured:Int = 0;

    if (newChain.isDead()) {
      spacesCaptured = this.killChain(newChain);
    }
    else {
      for (member in newChain.getMembers()) {
	this.chains(member) = newChain;
      }
    }

    return spacesCaptured;
  }

  public def mergeAndUpdate(toUpdate:Chain, idx:Int, toMerge:Chain) {
    val newChain = toUpdate.merge(idx, toMerge);
    for (member in newChain.getMembers()) {
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
