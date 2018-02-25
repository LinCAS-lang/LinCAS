
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

module LinCAS
    alias Value = Internal::Value
    alias T1 = Tuple(Value)
    alias T2 = Tuple(Value,Value)
    alias T3 = Tuple(Value,Value,Value)
    alias T4 = Tuple(Value,Value,Value,Value)
    alias An = Array(Value)
    alias Va = T1 | T2 | T3 | T4 | An 

    alias PV = Proc(Va,Value?)

    struct LcProc
        @proc : PV
        def initialize(&block : Va -> Value?)
            @proc = block 
        end

        def call(args : An)
            return @proc.call(args)
        end

        def call(*args : Value)
            return @proc.call(args)
        end

    end
end