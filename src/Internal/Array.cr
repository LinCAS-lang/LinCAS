
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

module LinCAS::Internal

    MAX_ARY_CAPA = 10000
    MIN_ARY_CAPA = 5

    class LcArray < BaseC
        def initialize
            @total_size = 0.as(Intnum)
            @size       = 0.as(Intnum)
            @ptr        = Pointer(Value).null
        end
        property total_size, size, ptr
        def to_s
            return Internal.ary_to_string(self)
        end 
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

    macro ary_sort_by_m(ary_ptr,length)
        lc_heap_sort({{ary_ptr}},{{length}}) do |v1,v2|
            if !Exec.block_given?
                lc_raise(LcArgumentError,"Expected block not found")
                next nil 
            end
            r1 = Exec.lc_yield(v1)
            r2 = Exec.lc_yield(v2)
            if r1.is_a? LcNum && r2.is_a? LcNum
                next (num2num(r1) > num2num(r2) ? 1 : 0)
            elsif r1.is_a? LcString && r2.is_a? LcString
                ptr1 = pointer_of(r1)
                ptr2 = pointer_of(r2)
                next ((libc.strcmp(ptr1,ptr2) > 0) ? 1 : 0)
            else
                lc_raise(LcArgumentError,"Comparison between #{lc_typeof(r1)} and #{lc_typeof(r2)} failed")
                next nil 
            end
        end
    end

    def self.tuple2array(*values : Value)
        ary = build_ary(values.size)
        set_ary_size(ary,values.size)
        values.each_with_index do |v,i|
            ary.as(LcArray).ptr[i] = v 
        end
        return ary.as(Value)
    end

    private def self.ary_from_int(i_ary : Int32*,size : Int32)
        ary   = build_ary(size)
        prt   = ary_ptr(ary)
        count = -1
        ptr.map!(size) do
            next num2int(i_ary[count += 1])
        end
        return ary
    end

    @[AlwaysInline]
    private def self.ary_append(buffer : String_buffer,ary : Value, origin : Value? = nil)
        size = ary_size(ary)
        ptr  = ary_ptr(ary)
        i    = 0
        buffer_append(buffer,'[')
        while i < size
            item = ptr[i]
            if item.is_a? LcArray
                if (ary.id == item.id) || (origin && (origin.id == item.id))
                    buffer_append(buffer,"[...]")
                else 
                    ary_append(buffer,item,origin ? origin : ary)
                end
            else
                string_buffer_appender(buffer,item)
            end
            buffer_append(buffer,',') if i < size - 1
            i += 1
        end
        buffer_append(buffer,']')
    end

    def self.new_ary
        ary = LcArray.new
        ary.klass = AryClass
        ary.data  = AryClass.data.clone
        ary.id    = ary.object_id
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
            return build_ary_new
        end 
    end

    @[AlwaysInline]
    def self.build_ary_new
        ary = new_ary
        resize_ary_capa_2(ary)
        return ary.as(Value)
    end

    def self.lc_ary_allocate(klass : Value)
        klass     = klass.as(LcClass)
        ary       = LcArray.new
        ary.klass = klass
        ary.data  = klass.data.clone
        ary.id    = ary.object_id
        return ary.as(Value)
    end

    ary_allocate = LcProc.new do |args|
        next lc_ary_allocate(*args.as(T1))
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
        return value
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

    private def self.ary_iterate(ary : Value)
        ary_p = ary_ptr(ary)
        size  = ary_size(ary)
        i     = 0
        while i < size 
            yield(ary_p[i])
            i += 1
        end
    end

    private def self.ary_iterate_with_index(ary : Value)
        ary_p = ary_ptr(ary)
        size  = ary_size(ary)
        i     = 0
        while i < size 
            yield(ary_p[i],i)
            i += 1
        end
    end

    def self.lc_ary_include(ary : Value, value : Value)
        a_ary_size = ary_size(ary)
        ptr        = ary.as(LcArray).ptr
        ary_iterate(ary) do |el|
            if test(Exec.lc_call_fun(el,"==",value))
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
        ptr        = ary_ptr(ary2)
        ptr.copy_from(ary_ptr(ary),a_ary_size)
        set_ary_size(ary2,a_ary_size)
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
        if test(tmp)
            set_ary_size(tmp,a_size3)
            ary_range_to_null(tmp,0,t_ary_size)
            ary_ptr(tmp).copy_from(ary_ptr(ary1),a_size1)
            (ary_ptr(tmp)  + a_size1).copy_from(ary_ptr(ary2),a_size2)
            return tmp
        end
        return ary1
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

    def self.ary_to_string(ary : Value)
        buffer = string_buffer_new
        ary_append(buffer,ary)
        buffer_trunc(buffer)
        return buffer
    end 

    def self.lc_ary_to_s(ary : Value)
        buffer = ary_to_string(ary)
        if buff_size(buffer) > STR_MAX_CAPA
            buffer_dispose(buffer)
            return lc_obj_to_s(ary)
        end
        return build_string_with_ptr(buff_ptr(buffer),buff_size(buffer))
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
        tmp    = build_ary_new
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

    def self.lc_ary_each_with_index(ary : Value)
        arylen = ary_size(ary)
        ptr    = ary_ptr(ary)
        arylen.times do |i|
            Exec.lc_yield(ptr[i],num2int(i))
            break if Exec.error?
        end
        return Null 
    end

    ary_each_with_index = LcProc.new do |args|
        next internal.lc_ary_each_with_index(*args.as(T1))
    end

    def self.lc_ary_flatten(ary : Value)
        arylen = ary_size(ary)
        new_ary = build_ary_new
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

    def self.lc_ary_swap(ary : Value, i1 : Value, i2 : Value)
        i1_val = lc_num_to_cr_i(i1)
        return Null unless i1_val 
        i2_val = lc_num_to_cr_i(i2)
        return Null unless i2_val
        arylen = ary_size(ary)
        if (i1_val < 0) || (i2_val < 0) || (i1_val >= arylen) || (i2_val >= arylen)
            lc_raise(LcIndexError,"(Indexes out of array)")
            return Null 
        end 
        ptr = ary_ptr(ary)
        ptr.swap(i1_val,i2_val)
        return Null 
    end 

    ary_swap = LcProc.new do |args|
        next internal.lc_ary_swap(*args.as(T3))
    end

    def self.lc_ary_map_with_index(ary : Value)
        size = ary_size(ary)
        tmp  = build_ary(size)
        size.times do |i|
            value = Exec.lc_yield(ary_at_index(ary,i),num2int(i)).as(Value)
            break if Exec.error?
            ary_set_index(tmp,i,value)
        end
        return tmp
    end 

    ary_map_with_index = LcProc.new do |args|
        next internal.lc_ary_map_with_index(*args.as(T1))
    end

    def self.lc_ary_o_map_with_index(ary : Value)
        size = ary_size(ary)
        size.times do |i|
            value = Exec.lc_yield(ary_at_index(ary,i),num2int(i)).as(Value)
            break if Exec.error?
            ary_set_index(ary,i,value)
        end
        return ary 
    end

    ary_o_map_with_index = LcProc.new do |args|
        next internal.lc_ary_o_map_with_index(*args.as(T1))
    end

    private def self.internal_ary_sort(ary : Value*,size)
        if size > 1
            if ary[0].is_a? LcNum
                lc_heap_sort(ary,size) do |v1,v2|
                    if v1.is_a? LcNum && v2.is_a? LcNum
                        next (num2num(v1) > num2num(v2) ? 1 : 0)
                    else
                        lc_raise(LcArgumentError,"Comparison between #{lc_typeof(v1)} and #{lc_typeof(v2)} failed")
                        next nil
                    end
                end
            elsif ary[0].is_a? LcString
                lc_heap_sort(ary,size) do |v1,v2|
                    if v1.is_a? LcString && v2.is_a? LcString
                        ptr1 = pointer_of(v1)
                        ptr2 = pointer_of(v2)
                        next ((libc.strcmp(ptr1,ptr2) > 0) ? 1 : 0)
                    else
                        lc_raise(LcArgumentError,"Comparison between #{lc_typeof(v1)} and #{lc_typeof(v2)} failed")
                        next nil
                    end
                end
            else
                lc_raise(LcArgumentError,"Comparison between #{lc_typeof(ary[0])} and #{lc_typeof(ary[1])} failed")
            end
        end
    end

    def self.lc_ary_sort(ary : Value)
        arylen = ary_size(ary)
        s_ary  = build_ary(arylen)
        set_ary_size(s_ary,arylen)
        tmp    = ary_ptr(s_ary)
        ptr    = ary_ptr(ary)
        tmp.copy_from(ptr,arylen)
        internal_ary_sort(tmp,arylen)
        return s_ary 
    end

    ary_sort = LcProc.new do |args|
        next internal.lc_ary_sort(*args.as(T1))
    end

    def self.lc_ary_o_sort(ary : Value)
        arylen = ary_size(ary)
        ptr    = ary_ptr(ary)
        internal_ary_sort(ptr,arylen)
        return ary 
    end

    ary_o_sort = LcProc.new do |args|
        next internal.lc_ary_o_sort(*args.as(T1))
    end

    def self.lc_ary_reverse(ary : Value)
        arylen  = ary_size(ary)
        ptr     = ary_ptr(ary)
        tmp     = build_ary(arylen)
        tmp_ptr = ary_ptr(tmp)
        arylen.times do |i|
            tmp_ptr[i] = ptr[arylen - i - 1]
        end
        set_ary_size(tmp,arylen)
        return tmp 
    end

    ary_reverse = LcProc.new do |args|
        next internal.lc_ary_reverse(*args.as(T1))
    end

    def self.lc_ary_o_reverse(ary : Value)
        arylen = ary_size(ary)
        ptr    = ary_ptr(ary)
        (arylen / 2).times do |i|
            ptr.swap(i,arylen - i - 1)
        end
        return ary 
    end

    ary_o_reverse = LcProc.new do |args|
        next internal.lc_ary_o_reverse(*args.as(T1)) 
    end

    def self.lc_ary_max(ary : Value)
        arylen = ary_size(ary)
        if arylen > 0
            ptr    = ary_ptr(ary)
            tmp    = Pointer(Value).malloc(arylen)
            tmp.copy_from(ptr,arylen)
            internal_ary_sort(tmp,arylen)
            max = tmp[arylen - 1]
            tmp = tmp.realloc(0)
            return max 
        end 
        return Null
    end

    ary_max = LcProc.new do |args|
        next internal.lc_ary_max(*args.as(T1))
    end

    def self.lc_ary_min(ary : Value)
        arylen = ary_size(ary)
        if arylen > 0
            ptr    = ary_ptr(ary)
            tmp    = Pointer(Value).malloc(arylen)
            tmp.copy_from(ptr,arylen)
            internal_ary_sort(tmp,arylen)
            min = tmp[0]
            tmp = tmp.realloc(0)
            return min 
        end 
        return Null
    end

    ary_min = LcProc.new do |args|
        next internal.lc_ary_min(*args.as(T1))
    end

    def self.lc_ary_delete_at(ary : Value, index : Value)
        i      = lc_num_to_cr_i(index)
        arylen = ary_size(ary)
        if i 
            if i >= 0 && i < arylen 
                ptr = ary_ptr(ary)
                (ptr + i).copy_from(ptr + (i + 1),arylen - i + 1)
                set_ary_size(ary,arylen - 1)
            end 
        end
        return ary
    end 

    ary_delete_at = LcProc.new do |args|
        next internal.lc_ary_delete_at(*args.as(T2))
    end

    def self.lc_ary_compact(ary : Value)
        arylen = ary_size(ary)
        ptr    = ary_ptr(ary)
        tmp    = build_ary_new
        arylen.times do |i|
            if ptr[i] != Null 
                lc_ary_push(tmp,ptr[i])
            end   
        end
        return tmp 
    end 

    ary_compact = LcProc.new do |args|
        next internal.lc_ary_compact(*args.as(T1))
    end

    def self.lc_ary_o_compact(ary : Value)
        arylen = ary_size(ary)
        ptr    = ary_ptr(ary)
        tmp    = Pointer(Value).malloc(arylen)
        count  = 0
        arylen.times do |i|
            if ptr[i] != Null 
                tmp[count] = ptr[i]
                count += 1 
            end
        end
        ptr.copy_from(tmp,count)
        set_ary_size(ary,count)
        tmp = tmp.realloc(0)
        return ary 
    end

    ary_o_compact = LcProc.new do |args|
        next internal.lc_ary_o_compact(*args.as(T1))
    end

    def self.lc_ary_shift(ary : Value)
        arylen = ary_size(ary)
        return ary if arylen == 0
        ptr    = ary_ptr(ary)
        tmp    = Pointer(Value).malloc(arylen)
        tmp.copy_from(ptr,arylen)
        ptr.copy_from(tmp + 1, arylen - 1)
        set_ary_size(ary,arylen  -1)
        tmp = tmp.realloc(0)
        return ary
    end 

    ary_shift = LcProc.new do |args|
        next internal.lc_ary_shift(*args.as(T1))
    end

    def self.lc_ary_sort_by(ary : Value)
        arylen = ary_size(ary)
        return ary if arylen < 2
        tmp    = build_ary(ary_total_size(ary))
        set_ary_size(tmp,arylen)
        ary_ptr(tmp).copy_from(ary_ptr(ary),arylen)
        ary_sort_by_m(ary_ptr(tmp),arylen)
        return tmp
    end

    ary_sort_by = LcProc.new do |args|
        next internal.lc_ary_sort_by(*args.as(T1))
    end

    def self.lc_ary_o_sort_by(ary : Value)
        ary_sort_by_m(ary_ptr(ary),ary_size(ary))
        return ary 
    end 

    ary_o_sort_by = LcProc.new do |args|
        next internal.lc_ary_o_sort_by(*args.as(T1))
    end

    def self.lc_ary_join(ary : Value, *args : Value)
        if args[0] == Null
            separator = ""
        else 
            separator = string2cr(args[0])
        end 
        arylen = ary_size(ary)
        string = String.build do |io|
            arylen.times do |i|
                io << ary_at_index(ary,i).to_s 
                io << separator if i < arylen - 1
            end
        end
        if string.size > STR_MAX_CAPA
            lc_raise(LcRuntimeError,"String overflows max length")
            return Null 
        end 
        return build_string(string)
    end 

    ary_join = LcProc.new do |args|
        args = args.as(An)
        arg1 = args[0]
        arg2 = args[1]?
        if arg2
            next internal.lc_ary_join(arg1,arg2)
        end 
        next internal.lc_ary_join(arg1,Null)
    end
        

    AryClass = internal.lc_build_internal_class("Array")
    internal.lc_set_parent_class(AryClass,Obj)
    internal.lc_set_allocator(AryClass,ary_allocate)

    internal.lc_add_internal(AryClass,"init",ary_init,       1)
    internal.lc_add_internal(AryClass,"+",ary_add,           1)
    internal.lc_add_internal(AryClass,"push",ary_push,       1)
    internal.lc_add_internal(AryClass,"<<",ary_push,         1)
    internal.lc_add_internal(AryClass,"pop",ary_pop,         0)
    internal.lc_add_internal(AryClass,"[]",ary_index,        1)
    internal.lc_add_internal(AryClass,"[]=",ary_index_assign,2)
    internal.lc_add_internal(AryClass,"include?",ary_include,1)
    internal.lc_add_internal(AryClass,"clone",ary_clone,     0)
    internal.lc_add_internal(AryClass,"first",ary_first,     0)
    internal.lc_add_internal(AryClass,"last", ary_last,      0)
    internal.lc_add_internal(AryClass,"size", ary_len,       0)
    internal.lc_add_internal(AryClass,"length",ary_len,      0)
    internal.lc_add_internal(AryClass,"to_s", ary_to_s,      0)
    internal.lc_add_internal(AryClass,"each",ary_each,       0)
    internal.lc_add_internal(AryClass,"map",ary_map,         0)
    internal.lc_add_internal(AryClass,"map!",ary_o_map,      0)
    internal.lc_add_internal(AryClass,"flatten",ary_flatten, 0)
    internal.lc_add_internal(AryClass,"insert",ary_insert,  -1)
    internal.lc_add_internal(AryClass,"==",ary_eq,           1)
    internal.lc_add_internal(AryClass,"swap",ary_swap,       2)
    internal.lc_add_internal(AryClass,"sort",ary_sort,       0)
    internal.lc_add_internal(AryClass,"max",ary_max,         0)
    internal.lc_add_internal(AryClass,"min",ary_min,         0)
    internal.lc_add_internal(AryClass,"sort!",ary_o_sort,    0)
    internal.lc_add_internal(AryClass,"reverse",ary_reverse, 0)
    internal.lc_add_internal(AryClass,"shift",ary_shift,     0)
    internal.lc_add_internal(AryClass,"join",ary_join,      -1)
    internal.lc_add_internal(AryClass,"sort_by",ary_sort_by,                  0)
    internal.lc_add_internal(AryClass,"sort_by!",ary_o_sort_by,               0)
    internal.lc_add_internal(AryClass,"reverse!",ary_o_reverse,               0)
    internal.lc_add_internal(AryClass,"delete_at",ary_delete_at,              1)
    internal.lc_add_internal(AryClass,"each_with_index",ary_each_with_index,  0)
    internal.lc_add_internal(AryClass,"map_with_index",ary_map_with_index,    0)
    internal.lc_add_internal(AryClass,"map_with_index!",ary_o_map_with_index, 0)
    internal.lc_add_internal(AryClass,"compact",ary_compact,                  0)
    internal.lc_add_internal(AryClass,"compact!",ary_o_compact,               0)
end
