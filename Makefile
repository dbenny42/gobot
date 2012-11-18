Go: Go.x10 MCTNode.x10 BoardState.x10 Stone.x10 Chain.x10
	${X10_HOME}/bin/x10c++ Go.x10 -o Go

BoardTest: BoardTest.x10 Chain.x10 BoardState.x10 Stone.x10
	${X10_HOME}/bin/x10c++ BoardTest.x10 -o BoardTest

Play: Go
	./Go 7 7 1

Test: BoardTest
	./BoardTest 7 7

.PHONY: clean

clean: 
	rm -f *.cc *.h *.class *.java *.out *~ Go BoardTest