
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

    MAX_ARY_CAPA = 1000
    MIN_ARY_CAPA = 5

    class LcArray < BaseC
        def initialize
            @total_size = 0.as(Intnum)
            @size       = 0.as(Intnum)
            @ptr        = Pointer(Value).null
        end
        attr total_size
        attr size 
        attr ptr 
    end

    macro ary_ptr(ary) 
        {{ary}}.as(LcArray).ptr 
    end 

    macro set_ary_size(ary,size)
        {{ary}}.as(LcArray).size = {{size}}
    end

    macro set_ary_total_size(ary,size)
        {{ary}}.as(LcArray).total_size = {{size}}
    end

    macro ary_size(ary)
        {{ary}}.as(LcArray).size
    end

    macro ary_total_size(ary)
        {{ary}}.as(LcArray).total_size
    end

    macro ary_at_index(ary,i)
        ary_ptr({{ary}})[{{i}}]
    end

    macro ary_set_index(ary,index,value)
        {{ary}}.as(LcArray).ptr[{{index}}] = {{value}}
    end

    macro resize_ary_capa(ary,size)
        f_size = ary_size({{ary}}) + {{size}}
        if MAX_ARY_CAPA < f_size
            lc_raise(LcArgumentError,"(Max array size exceeded)")
            return Null 
        end
        {{ary}}.as(LcArray).ptr = {{ary}}.as(LcArray).ptr.realloc(f_size)
        set_ary_total_size({{ary}},f_size)
    end

    macro resize_ary_capa_2(ary)
        f_size = ary_total_size(ary) + MIN_ARY_CAPA
        if MAX_ARY_CAPA < f_size
            lc_raise(LcArgumentError,"(Max array size exceeded)")
            return Null 
        end
        {{ary}}.as(LcArray).ptr = ary_ptr({{ary}}).realloc(f_size)
        set_ary_total_size({{ary}},f_size)
    end

    macro resize_ary_capa_3(ary,capa)
        if MAX_ARY_CAPA < {{capa}}
            lc_raise(LcArgumentError,"(Max array size exceeded)")
            return Null 
        end
        {{ary}}.as(LcArray).ptr = ary_ptr({{ary}}).realloc({{capa}})
        if {{capa}} < ary_total_size({{ary}})
            set_ary_size({{ary}},{{capa}})
        end
        set_ary_total_size({{ary}},{{capa}})
    end

    macro ary_range_to_null(ary,from,to)
        ({{from}}...{{to}}).each do |i|
            ary_set_index({{ary}},i,Null)
        end
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

    @[AlwaysInline]
    def self.build_ary_new(__)
        ary = new_ary
        resize_ary_capa_2(ary)
        return ary.as(Value)
    end

    def self.lc_build_ary_new(klass : Value)
        return new_ary 
    end

    def self.lc_ary_init(ary : Value, size : Value)
        x = lc_num_to_cr_i(size)
        return Null unless x.is_a? Intnum 
        resize_ary_capa_3(ary,x)
        ary_range_to_null(ary,0,x)
        set_ary_size(ary,x)
    end

    def self.lc_ary_push(ary : Value, value : Value)
        ary = ary.as(LcArray)
        if ary.size == ary.total_size
            resize_ary_capa_2(ary)
        end
        i = ary.size
        ary_set_index(ary,i,value)
        i += 1
        set_ary_size(ary,i)
    end

    def self.lc_ary_pop(ary : Value)
        i = ary_size(ary)
        if i == 0
            return Null 
        end 
        tmp = ary_at_index(ary,i - 1)
        i -= 1
        set_ary_size(ary,i)
        return tmp 
    end


    def self.lc_ary_index(ary : Value, index : Value)
        if index.is_a? LcRange 
            arylen = ary_size(ary)
            left   = index.left 
            right  = index.right 
            return Null if left > right || left > arylen
            return lc_ary_last(ary) if left == arylen
            range_size = right - left + ( index.inclusive ? 1 : 0)
            if left + range_size > arylen 
                range_size = arylen - left 
            end
            new_ary    = build_ary(range_size)
            set_ary_size(new_ary,range_size)
            ary_ptr(new_ary).copy_from(ary_ptr(ary) + left, range_size)
            return new_ary
        else
            i = internal.lc_num_to_cr_i(index)
            return Null unless i.is_a? Intnum
            if i >= ary_size(ary)  
                return Null 
            else
                v = ary_at_index(ary,i)
                return v
            end
        end
        # Should never get here
        Null 
    end

    def self.lc_ary_index_assign(ary : Value, index : Value, value : Value )
        x = internal.lc_num_to_cr_i(index)
         a_ary_size = ary_size(ary)
        t_ary_size = ary_total_size(ary)
        return Null unless x.is_a? Intnum
        if x > a_ary_size && x < t_ary_size
            set_ary_size(ary,x)
            ary_range_to_null(ary,a_ary_size,x)
            ary_set_index(ary,x,value)
        elsif x < a_ary_size
            ary_set_index(ary,x,value)
        else
            n = 0
            while t_ary_size < x 
                t_ary_size + MIN_ARY_CAPA
            end 
            resize_ary_capa(ary,t_ary_size)
            ary_range_to_null(ary,a_ary_size,x)
            set_ary_size(ary,x)
            ary_set_index(ary,x,value)
        end 
    end

    def self.lc_ary_includes(ary : Value, value : Value)
        a_ary_size = ary_size(ary)
        ptr        = ary.as(LcArray).ptr
        (0...a_ary_size).each do |i|
            if Exec.lc_call_fun(ptr[i],"==",value) == lctrue
                return lctrue 
            end 
        end
        return lcfalse 
    end 

    def self.lc_ary_clone(ary : Value)
        a_ary_size = ary_size(ary)
        t_ary_size = ary_total_size(ary)
        ary2       = build_ary(t_ary_size)
        set_ary_size(ary2,a_ary_size)
        (0...a_ary_size).each do |i|
            ary_set_index(ary2,i,ary_at_index(ary,i))
        end
        return ary2 
    end

    def self.lc_ary_add(ary1 : Value, ary2 : Value)
        a_size1 = ary_size(ary1)
        a_size2 = ary_size(ary2)
        a_size3 = a_size1 + a_size2
        t_ary_size = ary_total_size(ary1) + ary_total_size(ary2)
        tmp     = build_ary(t_ary_size)
        set_ary_size(tmp,a_size3)
        ary_range_to_null(tmp,0,t_ary_size)
        ary_ptr(tmp).copy_from(ary_ptr(ary1),a_size1)
        (ary_ptr(tmp)  + a_size1).copy_from(ary_ptr(ary2),a_size2)
        return tmp
    end

    def self.lc_ary_last(ary : Value)
        return Null if ary_size(ary) == 0
        return ary_ptr(ary)[ary_size(ary) - 1]
    end

    def self.lc_ary_len(ary : Value)
        return num2int(ary_size(ary))
    end

    def self.lc_ary_to_s(ary : Value)
        arylen = ary_size(ary)
        ptr    = ary_ptr(ary)
        return build_string("[]") if arylen == 0
        string = String.build do |io|
            io << '['
            (0...arylen - 1).each do |i|
                lc_str_io_append(io,ptr[i])
                io << ','
            end 
            lc_str_io_append(io,ptr[arylen - 1])
            io << ']'
        end 
        return build_string(string)
    ensure 
        GC.free(Box.box(string))
    end


    AryClass = internal.lc_build_class_only("Array")
    internal.lc_set_parent_class(AryClass,Obj)

    internal.lc_add_static_singleton(AryClass,"new",:lc_build_ary_new,0)
    internal.lc_add_internal(AryClass,"init",:lc_ary_init,    1)
    internal.lc_add_internal(AryClass,"+",:lc_ary_add,        1)
    internal.lc_add_internal(AryClass,"push",:lc_ary_push,    1)
    internal.lc_add_internal(AryClass,"<<",:lc_ary_push,      1)
    internal.lc_add_internal(AryClass,"pop",:lc_ary_pop,      0)
    internal.lc_add_internal(AryClass,"[]",:lc_ary_index,     1)
    internal.lc_add_internal(AryClass,"[]=",:lc_ary_index_assign, 2)
    internal.lc_add_internal(AryClass,"includes",:lc_ary_includes,1)
    internal.lc_add_internal(AryClass,"clone",:lc_ary_clone,      0)
    internal.lc_add_internal(AryClass,"last", :lc_ary_last,   0)
    internal.lc_add_internal(AryClass,"size", :lc_ary_len,    0)
    internal.lc_add_internal(AryClass,"length",:lc_ary_len,   0)
    internal.lc_add_internal(AryClass,"to_s", :lc_ary_to_s,   0)
end
