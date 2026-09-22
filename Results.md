# Code2Spec Results

## Experiment 1: Blocking Queue

### Source
- **Implementation:** Java
- **System:** Bounded concurrent BlockingQueue
- **Reference:** TLA+ BlockingQueue specification from the TLA+ learning materials

### LLM-Generated Specification

The LLM-generated specification successfully captured the main behavioral concepts of the Java implementation:

- Multiple producers and consumers
- Bounded buffer
- `put()` and `take()` operations
- Blocking when the buffer is full or empty
- Waiting threads
- Nondeterministic scheduling
- Notification behavior

The generated specification also introduced additional abstractions that were not present in the reference specification:

- `pc` state variable for thread states
- `ready`, `waiting`, and `notified` states
- `UseNotifyAll` configuration parameter

### Manual Comparison

| Property | Result |
|---|---|
| Producers | Match |
| Consumers | Match |
| Bounded buffer | Match |
| Put operation | Match |
| Take operation | Match |
| Full-buffer blocking | Match |
| Empty-buffer blocking | Match |
| Waiting threads | Match |
| Nondeterministic scheduling | Match |
| Initial state | Match |
| Notification | Partial match |
| Thread-state representation | Different |
| Core queue behavior | Strong correspondence |

### TLC Result

The generated model was tested with the following configuration:

    Producers = {p1, p2}
    Consumers = {c1}
    BufCapacity = 1
    UseNotifyAll = FALSE

TLC generated **88 states**, of which **43 were distinct**, with a maximum depth of **9**.

The generated specification violated the `NoDeadlock` invariant. The counterexample showed a state in which all producer and consumer threads became blocked.

The observed execution was:

    1. p1 puts an element into the empty buffer.
    2. p1 waits because the buffer becomes full.
    3. p2 also waits.
    4. c1 takes the element, emptying the buffer.
    5. p1 is notified.
    6. c1 waits because the buffer is empty.
    7. p1 puts an element into the buffer.
    8. p1 waits because the buffer becomes full.
    9. p2 waits, resulting in all threads being blocked.

This indicates that the generated model's notification and scheduling abstraction can lead to a deadlock state under the tested configuration.

### Result

The generated specification shows strong correspondence with the core behavior of the Java BlockingQueue. However, the notification mechanism and additional thread-state abstraction introduce behavioral differences. The TLC counterexample also demonstrates that the generated model does not completely preserve the intended concurrency behavior of the reference system.

---

## Experiment 2: Rule 110

### Source
- **Implementation:** Rust
- **System:** Rule 110 cellular automaton
- **Reference:** TLA+ Rule 110 specification from the `gterzian/automata` repository

### LLM-Generated Specification

The LLM-generated specification successfully captured the main behavioral concepts of the Rust implementation:

- One-dimensional cellular automaton
- Binary cell states (`Zero`, `One`) with an uninitialized (`None`) state
- Configurable width and number of steps
- Initial row containing zeros with the rightmost cell set to one
- Cyclic left and right neighbors
- Rule 110 transition logic
- Partial computation where cells can be updated independently
- Dependency on the previous row
- Nondeterministic update order

### Manual Comparison

| Property | Result |
|---|---|
| Cell states | Match |
| Initial configuration | Match |
| Configurable system size | Match |
| Cyclic boundary conditions | Match |
| Left-neighbor handling | Match |
| Right-neighbor handling | Match |
| Previous-row dependency | Match |
| Rule 110 transition | Match |
| Partial cell updates | Match |
| Nondeterministic update order | Match |
| State representation | Different |
| Indexing convention | Different |
| Main computation behavior | Strong correspondence |

### Main Differences

The generated specification and reference specification use different abstractions:

- The reference uses `N` for both the number of cells and the number of steps, while the generated specification uses separate `Width` and `MaxStep` parameters.
- The reference uses 1-based indexing, while the generated specification uses 0-based indexing.
- The generated specification represents cell states using strings (`"Zero"`, `"One"`, `"None"`), while the reference uses numeric values.
- The reference contains additional definitions such as `Done`, `CurrentStepBar`, `StepsBar`, and `BarSpec`, which were not reproduced by the generated specification.
- The generated specification introduces explicit invariants such as `DependencyInvariant` and `RuleCorrectness`.

### Result

The generated specification shows strong correspondence with the core computational behavior of the Rust implementation and the reference TLA+ specification. The main differences are in representation, parameterization, and auxiliary specification structure rather than the central Rule 110 transition behavior.

---

## Conclusion

The two experiments show that an LLM can generate TLA+ specifications that capture several important behavioral properties of real implementations.

For the **Blocking Queue**, the generated specification captured the core producer-consumer and bounded-buffer behavior, but differences in notification and thread-state modeling resulted in a deadlock counterexample during TLC checking.

For **Rule 110**, the generated specification showed strong correspondence with the core cellular automaton behavior, including initialization, cyclic boundaries, state transitions, and partial update semantics. The differences were mainly related to representation, indexing, parameterization, and auxiliary specification structure.

Overall, the experiments indicate that LLM-generated TLA+ specifications can provide a useful starting point for formalizing real code, but automated verification and comparison against reference specifications are necessary to identify behavioral mismatches and abstraction errors.
