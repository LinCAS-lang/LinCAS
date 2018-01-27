
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

module LinCAS::Internal

    class LcRange < BaseC
        @left  : Intnum = 0
        @right : Intnum = 0
        @inclusive = true
        attr left 
        attr right
        attr inclusive
    end    

    def self.range_new
        range       = LcRange.new 
        range.klass = RangeClass 
        range.data  = RangeClass.data.clone 
        return range 
    end

    def self.build_range(v1 : Num, v2 : Num, inclusive = true)
        range       = range_new 
        range.left  = v1.to_i 
        range.right = v2.to_i
        range.inclusive = inclusive
        return range.as(Value)
    end

    def self.build_range(v1 : Value, v2 : Value, inclusive : Bool)
        n1 = lc_num_to_cr_i(v1)
        n2 = lc_num_to_cr_i(v2)
        return Null unless n1 && n2
        return build_range(n1,n2,inclusive)
    end

    RangeClass = internal.lc_build_class_only("Range")


end