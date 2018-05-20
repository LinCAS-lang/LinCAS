[![Build Status](https://travis-ci.org/max-codeware/crLinCAS.svg?branch=master)](https://travis-ci.org/max-codeware/crLinCAS)


# LinCAS-lang
## The Linmeric programming language
LinCAS is a dinamically typed and interpreted programming language for quick object-oriented operations and
solving numeric problems in an easy way.

## Why?
The idea is to unify a general purpose language with a computer algebra system, in order to obtain a powerful tool to solve mathematic, engeneering, physical
and other sort of problems.

## Features of LinCAS
  * Easy syntax
  * Ordinary object-oriented features (e.g. classes, method calls...)
  * Some advanced features (e.g static methods)
  * Operator overloading
  * Exception handling
  * Dynamic require of files
  * Blocks
  * Garbage collection (inherited from Crystal)

## Requiremets
  * gcc compiler >= 5.0
  * Crystal compiler version >= 0.24.0

## Portability
This language has been developed on a 64 bit Linux Mint. It hasn't been tested on other architectures yiet, 
but for suggestions or contributing, see the 'Contributing' point.

## Status
The project is in pre-alpha stage, it is usable, even though the documentation is being edited, but the core and the API are still under development as well.

Some sintax or some other element might change to best fit the usability, until the language will reach the alpha stage. Then only improvements or API development
will be made.

## Examples
See [SampleTests](https://github.com/max-codeware/crLinCAS/tree/master/test/SampleTests) for now.

## To do:
  * [ ] Code cleanup
  * [ ] Unit Test library
  * [ ] Core API documentation
  * [ ] Improving parsing time. Maybe using a Bison-generated parser
  * [ ] Compile time optimizations
  * [ ] Speeding up the VM
  * [ ] Inline caches
  * [ ] Integer optimization (avoiding object allocation for ints)
  * [ ] String API optimization
  * [ ] String interpolation & encoding
  * [ ] BigInt conversion from string
  * [ ] Adding a 'break' statement for loops
  * [ ] File IO (The classes are in a primitive status)
  * [x] Symbols
  * [ ] Plot module
  * [ ] Procs and block catching
  * [ ] Adding other useful scientific API
  * [ ] Interactive LinCAS

## Installation
  1. Install gcc-5 or later versions
  2. Install Crystal
  3. Clone the repository with `git clone https://github.com/max-codeware/crLinCAS`
  4. Enter the cloned folder and run `install.sh`

You'll be asked to insert your password. This is to create the `/usr/lib/LinCAS` folder and copy the binaries into `/usr/bin`
  
## Contributing
Any help or idea is welcome. The project is ambitious and requires a lot of work. Whoever wants to contribure can open a branch, make some changes and then pull a request. 

To report bugs, or to suggest some feature, open an issue ensuring it does not already exist.

## Author
The developer and designer of this language is Massimiliano Dal Mas

max.codeware@gmail.com
