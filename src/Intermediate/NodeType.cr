# Copyright (c) 2017 Massimiliano Dal Mas
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

enum LinCAS::NodeType
    # Operands
    STRING INT FLOAT LOCAL_ID GLOBAL_ID SYMBOLIC MATRIX
    ARRAY ARRAY_LIST

    # Operations
    SUM SUB MUL FDIV IDIV MOD POWER AND OR NOT APPEND INVERT

    # Comparisons
    GR SM GE SE EQ NE

    # Statements
    IF SELECT VOID CLASS MODULE WHILE UNTIL FOR BLOCK
    REQUIRE INCLUDE ASSIGN NOOP CALL METHOD_CALL OPT_SET
    PROGRAM NEW CASE ELSE CONST USE RETURN YIELD PRINT
    PRINTL RAISE TRY CATCH READS

    # Math const
    E PI NINF INF

    # Other stuff
    NAMESPACE BODY VOID_NAME ARG_LIST SELF # OPERATOR
    IRANGE ERANGE ARG NULL TRUE FALSE

end