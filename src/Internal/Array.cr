
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
            @ptr        = Pointer( LcVal).null
        end
        property total_size, size, ptr
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

    def self.tuple2array(*values :  LcVal)
        ary = build_ary(values.size).as(LcArray)
        set_ary_size(ary,values.size)
        values.each_with_index do |v,i|
            ary.ptr[i] = v 
        end
        return ary.as( LcVal)
    end

    # This function converts a LinCAS array to a Python list.
    # It takes as argument a LinCAS Object (array) and returns a
    # Python object reference (PyObject).
    # No check is performed on the passed argument (ary), so
    # be sure of what you're doing
    def self.ary2py(ary :  LcVal)
        size  = ary_size(ary)
        ptr   = ary_ptr(ary)
        pyary = pyary_new(size)
        size.times do |i|
            item = ary_at_index(ary,i)
            res  = pyary_set_item(pyary,i,obj2py(item, ref: true))
            if res != 0 || pyerr_occurred
                lc_raise_py_error
                return PyObject.null 
            end
        end
        return pyary
    end

    # This functions converts a Python list to a LinCAS array.
    # It takes as argument a reference to a Python object and
    # it returns a LinCAS one.
    # Python object count reference is decreased.
    # No check is performed on the passed python object
    def self.pyary2ary(pyary : PyObject)
        ary  = build_ary_new
        size = pyary_size(pyary)
        size.times do |i|
            item = pyary_get_item(pyary,i)
            lc_ary_push(ary,pyobj2lc(item, borrowed_ref: true))
        end
        pyobj_decref(pyary)
        return ary
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
    private def self.ary_append(buffer : String_buffer,ary :  LcVal, origin = [] of  LcVal)
        size = ary_size(ary)
        ptr  = ary_ptr(ary)
        i    = 0
        origin << ary
        buffer_append(buffer,'[')
        while i < size
            item = ptr[i]
            if item.is_a? LcArray
                if (origin.includes? item)
                    buffer_append(buffer,"[...]")
                else 
                    ary_append(buffer,item,origin)
                end
            else
                string_buffer_appender(buffer,item)
            end
            buffer_append_n(buffer,',',' ') if i < size - 1
            i += 1
        end
        buffer_append(buffer,']')
        origin.pop
    end

    def self.new_ary_wrapper
        ary = Ary.new
        ary.klass = @@lc_array
        # ary.data  = @@lc_array.data.clone
        ary.id    = ary.object_id
        ary.flags |= ObjectFlags::FAKE
        return ary
    end

    def self.new_ary
        ary    = lincas_obj_alloc LcArray, @@lc_array, data: @@lc_array.data.clone
        ary.id = ary.object_id
        return ary.as( LcVal)
    end

    @[AlwaysInline]
    def self.build_ary(size : Intnum)
        ary = new_ary
        resize_ary_capa(ary,size) if size > 0
        return ary.as( LcVal)
    end

    @[AlwaysInline]
    def self.build_ary(size :  LcVal)
        sz = internal.lc_num_to_cr_i(size)
        if sz && sz > 0
            return build_ary(sz)
        else 
            return build_ary_new
        end 
    end

    @[AlwaysInline]
    def self.build_ary_new
        ary = new_ary
        resize_ary_capa_2(ary)
        return ary.as( LcVal)
    end

    def self.lc_ary_allocate(klass :  LcVal)
        klass     = klass.as(LcClass)
        ary       = lincas_obj_alloc LcArray, klass, data: klass.data.clone
        ary.id    = ary.object_id
        return ary.as( LcVal)
    end

    def self.lc_ary_init(ary :  LcVal, size :  LcVal)
        x = lc_num_to_cr_i(size)
        return Null unless x.is_a? Intnum 
        resize_ary_capa_3(ary,x)
        ary_range_to_null(ary,0,x)
        set_ary_size(ary,x)
        Null
    end

    def self.lc_ary_push(ary :  LcVal, value :  LcVal)
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


    def self.lc_ary_pop(ary :  LcVal)
        i = ary_size(ary)
        if i == 0
            return Null 
        end 
        tmp = ary_at_index(ary,i - 1)
        i -= 1
        set_ary_size(ary,i)
        return tmp 
    end

    def self.lc_ary_index(ary :  LcVal, index :  LcVal)
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

    def self.lc_ary_index_assign(ary :  LcVal, index :  LcVal, value :  LcVal )
        x = internal.lc_num_to_cr_i(index)
        a_ary_size = ary_size(ary)
        t_ary_size = ary_total_size(ary)
        return Null unless x.is_a? Intnum
        if x >= a_ary_size && x < t_ary_size
            set_ary_size(ary,x + 1)
            ary_range_to_null(ary,a_ary_size,x)
            ary_set_index(ary,x,value)
        elsif x < a_ary_size
            lc_raise(LcIndexError,"(Index #{x} out of array)") unless x >= 0
            ary_set_index(ary,x,value)
        else
            n = 0
            while t_ary_size < x 
                t_ary_size + MIN_ARY_CAPA
            end 
            resize_ary_capa(ary,t_ary_size)
            ary_range_to_null(ary,a_ary_size,x)
            set_ary_size(ary,x + 1)
            ary_set_index(ary,x,value)
        end
        value
    end

    private def self.ary_iterate(ary :  LcVal)
        ary_p = ary_ptr(ary)
        size  = ary_size(ary)
        i     = 0
        while i < size 
            yield(ary_p[i])
            i += 1
        end
    end

    private def self.ary_iterate_with_index(ary :  LcVal)
        ary_p = ary_ptr(ary)
        size  = ary_size(ary)
        i     = 0
        while i < size 
            yield(ary_p[i],i)
            i += 1
        end
    end

    private def self.ary_iterate_with_index(ary :  LcVal, index : Int64)
        ary_p = ary_ptr(ary)
        size  = ary_size(ary)
        i     = index
        while i < size 
            yield(ary_p[i],i)
            i += 1
        end
    end

    def self.lc_ary_include(ary :  LcVal, value :  LcVal)
        a_ary_size = ary_size(ary)
        ptr        = ary.as(LcArray).ptr
        ary_iterate(ary) do |el|
            if test(Exec.lc_call_fun(el,"==",value))
                return lctrue 
            end 
        end
        return lcfalse 
    end 

    def self.lc_ary_clone(ary :  LcVal)
        a_ary_size = ary_size(ary)
        t_ary_size = ary_total_size(ary)
        ary2       = build_ary(t_ary_size)
        ptr        = ary_ptr(ary2)
        ptr.copy_from(ary_ptr(ary),a_ary_size)
        set_ary_size(ary2,a_ary_size)
        return ary2 
    end

    def self.lc_ary_add(ary1 :  LcVal, ary2 :  LcVal)
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

    @[AlwaysInline]
    def self.lc_ary_first(ary :  LcVal)
        return Null unless ary_size(ary) > 0
        return ary_at_index(ary,0)
    end 

    def self.lc_ary_last(ary :  LcVal)
        return Null if ary_size(ary) == 0
        return ary_ptr(ary)[ary_size(ary) - 1]
    end

    def self.lc_ary_len(ary :  LcVal)
        return num2int(ary_size(ary))
    end

    def self.lc_ary_empty(ary :  LcVal)
        return (ary_size(ary) == 0) ? lctrue : lcfalse
    end

    def self.ary_to_string(ary :  LcVal)
        buffer = string_buffer_new
        ary_append(buffer,ary)
        buffer_trunc(buffer)
        return buffer
    end 

    def self.lc_ary_to_s(ary :  LcVal)
        buffer = ary_to_string(ary)
        if buff_size(buffer) > STR_MAX_CAPA
            buffer_dispose(buffer)
            return lc_obj_to_s(ary)
        end
        return build_string_with_ptr(buff_ptr(buffer),buff_size(buffer))
    end

    def self.lc_ary_each(ary :  LcVal)
        arylen = ary_size(ary)
        ptr    = ary_ptr(ary)
        arylen.times do |i|
            Exec.lc_yield(ary_at_index(ary,i))
        end
        Null 
    end

    def self.lc_ary_map(ary :  LcVal)
        arylen = ary_size(ary)
        tmp    = build_ary_new
        arylen.times do |i|
            lc_ary_push(tmp,Exec.lc_yield(ary_at_index(ary,i)))
        end
        return tmp 
    end 

    def self.lc_ary_o_map(ary :  LcVal)
        arylen = ary_size(ary)
        arylen.times do |i|
            ary_set_index(ary,i,Exec.lc_yield(ary_at_index(ary,i)))
        end
        return ary 
    end 

    def self.lc_ary_each_with_index(ary :  LcVal)
        arylen = ary_size(ary)
        ptr    = ary_ptr(ary)
        arylen.times do |i|
            Exec.lc_yield(ptr[i],num2int(i))
            break if Exec.error?
        end
        return Null 
    end

    def self.lc_ary_flatten(ary :  LcVal)
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

    def self.lc_ary_insert(ary :  LcVal, argv :  LcVal)
        argv = lc_cast(argv,Ary)
        x = lc_num_to_cr_i(argv[0])
        return Null unless x.is_a? Intnum
        arylen = ary_size(ary)
        ptr    = ary_ptr(ary)
        if (x > arylen - 1) || (x < 0)
            lc_raise(LcIndexError,"(Index #{x} out of array)")
            return Null 
        elsif x == arylen - 1
            argv.each_with_index do |e,i|
                lc_ary_push(ary,e) unless i == 0
            end
            return ary 
        else 
            elemc = argv.size - 1
            if elemc > 1
                resize_ary_capa(ary,elemc)
            end
            tmp   = ptr + x + elemc 
            tmp.copy_from(ptr + x,arylen - x)
            (x...(x + elemc)).each do |i|
                ary_set_index(ary,i,argv[i - x + 1])
            end 
            return ary 
        end
    end

    def self.lc_ary_eq(ary1 :  LcVal, ary2 :  LcVal)
        return lcfalse unless ary2.is_a? LcArray
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

    def self.lc_ary_swap(ary :  LcVal, i1 :  LcVal, i2 :  LcVal)
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

    def self.lc_ary_map_with_index(ary :  LcVal)
        size = ary_size(ary)
        tmp  = build_ary(size)
        size.times do |i|
            value = Exec.lc_yield(ary_at_index(ary,i),num2int(i)).as( LcVal)
            break if Exec.error?
            ary_set_index(tmp,i,value)
        end
        set_ary_size(tmp,size)
        return tmp
    end 

    def self.lc_ary_o_map_with_index(ary :  LcVal)
        size = ary_size(ary)
        size.times do |i|
            value = Exec.lc_yield(ary_at_index(ary,i),num2int(i)).as( LcVal)
            break if Exec.error?
            ary_set_index(ary,i,value)
        end
        return ary 
    end

    private def self.internal_ary_sort(ary :  LcVal*,size)
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

    def self.lc_ary_sort(ary :  LcVal)
        arylen = ary_size(ary)
        s_ary  = build_ary(arylen)
        set_ary_size(s_ary,arylen)
        tmp    = ary_ptr(s_ary)
        ptr    = ary_ptr(ary)
        tmp.copy_from(ptr,arylen)
        internal_ary_sort(tmp,arylen)
        return s_ary 
    end

    def self.lc_ary_o_sort(ary :  LcVal)
        arylen = ary_size(ary)
        ptr    = ary_ptr(ary)
        internal_ary_sort(ptr,arylen)
        return ary 
    end

    def self.lc_ary_reverse(ary :  LcVal)
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

    def self.lc_ary_o_reverse(ary :  LcVal)
        arylen = ary_size(ary)
        ptr    = ary_ptr(ary)
        (arylen / 2).times do |i|
            ptr.swap(i,arylen - i - 1)
        end
        return ary 
    end

    def self.lc_ary_max(ary :  LcVal)
        arylen = ary_size(ary)
        if arylen > 0
            ptr    = ary_ptr(ary)
            tmp    = Pointer( LcVal).malloc(arylen)
            tmp.copy_from(ptr,arylen)
            internal_ary_sort(tmp,arylen)
            max = tmp[arylen - 1]
            tmp = tmp.realloc(0)
            return max 
        end 
        return Null
    end

    def self.lc_ary_min(ary :  LcVal)
        arylen = ary_size(ary)
        if arylen > 0
            ptr    = ary_ptr(ary)
            tmp    = Pointer( LcVal).malloc(arylen)
            tmp.copy_from(ptr,arylen)
            internal_ary_sort(tmp,arylen)
            min = tmp[0]
            tmp = tmp.realloc(0)
            return min 
        end 
        return Null
    end

    def self.lc_ary_delete_at(ary :  LcVal, index :  LcVal)
        i      = lc_num_to_cr_i(index)
        arylen = ary_size(ary)
        del    = Null
        if i 
            if i >= 0 && i < arylen 
                ptr = ary_ptr(ary)
                del = ptr[i]
                (ptr + i).copy_from(ptr + (i + 1),arylen - i + 1)
                set_ary_size(ary,arylen - 1)
            end 
        end
        return del
    end 

    def self.lc_ary_compact(ary :  LcVal)
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

    def self.lc_ary_o_compact(ary :  LcVal)
        arylen = ary_size(ary)
        ptr    = ary_ptr(ary)
        tmp    = Pointer( LcVal).malloc(arylen)
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

    def self.lc_ary_shift(ary :  LcVal)
        arylen = ary_size(ary)
        return Null if arylen == 0
        ptr    = ary_ptr(ary)
        val    = ptr[0]
        tmp    = Pointer( LcVal).malloc(arylen)
        tmp.copy_from(ptr,arylen)
        ptr.copy_from(tmp + 1, arylen - 1)
        set_ary_size(ary,arylen  -1)
        tmp = tmp.realloc(0)
        return val
    end 

    def self.lc_ary_sort_by(ary :  LcVal)
        arylen = ary_size(ary)
        return ary if arylen < 2
        tmp    = build_ary(ary_total_size(ary))
        set_ary_size(tmp,arylen)
        ary_ptr(tmp).copy_from(ary_ptr(ary),arylen)
        ary_sort_by_m(ary_ptr(tmp),arylen)
        return tmp
    end

    def self.lc_ary_o_sort_by(ary :  LcVal)
        ary_sort_by_m(ary_ptr(ary),ary_size(ary))
        return ary 
    end 

    def self.lc_ary_join(ary :  LcVal, argv :  LcVal)
        argv = argv.as(Ary)
        if argv.empty?
            separator = ""
        else 
            separator = string2cr(argv[0]) || ""
        end 
        buffer     = string_buffer_new
        processing = [{ary,ary_size(ary),0_i64}]
        while !processing.empty?
            frame   = processing.pop
            current = frame[0]  # Array pointer
            length  = frame[1]  # Array size
            i       = frame[2]  # Last index
            ary_iterate_with_index(current,i) do |v,j|
                if v.is_a? LcArray
                    if v == ary
                        lc_raise(LcArgumentError,"Recursive array join") 
                        return Null 
                    end 
                    processing << {current,length,j+1} << {v,ary_size(v),0_i64}
                    buffer_append(buffer,separator) unless v.size == 0
                else
                    buffer_append(buffer,separator) if j > 0
                    string_buffer_appender(buffer,v)
                end 
            end
        end
        buffer_trunc(buffer)
        string = build_string_with_ptr(buff_ptr(buffer),buff_size(buffer))
        if string.size > STR_MAX_CAPA
            lc_raise(LcRuntimeError,"String overflows max length")
            return Null 
        end 
        return build_string(string)
    end 

    def self.lc_ary_from_range(unused,argv :  LcVal)
        argv  = argv.as(Ary)
        range = argv[0]
        step  = argv[1]?
        check_range(range)
        if test(step)
            step = lc_num_to_cr_f(step)
        else
            step = 1.0 
        end
        return Null unless step 
        r_beg = r_left(range)
        r_end = r_right(range)
        if r_beg.is_a? BigInt || r_end.is_a? BigInt
            lc_raise(LcNotSupportedError,"BigInt range is not supported yet")
            return Null
        end
        ary   = build_ary_new 
        if r_beg > r_end 
            return ary
        end 
        tmp       = r_beg
        while tmp <= r_end 
            lc_ary_push(ary,num_auto(tmp))
            tmp +=  step
        end
        return ary
    end        

    def self.init_array
        @@lc_array = internal.lc_build_internal_class("Array")
        define_allocator(@@lc_array,lc_ary_allocate)
    
        lc_add_static(@@lc_array,"from_range",wrap(lc_ary_from_range,2), -2)
    
        lc_add_internal(@@lc_array,"init",           wrap(lc_ary_init,2),            1)
        lc_add_internal(@@lc_array,"+",              wrap(lc_ary_add,2),             1)
        lc_add_internal(@@lc_array,"push",           wrap(lc_ary_push,2),            1)
        alias_method_str(@@lc_array,"push","<<"                                       )
        lc_add_internal(@@lc_array,"pop",            wrap(lc_ary_pop,1),             0)
        lc_add_internal(@@lc_array,"[]",             wrap(lc_ary_index,2),           1)
        lc_add_internal(@@lc_array,"[]=",            wrap(lc_ary_index_assign,3),    2)
        lc_add_internal(@@lc_array,"include?",       wrap(lc_ary_include,2),         1)
        lc_add_internal(@@lc_array,"clone",          wrap(lc_ary_clone,1),           0)
        lc_add_internal(@@lc_array,"first",          wrap(lc_ary_first,1),           0)
        lc_add_internal(@@lc_array,"last",           wrap(lc_ary_last,1),            0)
        lc_add_internal(@@lc_array,"size",           wrap(lc_ary_len,1),             0)
        alias_method_str(@@lc_array,"size","length"                                   )
        lc_add_internal(@@lc_array,"empty?",         wrap(lc_ary_empty,1),           0)
        lc_add_internal(@@lc_array,"to_s",           wrap(lc_ary_to_s,1),            0)
        lc_add_internal(@@lc_array,"each",           wrap(lc_ary_each,1),            0)
        lc_add_internal(@@lc_array,"map",            wrap(lc_ary_map,1),             0)
        lc_add_internal(@@lc_array,"map!",           wrap(lc_ary_o_map,1),           0)
        lc_add_internal(@@lc_array,"flatten",        wrap(lc_ary_flatten,1),         0)
        lc_add_internal(@@lc_array,"insert",         wrap(lc_ary_insert,2),         -2)
        lc_add_internal(@@lc_array,"==",             wrap(lc_ary_eq,2),              1)
        lc_add_internal(@@lc_array,"swap",           wrap(lc_ary_swap,3),            2)
        lc_add_internal(@@lc_array,"sort",           wrap(lc_ary_sort,1),            0)
        lc_add_internal(@@lc_array,"sort!",          wrap(lc_ary_o_sort,1),          0)
        lc_add_internal(@@lc_array,"max",            wrap(lc_ary_max,1),             0)
        lc_add_internal(@@lc_array,"min",            wrap(lc_ary_min,1),             0)
        lc_add_internal(@@lc_array,"reverse",        wrap(lc_ary_reverse,1),         0)
        lc_add_internal(@@lc_array,"reverse!",       wrap(lc_ary_o_reverse,1),       0)
        lc_add_internal(@@lc_array,"shift",          wrap(lc_ary_shift,1),           0)
        lc_add_internal(@@lc_array,"join",           wrap(lc_ary_join,2),           -1)
        lc_add_internal(@@lc_array,"sort_by",        wrap(lc_ary_sort_by,1),         0)
        lc_add_internal(@@lc_array,"sort_by!",       wrap(lc_ary_o_sort_by,1),       0)
        lc_add_internal(@@lc_array,"delete_at",      wrap(lc_ary_delete_at,2),       1)
        lc_add_internal(@@lc_array,"each_with_index",wrap(lc_ary_each_with_index,1), 0)
        lc_add_internal(@@lc_array,"map_with_index", wrap(lc_ary_map_with_index,1),  0)
        lc_add_internal(@@lc_array,"map_with_index!",wrap(lc_ary_o_map_with_index,1),0)
        lc_add_internal(@@lc_array,"compact",        wrap(lc_ary_compact,1),         0)
        lc_add_internal(@@lc_array,"compact!",       wrap(lc_ary_o_compact,1),       0)

        lc_define_const(@@lc_kernel,"ARGV",define_argv)
    end
end    


require "./Wrappers/LcArray"
