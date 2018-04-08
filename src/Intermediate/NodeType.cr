
# Copyright (c) 2017-2018 Massimiliano Dal Mas
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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
    PRINTL RAISE TRY CATCH READS NEXT

    # Math const
    # E PI NINF INF

    # Other stuff
    NAMESPACE BODY VOID_NAME ARG_LIST SELF # OPERATOR
    IRANGE ERANGE ARG NULL TRUE FALSE ANS

end
