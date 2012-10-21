import x10.util.StringBuilder;
import x10.util.HashSet;
import x10.util.Pair;

public class BoardState {

  private val height:Int;
  private val width:Int;
  private val stones:Array[Stone];
  private val chains:Array[Chain];

  public def this(height:Int, width:Int) {
    this.height = height;
    this.width = width;
    this.stones = new Array[Stone](height*width, Stone.EMPTY);
    this.chains = new Array[Chain](height*width);
  }

  public def this(to_copy:BoardState) {
    this.height = to_copy.height;
    this.width = to_copy.width;
    this.stones = new Array[Stone](to_copy.stones);
    this.chains = new Array[Chain](to_copy.chains);
  }

  public def stoneAt(idx:Int):Stone {
    return this.stones(idx);
  }

  public def hasIdx(idx:Int):Boolean {
    return idx > this.stones.size;
  }

  private def getIdx(row:Int, col:Int):Int {
    if (row >= this.height || col >= this.width)
      return -1;
    else if (row < 0 || col < 0)
      return -1;
    else
      return row*this.width + col;
  }

  public def getCoord(idx:Int):Pair[Int, Int] {
    val row = idx / this.width;
    val col = idx - (row * this.width);
    return new Pair[Int, Int](row, col);
  }

  private def hasCoord(row:Int, col:Int):Boolean {
    return (this.getIdx(row, col) == -1);
  }

  public def isEmptyAt(idx:Int):Boolean {
    return (this.stoneAt(idx) == Stone.EMPTY);
  }

  public def doMove(row:Int, col:Int, stone:Stone):BoardState {
    val idx = getIdx(row, col);
    return doMove(idx, stone);
  }

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

    // Update chains and validate suicide prohibition
    val newChain = newBoard.makeChain(row, col, stone);
    if (newChain.isDead()) {
      return null;
    }

    // Opponent chains adjacent to the new stone will need to
    // be notified of lost liberties
    for (oppChain in newBoard.getChainsAt(getAdjacentIndices(row, col))) {
      oppChain.takeLiberty(idx);
      if (oppChain.isDead()) {
	newBoard.killChain(oppChain);
      }
    }

    return newBoard;
  }

  private def getChainsAt(indices:HashSet[Int]) {
    val chainSet:HashSet[Chain] = new HashSet[Chain]();
    for (index in indices) {
      if (this.chains(index) != null) {
	chainSet.add(this.chains(index));
      }
    }

    return chainSet;
  }

  private def makeChain(row:Int, col:Int, stone:Stone):Chain {
    // Create new chain
    val idx = getIdx(row, col);
    val newChain = new Chain(idx, stone, this);
   
    // Merge with matches
    val adjIndices = getAdjacentIndices(row, col);

    for (adjChain in getChainsAt(adjIndices)) {
      if (adjChain != null && adjChain.getStone() == stone) {
	    newChain.merge(idx, adjChain);
      }
    }

    this.chains(idx) = newChain;

    // Update chain membership
    for (memberIdx in newChain.getMembers()) {
      this.chains(memberIdx) = newChain;
    }

    return newChain;
  }
  
  private def killChain(toDie:Chain) {
    for (memberIdx in toDie.getMembers()) {
      this.stones(memberIdx) = Stone.EMPTY;
      this.chains(memberIdx) = null;
    }

    for (adjChain in getChainsAt(toDie.getAdjacencies())) {
      adjChain.addLiberties(toDie.getMembers());
    }
  }

  public def getAdjacentIndices(idx:Int):HashSet[Int] {
    val c = getCoord(idx);
    return getAdjacentIndices(c.first, c.second);
  }

  
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
      } else { // Add the column numbers
	sb.add("\n\t");
	for (var row:Int = 0; row < this.width; row++) {
	  sb.add(row);

	  if (row+1 < width) {
	    sb.add("  ");
	  }
	}
      }

      sb.add('\n');
      rowChar = rowChar + 1;
    }
    return sb.result();
  }
}
