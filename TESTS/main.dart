
import 'matrix_generator.dart';
import 'matrix_puzzle.dart';

void main(){
  MatrixPuzzle puzzle = MatrixGenerator.generate();
  puzzle.consolePrint();
}