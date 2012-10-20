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

  public def print() {
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
