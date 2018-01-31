
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

    lc_new_ary = LcProc.new do |args|
        next new_ary
    end

    def self.lc_ary_init(ary : Value, size : Value)
        x = lc_num_to_cr_i(size)
        return Null unless x.is_a? Intnum 
        resize_ary_capa_3(ary,x)
        ary_range_to_null(ary,0,x)
        set_ary_size(ary,x)
        Null
    end

    ary_init = LcProc.new do |args|
        next internal.lc_ary_init(*args.as(T2))
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
        Null
    end

    ary_push = LcProc.new do |args|
        next internal.lc_ary_push(*args.as(T2))
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

    ary_pop = LcProc.new do |args|
        next internal.lc_ary_pop(*args.as(T1))
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
            if i >= ary_size(ary)  || i < 0 
                return Null 
            else
                v = ary_at_index(ary,i)
                return v
            end
        end
        # Should never get here
        Null 
    end

    ary_index = LcProc.new do |args|
        next internal.lc_ary_index(*args.as(T2))
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
            lc_raise(LcIndexError,"(Index #{x} out of array)") unless x > 0
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
        Null 
    end

    ary_index_assign = LcProc.new do |args|
        args = args.as(T3)
        next internal.lc_ary_index_assign(*args)
    end

    def self.lc_ary_include(ary : Value, value : Value)
        a_ary_size = ary_size(ary)
        ptr        = ary.as(LcArray).ptr
        (0...a_ary_size).each do |i|
            if Exec.lc_call_fun(ptr[i],"==",value) == lctrue
                return lctrue 
            end 
        end
        return lcfalse 
    end 

    ary_include = LcProc.new do |args|
        next internal.lc_ary_include(*args.as(T2))
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

    ary_clone = LcProc.new do |args|
        next internal.lc_ary_clone(*args.as(T1))
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

    ary_add = LcProc.new do |args|
        next internal.lc_ary_add(*args.as(T2))
    end

    @[AlwaysInline]
    def self.lc_ary_first(ary : Value)
        return Null unless ary_size(ary) > 0
        return ary_at_index(ary,0)
    end 

    ary_first = LcProc.new do |args|
        next internal.lc_ary_first(*args.as(T1))
    end

    def self.lc_ary_last(ary : Value)
        return Null if ary_size(ary) == 0
        return ary_ptr(ary)[ary_size(ary) - 1]
    end

    ary_last = LcProc.new do |args|
        next internal.lc_ary_last(*args.as(T1))
    end

    def self.lc_ary_len(ary : Value)
        return num2int(ary_size(ary))
    end

    ary_len = LcProc.new do |args|
        next num2int(ary_size(args.as(T1)[0]))
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

    ary_to_s = LcProc.new do |args|
        next internal.lc_ary_to_s(*args.as(T1))
    end

    def self.lc_ary_each(ary : Value)
        arylen = ary_size(ary)
        ptr    = ary_ptr(ary)
        arylen.times do |i|
            Exec.lc_yield(ary_at_index(ary,i))
        end
        Null 
    end

    ary_each = LcProc.new do |args|
        next internal.lc_ary_each(*args.as(T1))
    end

    def self.lc_ary_map(ary : Value)
        arylen = ary_size(ary)
        tmp    = build_ary_new nil 
        arylen.times do |i|
            lc_ary_push(tmp,Exec.lc_yield(ary_at_index(ary,i)))
        end
        return tmp 
    end 

    ary_map = LcProc.new do |args|
        next internal.lc_ary_map(*args.as(T1))
    end

    def self.lc_ary_o_map(ary : Value)
        arylen = ary_size(ary)
        arylen.times do |i|
            ary_set_index(ary,i,Exec.lc_yield(ary_at_index(ary,i)))
        end
        return ary 
    end 

    ary_o_map = LcProc.new do |args|
        next internal.lc_ary_o_map(*args.as(T1))
    end

    def self.lc_ary_flatten(ary : Value)
        arylen = ary_size(ary)
        new_ary = build_ary_new(nil)
        arylen.times do |i|
            elem = ary_at_index(ary,i)
            if elem.is_a? LcArray
                tmp = lc_ary_flatten(elem)
                arylen_t = ary_size(tmp)
                arylen_t.times do |k|
                    lc_ary_push(new_ary,ary_at_index(tmp,k))
                end
            else
                lc_ary_push(new_ary,elem)
            end 
        end 
        return new_ary
    end

    ary_flatten = LcProc.new do |args|
        next internal.lc_ary_flatten(*args.as(T1))
    end

    def self.lc_ary_insert(ary : Value, index : Value, elem : Array(Value))
        x = lc_num_to_cr_i(index)
        return Null unless x.is_a? Intnum
        arylen = ary_size(ary)
        ptr    = ary_ptr(ary)
        if (x > arylen - 1) || (x < 0)
            lc_raise(LcIndexError,"(Index #{x} out of array)")
            return Null 
        elsif x == arylen - 1
            elem.each do |e|
                lc_ary_push(ary,e)
            end
            return ary 
        else 
            elemc = elem.size 
            if elemc > 1
                resize_ary_capa(ary,elemc)
            end
            tmp   = ptr + x + elemc 
            tmp.copy_from(ptr + x,arylen - x)
            (x...(x + elemc)).each do |i|
                ary_set_index(ary,i,elem[i - x])
            end 
            return ary 
        end
    end

    ary_insert = LcProc.new do |args|
        tmp  = args.as(An)
        arg1 = tmp[0]
        arg2 = tmp[1]  
        tmp.shift; tmp.shift
        next internal.lc_ary_insert(arg1,arg2,tmp)
    end

    def self.lc_ary_eq(ary1 : Value, ary2 : Value)
        return lcfalse if ary_size(ary1) != ary_size(ary2)
        arylen = ary_size(ary1)
        arylen.times do |i|
            return lcfalse unless lc_obj_compare(
                ary_at_index(ary1,i),
                ary_at_index(ary2,i)
            ) == lctrue 
        end
        return lctrue 
    end

    ary_eq = LcProc.new do |args|
        next internal.lc_ary_eq(*args.as(T2))
    end

    ary_defrost = LcProc.new do |args|
        ary = args.as(T1)[0]
        ary.frozen = false 
        next ary 
    end


    AryClass = internal.lc_build_class_only("Array")
    internal.lc_set_parent_class(AryClass,Obj)

    internal.lc_add_static_singleton(AryClass,"new",lc_new_ary,0)
    internal.lc_add_internal(AryClass,"init",ary_init,    1)
    internal.lc_add_internal(AryClass,"+",ary_add,        1)
    internal.lc_add_internal(AryClass,"push",ary_push,    1)
    internal.lc_add_internal(AryClass,"<<",ary_push,      1)
    internal.lc_add_internal(AryClass,"pop",ary_pop,      0)
    internal.lc_add_internal(AryClass,"[]",ary_index,     1)
    internal.lc_add_internal(AryClass,"[]=",ary_index_assign,2)
    internal.lc_add_internal(AryClass,"includes",ary_include,1)
    internal.lc_add_internal(AryClass,"clone",ary_clone,     0)
    internal.lc_add_internal(AryClass,"first",ary_first,  0)
    internal.lc_add_internal(AryClass,"last", ary_last,   0)
    internal.lc_add_internal(AryClass,"size", ary_len,    0)
    internal.lc_add_internal(AryClass,"length",ary_len,   0)
    internal.lc_add_internal(AryClass,"to_s", ary_to_s,   0)
    internal.lc_add_internal(AryClass,"each",ary_each,    0)
    internal.lc_add_internal(AryClass,"map",ary_map,      0)
    internal.lc_add_internal(AryClass,"o_map",ary_o_map,  0)
    internal.lc_add_internal(AryClass,"flatten",ary_flatten,0)
    internal.lc_add_internal(AryClass,"insert",ary_insert, -1)
    internal.lc_add_internal(AryClass,"==",ary_eq,          1)
    internal.lc_add_internal(AryClass,"defrost",ary_defrost,0)
end
