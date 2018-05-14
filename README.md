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
  * Some advanced feature (e.g static methods)
  * Operator overloading
  * Exception handling
  * Dynamic require of files
  * Blocks
  * Garbage collection (inherited from Crystal)

## Portability
This language has been developed on a 64 bit Linux Mint. It hasn't been tested on other architectures yiet, 
but for suggestions or contributing, see the 'Contributing' point.

## Status
The project is in pre-alpha stage, it is usable, even though the documentation is being edited, but the core and the API are still under development as well.

Some sintax or some other element might change to best fit the usability, until the language will reach the alpha stage. Then only improvements or API development
will be made.

## To do:
  * [ ] Code cleanup
  * [ ] Unit Test library
  * [ ] Core api documentation
  * [ ] Improving parsing time. Maybe using a Bison-generated parser
  * [ ] Compile time optimizations
  * [ ] Speeding up the VM
  * [ ] Inline caches
  * [ ] Integer optimization (avoiding object allocation for ints)
  * [ ] String API optimization
  * [ ] String interpolation
  * [ ] BigInt conversion from string
  * [ ] Adding a 'break' statement for loops
  * [ ] File IO (The classes are in a primitive status)
  * [ ] Procs and block catching
  * [ ] Adding other useful scientific API
  
## Contributing
Any help or idea is welcome. The project is ambitious and reuires a lot of work. Whoever wants to contribure can open a branch, make some changes and then pull a request. 

To report bugs, or to suggest some feature, open an issue ensuring it does not already exist.

## Author
The developer and designer of this language is Massimiliano Dal Mas

max.codeware@gmail.com
