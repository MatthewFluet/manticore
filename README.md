# Manticore

[Manticore](http://manticore.cs.uchicago.edu) is a high-level parallel programming language aimed at general-purpose applications running on multi-core processors. Manticore supports parallelism at multiple levels: explicit concurrency and coarse-grain parallelism via CML-style constructs and fine-grain parallelism via various light-weight notations, such as parallel tuple expressions and NESL/Nepal-style parallel array comprehensions.

## REQUIREMENTS


Manticore currently only supports the x86-64 (a.k.a. AMD64)
architecture running on either Linux or Mac OS X. It is possible to
build the compiler on other systems (see below), but we have not
ported the runtime or code generator to them yet.

Manticore is implemented in a mix of C and SML code.  You will need a
recent version of SML/NJ (version 110.68+) installed.  Furthermore,
your installation of SML/NJ should include the MLRISC library. 

## BUILDING FROM SOURCE

If building and installing the system from source, you first must 
generate the configuration script.  To do so, run the following two commands:

	autoheader -Iconfig
	autoconf -Iconfig
    
Then proceed with configuration.

### Configuring

Our next step is to run the configure script. If you are using the MLRISC
library *included* with your SML/NJ installation and do *not* plan to use the
LLVM backend, you can simply run

	./configure

and skip to the build/installation step.

#### Configuring with external MLRISC

If you would like to configure with external MLRISC libraries, run the following instead.

	./configure --with-mlrisc=<path to mlrisc>

#### Configuring with LLVM

You must have a custom version of LLVM installed in order to have the LLVM
backend available in your installation. The following commands will obtain
LLVM and place it in `./llvm/src`

    git submodule init
    git submodule update
    
Next, we're going to build LLVM. TODO put steps here.

Then proceed with the installation instructions below


### Building and Installing the Distribution


To build the compiler, we use the following command.

    make build

We can install locally

    make local-install

or globally.

    make install

### Testing

Details about running the regression suite goes here.


Known large issues
-
- The frontend does not support signatures, functors, record types, and a slew of
corner cases in the language.

- PVal and PTuples cannot be used together. The "fast clone" translation breaks
invariants relied on by the work-stealing scheduler with regards to the valid
intermediate states of the work queues.

- Exception handling is not implemented.

- The inatomic/from-atomic/to-atomic naming convention used in inline BOM is still
a bugfest and should really be replaced by a static annotation that is checked
by the compiler.

- The basis library is a hodgepodge mess. The few structures that exist are
typically dramatically different from the SML basis library due to the subset of
the language implemented, which both makes existing code from another system
hard to reuse and sometimes the interface cannot even be written.

Known smaller issues
-

- The effect analysis defined in bom-opt/remove-atomics.sml should be changed from
being name-based to instead either have a trackable annotation or other better
marker for user-level code that uses mutable state. Additionally, while we
remove ATOMIC operations around PURE functions, we do not handle reducing them
in the case where the code between the parallel spawn and another lock is PURE.

- We cannot handle allocations larger than a single heap page size (minus some
slop). These allocations result in an exception, which is tough to debug because
there is no exception handling.

- The work-stealing scheduler cannot handle more than a stack of 32k tasks, and
crashes quietly when that is exceeded.

- Memoization and mutable state exist only as hand-performed translations to call
basis library functions.

Incomplete projects
-

- The safe-for-space closure conversion was not completed. While its code may be
used for inspiration, we were not able to get a full write-up on its status
before the student graduated.

- In CFG, we now have code that performs rudimentary loop identification and can
also generate a DOT file for visualization of basic blocks. Loop unrolling was
not implemented.

- A branch was created for the BOM implementation of flattening, but it is still
in the design phase.
