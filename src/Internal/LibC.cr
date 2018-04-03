
# Copyright (c) 2017-2018 Massimiliano Dal Mas
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

@[Link(ldflags: "#{__DIR__}/LibC/libc.a")]
lib LibC
    fun strstr(str1 : Char*, str2 : Char*) : Char*
    fun printf(format : Char*, ... ) : Int 
    fun toupper(str : Char*) : Char*
    fun strlwr(str : Char*) : Char*
    fun strlen(str : Char*) : SizeT
    fun strtok(str : Char*, delimiter : Char*) : Char*
    fun strtol(str : Char*, endptr : Char*, base : Int) : Int
    fun strtod(str : Char*, endptr : Char**) : Double
    fun strcmp(str1 : Char*, str2 : Char*) : Int

    fun add_overflow_i(n1 : Int, n2 : Int, var : Int*) : Int
    fun add_overflow_l(n1 : Int64, n2 : Int64, var : Int64*) : Int
    fun sub_overflow_i(n1 : Int, n2 : Int, var : Int*) : Int
    fun sub_overflow_l(n1 : Int64, n2 : Int64, var : Int64*) : Int
    fun mul_overflow_i(n1 : Int, n2 : Int, var : Int*) : Int
    fun mul_overflow_l(n1 : Int64, n2 : Int64, var : Int64*) : Int
end