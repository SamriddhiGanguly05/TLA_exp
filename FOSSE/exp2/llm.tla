------------------------------ MODULE Rule110 ------------------------------
(***************************************************************************)
(* Abstract model of the Rust Rule-110 cellular automaton.                 *)
(*                                                                         *)
(* The Rust program keeps a circular buffer of rows ("Board") together     *)
(* with a row_offset so that old rows can be discarded (shift_up) while    *)
(* new ones are computed. That is a memory-management optimisation and    *)
(* does not affect which values a cell eventually takes. This spec         *)
(* therefore models the board as a logically unbounded (but, for model    *)
(* checking, finite) grid of rows 0..MaxStep-1 addressed directly by       *)
(* logical row/step number, with no wraparound.                           *)
(*                                                                         *)
(* Each cell starts as "None" (not yet computed). update_cell(step,cell)   *)
(* in Rust computes cells[step][cell] from row step-1, but only if:        *)
(*   - step > 0                                                            *)
(*   - the target cell is still "None"                                    *)
(*   - both cyclic neighbors (left, right) in row step-1 are already      *)
(*     computed (not "None")                                              *)
(* and the update may be attempted for any (step, cell) pair in any       *)
(* order -- this models the caller's freedom to call update_cell for      *)
(* arbitrary rows/cells (e.g. across frames/threads), i.e. the             *)
(* nondeterministic order of cell computation.                            *)
(***************************************************************************)

EXTENDS Naturals

CONSTANTS
    Width,      \* number of columns on the board (board.width)
    MaxStep     \* number of rows modeled (bounds board.height for TLC)

ASSUME Width \in Nat \ {0}
ASSUME MaxStep \in Nat \ {0}

States == {"Zero", "One", "None"}

Cols == 0 .. (Width - 1)
Rows == 0 .. (MaxStep - 1)

VARIABLES
    cells   \* cells[r][c] : the logical state of row r, column c

vars == <<cells>>

(***************************************************************************)
(* Left/right cyclic neighbors, as computed in Rust via                    *)
(*   cell > 0 ? last_row[cell-1] : last_row[width-1]                       *)
(*   cell+1<width ? last_row[cell+1] : last_row[0]                         *)
(***************************************************************************)
LeftOf(row, c)  == IF c > 0 THEN row[c - 1] ELSE row[Width - 1]
RightOf(row, c) == IF c + 1 < Width THEN row[c + 1] ELSE row[0]

(***************************************************************************)
(* Rule 110 transition, exactly mirroring update_cell's new_state logic.   *)
(***************************************************************************)
Rule110(old, left, right) ==
    IF old = "One" /\ left = "One" /\ right = "One" THEN "Zero"
    ELSE IF old = "Zero" /\ right = "One" THEN "One"
    ELSE old

(***************************************************************************)
(* Initial configuration: Board::new -- row 0 is all "Zero" except the     *)
(* last column, which is "One"; every other row is entirely "None".       *)
(***************************************************************************)
Init ==
    cells = [ r \in Rows |->
                [ c \in Cols |->
                    IF r = 0
                        THEN IF c = Width - 1 THEN "One" ELSE "Zero"
                        ELSE "None" ] ]

(***************************************************************************)
(* One successful call to update_cell(step, cell): attempts to fill in     *)
(* cells[step][cell] from row step-1. It only succeeds under the same      *)
(* preconditions as the Rust function; otherwise update_cell returns       *)
(* false and the board is unchanged (modeled simply by that action not     *)
(* being enabled).                                                        *)
(***************************************************************************)
UpdateCell(step, cell) ==
    /\ step \in Rows \ {0}
    /\ cell \in Cols
    /\ cells[step][cell] = "None"                       \* not yet computed
    /\ LET prevRow == cells[step - 1] IN
         /\ LeftOf(prevRow, cell)  # "None"              \* neighbors ready
         /\ RightOf(prevRow, cell) # "None"
         /\ LET old   == prevRow[cell]
                left  == LeftOf(prevRow, cell)
                right == RightOf(prevRow, cell)
                new   == Rule110(old, left, right)
            IN cells' = [cells EXCEPT ![step][cell] = new]

(***************************************************************************)
(* Nondeterministic scheduling: any (step, cell) whose preconditions hold  *)
(* may be updated next -- there is no fixed order across rows or columns.  *)
(***************************************************************************)
Next == \E step \in Rows \ {0}, cell \in Cols : UpdateCell(step, cell)

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------
(* Type correctness *)

TypeOK ==
    cells \in [ Rows -> [ Cols -> States ] ]

(***************************************************************************)
(* Row 0 is fixed by initialization and is never touched by Next (Next     *)
(* only writes rows 1..MaxStep-1).                                         *)
(***************************************************************************)
Row0Invariant ==
    cells[0] = [ c \in Cols |-> IF c = Width - 1 THEN "One" ELSE "Zero" ]

(***************************************************************************)
(* A cell can only be non-"None" if both of its "parent" cells in the      *)
(* previous row were already computed. This restates update_cell's guard  *)
(* as a global invariant, confirming no cell is ever computed "out of      *)
(* order" with respect to its dependencies.                                *)
(***************************************************************************)
DependencyInvariant ==
    \A r \in Rows \ {0}, c \in Cols :
        cells[r][c] # "None" =>
            /\ LeftOf(cells[r - 1], c)  # "None"
            /\ RightOf(cells[r - 1], c) # "None"

(***************************************************************************)
(* Any cell that has been computed indeed carries the Rule 110 value       *)
(* determined by the row below it -- i.e. the computed grid is always a    *)
(* partially-filled, but value-correct, Rule 110 evolution.                *)
(***************************************************************************)
RuleCorrectness ==
    \A r \in Rows \ {0}, c \in Cols :
        cells[r][c] # "None" =>
            cells[r][c] = Rule110(cells[r - 1][c],
                                   LeftOf(cells[r - 1], c),
                                   RightOf(cells[r - 1], c))

=============================================================================
