My learn-by-doing attempt to get into Zig by creating a hexdump utility.;
STD library only.
Many thanks to ziglings project.

Milestones:
- [] Implement basic functions;
  - [x] Basic hexdump formatter;
  - [x] Read command line params;
  - [x] Handle errors when suppiled params are missing/broken;
  - [] Read data directly from stdin;
- [] Going deeper;
  - [] Learn zig build system;
    - [] Note: for now this seems pretty straingtforward so I will try to move some function to external zig file and then import it back to the original code (Most likely I will try to implement my own args reading and parsing module);
  - [] Coloured output;
- [] Final steps;
  - [] Support for both -p val amd -p=val command line param formats;
  - [] Code revision, maybe I will know how to redo already implemented stuff in a better way by that moment;
    - [] Add comptime where it is possible;
