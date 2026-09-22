------------------------------ MODULE BlockingQueue ------------------------------
(***************************************************************************)
(* Bounded buffer guarded by a Java monitor (synchronized / wait / notify) *)
(* shared by several producer and several consumer threads.               *)
(*                                                                         *)
(* Because every access to the buffer happens inside a synchronized        *)
(* method, the critical section of put()/take() is modeled as one atomic  *)
(* step. The only interleaving points are those where a thread (re)enters *)
(* the monitor, so that is where the model lets threads interleave.       *)
(***************************************************************************)
EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS
    Producers,      \* set of producer thread ids
    Consumers,      \* set of consumer thread ids
    BufCapacity,    \* capacity k of the queue
    UseNotifyAll    \* FALSE = the original notify() (buggy); TRUE = notifyAll() (fix)

ASSUME /\ Producers # {} /\ Consumers # {}
       /\ Producers \cap Consumers = {}
       /\ BufCapacity \in Nat \ {0}
       /\ UseNotifyAll \in BOOLEAN

Threads == Producers \cup Consumers

VARIABLES
    buffer,     \* sequence of items currently in the queue (head = first element)
    waitSet,    \* set of threads blocked in Object.wait() on the queue's monitor
    pc          \* pc[t] \in {"ready", "waiting", "notified"}

vars == <<buffer, waitSet, pc>>

(***************************************************************************)
(* pc values:                                                              *)
(*  "ready"    - outside the monitor; about to call put()/take() (this     *)
(*               also abstracts printing and Thread.sleep()).              *)
(*  "waiting"  - inside wait(), member of waitSet.                         *)
(*  "notified" - removed from waitSet by notify(); not yet holding the     *)
(*               monitor again. Once it wins the monitor it re-evaluates   *)
(*               the while-condition (isFull / isEmpty).                   *)
(***************************************************************************)

TypeOK ==
    /\ buffer \in Seq(Producers)
    /\ Len(buffer) <= BufCapacity
    /\ waitSet \subseteq Threads
    /\ pc \in [Threads -> {"ready", "waiting", "notified"}]
    /\ waitSet = {t \in Threads : pc[t] = "waiting"}

Init ==
    /\ buffer  = <<>>
    /\ waitSet = {}
    /\ pc      = [t \in Threads |-> "ready"]

(***************************************************************************)
(* notify(): wakes ONE arbitrary thread of the wait set (or nobody if the  *)
(* set is empty), with no regard for whether it is a producer or consumer. *)
(* notifyAll(): wakes all of them.                                         *)
(***************************************************************************)
WakeChoices ==
    IF UseNotifyAll THEN {waitSet}
    ELSE IF waitSet = {} THEN {{}}
    ELSE {{w} : w \in waitSet}

\* Thread t executes wait(): release the monitor and join the wait set.
BlockOnWait(t) ==
    /\ waitSet' = waitSet \cup {t}
    /\ pc'      = [pc EXCEPT ![t] = "waiting"]

\* Thread t passes its while-check, calls notify(), updates the buffer,
\* leaves the synchronized method and goes back to "ready".
NotifyAndLeave(t, newBuffer) ==
    /\ \E W \in WakeChoices :
         /\ waitSet' = waitSet \ W
         /\ pc' = [u \in Threads |->
                      IF u = t THEN "ready"
                      ELSE IF u \in W THEN "notified"
                      ELSE pc[u]]
    /\ buffer' = newBuffer

CanEnter(t) == pc[t] \in {"ready", "notified"}   \* t may acquire the monitor

(* BlockingQueue.put(): while (isFull()) wait(); notify(); append(e); *)
Put(p) ==
    /\ CanEnter(p)
    /\ IF Len(buffer) = BufCapacity
         THEN /\ BlockOnWait(p)
              /\ UNCHANGED buffer
         ELSE NotifyAndLeave(p, Append(buffer, p))

(* BlockingQueue.take(): while (isEmpty()) wait(); notify(); return head(); *)
Take(c) ==
    /\ CanEnter(c)
    /\ IF buffer = <<>>
         THEN /\ BlockOnWait(c)
              /\ UNCHANGED buffer
         ELSE NotifyAndLeave(c, Tail(buffer))

(* Nondeterministic scheduling: any thread that can enter the monitor may  *)
(* be the next one to do so.                                               *)
Next == \/ \E p \in Producers : Put(p)
        \/ \E c \in Consumers : Take(c)

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------
(* Properties *)

BufferBounded == Len(buffer) <= BufCapacity

\* Deadlock: every thread is parked in wait(); nobody is left to notify.
\* (A thread in "ready"/"notified" always has an enabled step, so Next is
\* disabled exactly when all threads are waiting.)
NoDeadlock == waitSet # Threads

=============================================================================