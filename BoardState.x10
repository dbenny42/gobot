import x10.util.StringBuilder;

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

  public def stoneAt(row:Int, col:Int):Stone {
    val idx = getIdx(row, col);
    if (idx != -1)
      return this.stones(idx);
    else
      return null;
  }

  public def hasIdx(idx:Int):Boolean {
    return idx > this.stones.size;
  }

  private def getIdx(row:Int, col:Int):Boolean {
    if (row < this.height && col < this.width)
      return -1;
    else
      return row*this.width + col
  }

  public def getCoord(idx:Int):Pair[Int, Int] {
    val row = idx / this.width;
    val col = idx - (row * this.width);
    return new Pair(row, col);
  }

  private def hasCoord(row:Int, col:Int):Boolean {
    return (this.getCoordIdx(row, col) == -1);
  }

  public def isEmptyAt(row:Int, col:Int):Boolean {
    return (this.stoneAt(row, col) == Stones.EMPTY);
  }

  public def doMove(idx:Int, stone:Stone):Boolean {

    val Pair[Int, Int] p = getCoord(idx);
    val row = p.first;
    val col = p.second;

    // Make sure we're not trying to push an emtpy stone
    if (stone == Stone.EMPTY)
      return null;
    
    // Make sure we ARE pushing ONTO an empty stone
    if (!this.isEmptyAt(row, col))
      return null;

    // Validate suicide prohibition
    val newChain = makeChain(row, col, stone);
    if (newChain.isDead()) {
      return null;
    }

    // Push the stone into place
    this.stones(idx) = stone;
    this.chains(idx) = chain;

    // Update chain membership
    for (memberIdx in newChain.getMembers()) {
      this.chains(memberIdx) = newChain;
    }

    // Opponent chains adjacent to the new stone will need to
    // be notified of lost liberties
    for (oppChain in getChainsAt(getAdjacentIndices(row, col)) {
      oppChain.takeLiberty(row, col);
      if oppChain.isDead() {
	killChain(oppChain);
      }
    }
  }

  // TODO: Implement getChainsAt
  // TODO: Implement makeChain
  // TODO: Finish getAdjacentIndices

  private def makeChain(row:Int, col:Int, stone:Stone):Boolean {
    // Create new chain
    // Look for matches on all sides
    // Merge with matches
  }
  

  private def killChain(toDie:Chain) {
    for (memberIdx in toDie.getMembers()) {
      this.stones(memberIdx) = Stone.EMPTY;
      this.chains(memberIdx) = null;
    }

    for (adjChain in getChainsAt(toDie.getAdjacencies())) {
      adjChain.addLiberties(toDie.getMembers());
      // addLiberties should know not to add nonadjacent spaces
    }
  }
  
  private def getAdjacentIndices(row:Int, col:Int):Array[Int] {
    val adjIndices = new Array[Int](4);
    var numAdjacencies:Int = 0;
    
    val cNorth = this.getCoord(row+1, col);
    val cSouth = this.getCoord(row-1, col);
    val cEast = this.getCoord(row, col+1);
    val cWest = this.getCoord(row, col-1);

    if (cNorth != -1) {
      adjIndices(numAdjacencies) = cNorth;
      numAdjacencies++;
    }

    if (cEast != -1) {
      adjIndices(numAdjacencies) = cEast;
      numAdjacencies++;
    }

    if (cSouth != -1) {
      adjIndices(numAdjacencies) = cSouth;
      numAdjacencies++;
    }

    if (cWest != -1) {
      adjIndices(numAdjacencies) = cWest;
      numAdjacencies++;
    }


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
