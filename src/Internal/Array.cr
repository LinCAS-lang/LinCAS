
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

    class LcArray < BaseC
        def initialize
            @size = 0
            @ptr  = Pointer(Value).null
        end
        attr size 
        attr ptr 
    end

    macro set_ary_size(ary,size)
        {{ary}}.as(LcArray).size = {{size}}
    end

    macro ary_size(ary)
        {{ary}}.as(LcArray).size
    end

    macro ary_at_index(ary,i)
        {{ary}}.as(LcArray).ptr[{{i}}]
    end

    macro resize_ary_capa(ary,size)
        f_size = ary_size(ary) + size
        {{ary}}.as(LcArray).ptr = {{ary}}.as(LcArray).ptr.realloc(f_size)
        set_ary_size(ary,size)
    end

    def self.tuple2array(*values : Value)
        ary = build_ary(values.size)
        values.each_with_index do |v,i|
            ary.as(LcArray).ptr[i] = v 
        end
        return ary.as(Value)
    end

    def self.new_ary
        ary = LcArray.new
        ary.klass = AryClass
        ary.data  = AryClass.data.clone
        return ary.as(Value)
    end

    @[AlwaysInline]
    def self.build_ary(size : Intnum)
        ary = new_ary
        resize_ary_capa(ary,size) if size > 0
        return ary.as(Value)
    end

    @[AlwaysInline]
    def self.build_ary(size : Value)
        sz = internal.lc_num_to_cr_i(size)
        if sz 
            return build_ary(sz)
        else 
            return Null 
        end 
    end

    def self.lc_ary_index(ary : Value, index : Value)
        if index.is_a? LcNum
            i = internal.lc_num_to_cr_i(index)
            return Null unless i.is_a? Intnum
            if i > ary_size(ary) 
                return Null 
            else
                return ary_at_index(ary,i)
            end
#        elsif index.is_a? LcRange
        end
        # Should never get here
        Null 
    end

    AryClass = internal.lc_build_class_only("Array")
end