
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

@[Link(ldflags: "#{__DIR__}/LibC/libc.o")]
lib LibC
    # struct JmpBuf
    #     __rbx : ULong
    #     __rsp : ULong
    #     __rbp : ULong
    #     __r12 : ULong
    #     __r13 : ULong
    #     __r14 : ULong
    #     __r15 : ULong
    #     __rip : ULong    
    # end

    {%if flag?(:x86_64)%}
      JBLEN = (9 * 2) + 3 + 16
    {%elsif flag?(:i386)%}
      JBLEN = 18
    {%elsif flag?(:arm)%}
      JBLEN (10 + 16 + 2)
    {%elsif flag?(:arm64)%}
      JBLEN = (14 + 8 + 2) * 2
    {%end%}
    alias JmpBuf = Int[JBLEN]

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

    fun setjmp(buf : Int*) : Int
    fun longjmp(buf : Int*, rval : Int)
end
