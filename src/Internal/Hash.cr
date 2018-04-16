
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
# limitations under the License..

module LinCAS::Internal

    # Hash Class Implementation
    #
    # The algorithm bases on https://github.com/crystal-lang/crystal/blob/master/src/hash.cr
    # and it is an adaptation of Crystal hash to a sutable one 
    # for LinCAS which is dinamically typed
    
    HASHER = Crystal::Hasher.new 
    PRIMES = Hash::HASH_PRIMES

    MAX_BUCKET_DEPTH = 5
    
    class Entry 
        @next  : Entry? = nil 
        @prev  : Entry? = nil 
        @fore  : Entry? = nil
        def initialize(@key : Value,@hash : UInt64,@value : Value)
        end
        property key,value,prev,fore
        property "next"
    end

    alias  Entries = Pointer(Entry?)

    class LcHash < BaseC
        @size       = 0.as(IntnumR)
        @capa       = 0.as(IntnumR)
        @buckets    = Entries.null
        @first      : Entry? = nil  
        @last       : Entry? = nil
        property size,buckets,capa,first,last
    end

    macro hash_size(hash)
        lc_cast({{hash}},LcHash).size 
    end

    macro set_hash_size(hash,size)
        lc_cast({{hash}},LcHash).size = {{size}}
    end

    macro hash_capa(hash)
        lc_cast({{hash}},LcHash).capa
    end

    macro set_hash_capa(hash,capa)
        lc_cast({{hash}},LcHash).capa = {{capa}}
    end

    macro hash_last(hash)
        lc_cast({{hash}},LcHash).last
    end

    macro set_hash_last(hash,last)
        lc_cast({{hash}},LcHash).last = {{last}}
    end

    macro hash_first(hash)
        lc_cast({{hash}},LcHash).first
    end

    macro set_hash_first(hash,first)
        lc_cast({{hash}},LcHash).first = {{first}}
    end

    macro resize_hash_capa(hash,capa)
        lc_cast({{hash}},LcHash).buckets = hash_buckets({{hash}}).realloc({{capa}})
        set_hash_capa({{hash}},{{capa}})
        clear_buckets({{hash}},{{capa}})
    end

    macro hash_buckets(hash)
        lc_cast({{hash}},LcHash).buckets
    end

    macro clear_buckets(hash,capa)
        ptr = hash_buckets({{hash}})
        {{capa}}.times { |i| ptr[i] = nil }
    end

    macro hash_check(hash)
        if !({{hash}}.is_a? LcHash)
            lc_raise(LcTypeError,"No implicit conversion of #{lc_typeof({{hash}})} into Hash")
            return Null 
        end
    end

    macro new_entry(key,h_key,value)
        Entry.new({{key}},{{h_key}},{{value}}) 
    end

    private def self.get_new_capa(hash : LcHash)
        size = hash_size(hash)
        capa = 8
        PRIMES.each do |n_capa|
            return n_capa if capa > size
            capa <<= 1
        end
        lc_raise(LcRuntimeError,"(Hash table too big)")
        return size + 2
    end

    private def self.hash_append(buffer : String_buffer,hash : Value)
        size   = hash_size(hash) - 1
        buffer_append(buffer,'{')
        hash_iterate_with_index(hash) do |entry,i|
            string_buffer_appender(buffer,entry.key)
            buffer_append(buffer,"=>")
            value = entry.value
            if value.is_a? LcHash
                if value.id == hash.id
                    buffer_append(buffer,"{...}")
                else 
                    hash_append(buffer,entry.value)
                end
            else
                string_buffer_appender(buffer,entry.value)
            end
            buffer_append_n(buffer,',',' ') if i < size
        end
        buffer_append(buffer,'}')
    end

    private def self.fast_hash(item : Value)
        if lc_obj_has_internal_m? item,"hash"
            if item.is_a? LcInt
                value = int2num(item)
                {% if flag? (:fast_math) %}
                    return HASHER.int(value).result
                {% else %}
                    if value.is_a? BigInt
                        return value.to_u64 # FIX THIS
                    else 
                        return HASHER.int(value).result
                    end 
                {% end %}
            elsif item.is_a? LcFloat
                return HASHER.float(float2num(item)).result
            elsif item.is_a? LcString
                return HASHER.bytes(string2slice(item)).result
            end 
            return HASHER.int(item.id).result
        end
        value = lc_num_to_cr_i(Exec.lc_call_fun(item,"hash"))
        if value 
            return value.to_u64
        else
            return HASHER.int(item.id).result
        end 
    ensure
        HASHER.reset
    end

    private def self.fast_compare(v1 : Value,v2 : Value)
        return true if v1.id == v2.id 
        if lc_obj_has_internal_m? v1,"=="
            if v1.is_a? LcInt 
                return bool2val(lc_int_eq(v1,v2))
            elsif v1.is_a? LcFloat
                return bool2val(lc_float_eq(v1,v2))
            elsif v1.is_a? LcString
                return bool2val(lc_str_compare(v1,v2))
            #elsif v1.is_a? Matrix 
            #    return lc_matrix_eq(v1,v2)
            end
            return (Exec.lc_call_fun(v1,"==",v2) == lctrue) ? true : false
        end
        return lc_obj_compare(v1,v2)
    end

    private def self.rehash(hash : LcHash)
        n_capa  = get_new_capa(lc_cast(hash,LcHash))
        resize_hash_capa(hash,n_capa)
        entry_list = hash_last(hash)
        buckets    = hash_buckets(hash)
        while entry_list
            h_key           = fast_hash(entry_list.key)
            index           = bucket_index(h_key,n_capa)
            entry_list.next = buckets[index]
            buckets[index]  = entry_list
            entry_list      = entry_list.prev
        end
    end

    def self.build_hash
        return lc_hash_allocate(HashClass)
    end

    def self.lc_hash_allocate(klass : Value)
        hash = LcHash.new
        klass = lc_cast(klass,LcClass)
        hash.klass = klass 
        hash.data  = klass.data.clone 
        hash.id    = hash.object_id
        lc_hash_init(hash)
        return lc_cast(hash,Value)
    end

    hash_allocator = LcProc.new do |args|
        next lc_hash_allocate(*lc_cast(args,T1))
    end

    def self.lc_hash_init(hash : Value)
        set_hash_capa(hash,11)
        resize_hash_capa(hash,11)
    end

    @[AlwaysInline]
    def self.bucket_index(key : UInt64,capa : IntnumR)
        return key % capa 
    end

    def self.insert_item(hash : Value,key : Value,value : Value,capa : IntnumR) : Entry?
        h_key   = fast_hash(key)
        index   = bucket_index(h_key,capa)
        buckets = hash_buckets(hash)
        entry   = buckets[index]
        if entry
            while entry 
                if fast_compare(entry.key,key)
                    entry.value = value
                    return nil 
                end
                if entry.next 
                    entry = entry.next 
                else
                    return entry.next = new_entry(key,h_key,value)
                end  
            end
        end
        return buckets[index] = new_entry(key,h_key,value)
    end

    def self.lc_hash_set_index(hash : Value,key : Value, value : Value) : Value
        size = hash_size(hash)
        capa = hash_capa(hash)
        if size > capa * MAX_BUCKET_DEPTH
            rehash(lc_cast(hash,LcHash)) 
            capa = hash_capa(hash) 
        end  
        entry = insert_item(hash,key,value,capa)
        return value unless entry 
        size += 1
        set_hash_size(hash,size)
        if last = hash_last(hash)
            last.fore  = entry 
            entry.prev = last 
        end
        set_hash_last(hash,entry)
        first = hash_first(hash)
        set_hash_first(hash,entry) unless first
        return value
    end

    hash_set_index = LcProc.new do |args|
        next lc_hash_set_index(*lc_cast(args,T3))
    end

    @[AlwaysInline]
    def self.hash_empty?(hash : Value)
        return (hash_size(hash) == 0) ? true : false 
    end

    @[AlwaysInline]
    def self.lc_hash_empty(hash : Value)
        return val2bool(hash_empty?(hash))
    end

    hash_empty = LcProc.new do |args|
        next lc_hash_empty(*lc_cast(args,T1))
    end

    private def self.fetch_entry_in_bucket(entry : Entry?,key : Value)
        while entry 
            if fast_compare(entry.key,key)
                return entry 
            end
            entry = entry.next 
        end
        return nil
    end

    def self.hash_fetch(hash : Value,key : Value,default : Value)
        return Null if hash_empty?(hash)
        h_key   = fast_hash(key)
        capa    = hash_capa(hash)
        index   = bucket_index(h_key,capa)
        buckets = hash_buckets(hash)
        entry   = buckets[index]
        entry   = fetch_entry_in_bucket(entry,key)
        return entry ? entry.value : default
    end

    def self.lc_hash_fetch(hash : Value,key : Value)
        return hash_fetch(hash,key,Null)
    end 

    hash_fetch = LcProc.new do |args|
        next lc_hash_fetch(*lc_cast(args,T2))
    end

    private def self.hash_iterate(hash : Value)
        current = hash_first(hash)
        while current 
            ret = yield(current)
            current = current.fore 
        end
    end

    private def self.hash_iterate_with_index(hash : Value)
        current = hash_first(hash)
        i       = 0
        while current 
            yield(current,i)
            current = current.fore 
            i += 1
        end
    end

    private def self.hash_each_key(hash : Value)
        hash_iterate(hash) do |entry|
            yield(entry.key)
        end
    end

    private def self.hash_each_key_with_index(hash : Value)
        count = 0
        hash_iterate(hash) do |entry|
            yield(entry.key,count)
            count += 1
        end
    end

    private def self.hash_each_value(hash : Value)
        hash_iterate(hash) do |entry|
            yield(entry.value)
        end
    end

    private def self.hash_each_value_with_index(has : Value)
        count = 0
        hash_iterate(hash) do |entry|
            yield(entry.value,count)
            count += 1
        end
    end

    def self.lc_hash_inspect(hash : Value)
        buffer = string_buffer_new
        hash_append(buffer,hash)
        buffer_trunc(buffer)
        if buff_size(buffer) > STR_MAX_CAPA
            buffer_dispose(buffer)
            return lc_obj_to_s(hash)
        end
        return build_string_with_ptr(buff_ptr(buffer),buff_size(buffer)) 
    end

    hash_inspect = LcProc.new do |args|
        next lc_hash_inspect(*lc_cast(args,T1))
    end

    def self.lc_hash_each_key(hash : Value)
        hash_each_key(hash) do |key|
            Exec.lc_yield(key)
        end
        return Null
    end

    hash_e_key = LcProc.new do |args|
        next lc_hash_each_key(*lc_cast(args,T1))
    end

    def self.lc_hash_each_value(hash : Value)
        hash_each_value(hash) do |value|
            Exec.lc_yield(value)
        end
        return Null
    end

    hash_e_value = LcProc.new do |args|
        next lc_hash_each_value(*lc_cast(args,T1))
    end

    private def self.hash_has_key(hash : Value, key : Value)
        return false if hash_empty?(hash)
        buckets = hash_buckets(hash)
        capa    = hash_capa(hash)
        h_key   = fast_hash(key)
        index   = bucket_index(h_key,capa)
        entry   = buckets[index]
        return fetch_entry_in_bucket(entry,key) ? true : false
    end

    def self.lc_hash_has_key(hash : Value,key : Value)
        return val2bool(hash_has_key(hash,key))
    end

    hash_h_key = LcProc.new do |args|
        next lc_hash_has_key(*lc_cast(args,T2))
    end

    def self.lc_hash_has_value(hash : Value,value : Value)
        found = lcfalse
        hash_each_value(hash) do |val|
            if fast_compare(val,value)
                found = lctrue
                break 
            end 
        end
        return found 
    end 

    hash_has_v = LcProc.new do |args|
        next lc_hash_has_value(*lc_cast(args,T2))
    end

    def self.lc_hash_key_of(hash : Value,value : Value)
        key = Null
        hash_iterate(hash) do |entry|
            val = entry.value
            if fast_compare(val,value)
                key = entry.key 
                break 
            end 
        end
        return key
    end

    hash_key_of = LcProc.new do |args|
        next lc_hash_key_of(*lc_cast(args,T2))
    end

    def self.lc_hash_keys(hash : Value)
        ary = build_ary_new
        hash_each_key(hash) do |key|
            lc_ary_push(ary,key)
        end
        return ary
    end 

    hash_keys = LcProc.new do |args|
        next lc_hash_keys(*lc_cast(args,T1))
    end

    def self.lc_hash_delete(hash : Value,key : Value)
        capa    = hash_capa(hash)
        h_key   = fast_hash(key)
        index   = bucket_index(h_key,capa)
        buckets = hash_buckets(hash)
        entry   = buckets[index]
        p_entry = nil
        while entry 
            if fast_compare(entry.key,key)
                b_entry = entry.prev 
                f_entry = entry.fore 
                if f_entry 
                    if b_entry
                        b_entry.fore = f_entry
                        f_entry.prev = b_entry
                    else
                        set_hash_first(hash,f_entry)
                        f_entry.prev = nil
                    end
                else 
                    if b_entry
                        b_entry.fore = nil 
                        set_hash_last(hash,b_entry)
                    else 
                        set_hash_first(hash,nil)
                        set_hash_last(hash,nil)
                    end
                end
                if p_entry
                    p_entry.next = entry.next 
                else 
                    buckets[index] = entry.next
                end 
                set_hash_size(hash,hash_size(hash) - 1)
                return entry.value 
            end
            p_entry = entry 
            entry = entry.next
        end
        return Null  
    end 

    hash_delete = LcProc.new do |args|
        next lc_hash_delete(*lc_cast(args,T2))
    end

    def self.lc_hash_clone(hash : Value)
        new_hash = build_hash
        hash_iterate(hash) do |entry|
            lc_hash_set_index(new_hash,entry.key,entry.value)
        end
        return new_hash
    end

    hash_clone = LcProc.new do |args|
        next lc_hash_clone(*lc_cast(args,T1))
    end

    def self.lc_hash_o_merge(hash : Value, h2 : Value)
        hash_check(h2)
        hash_iterate(h2) do |entry|
            lc_hash_set_index(hash,entry.key,entry.value)
        end
        return hash
    end

    hash_o_merge = LcProc.new do |args|
        next lc_hash_o_merge(*lc_cast(args,T2))
    end

    def self.lc_hash_merge(hash : Value,h2 : Value)
       new_hash = lc_hash_clone(hash)
       return lc_hash_o_merge(new_hash,h2)
    end

    hash_merge = LcProc.new do |args|
        next lc_hash_merge(*lc_cast(args,T2))
    end

    hash_size = LcProc.new do |args|
        next num2int(hash_size(lc_cast(args,T1)[0]))
    end

    def self.lc_hash_to_a(hash : Value)
        ary = build_ary_new
        hash_iterate(hash) do |entry|
            tmp = build_ary_new
            lc_ary_push(tmp,entry.key)
            lc_ary_push(tmp,entry.value)
            lc_ary_push(ary,tmp)
        end
        return ary 
    end

    hash_to_a = LcProc.new do |args|
        next lc_hash_to_a(*lc_cast(args,T1))
    end



    HashClass = internal.lc_build_internal_class("Hash")
    internal.lc_set_parent_class(HashClass,Obj)

    internal.lc_set_allocator(HashClass,hash_allocator)

    internal.lc_add_internal(HashClass,"[]=",hash_set_index,  2)
    internal.lc_add_internal(HashClass,"empty?",hash_empty,   0)
    internal.lc_add_internal(HashClass,"fetch",hash_fetch,    1)
    internal.lc_add_internal(HashClass,"[]",hash_fetch,       1)
    internal.lc_add_internal(HashClass,"inspect",hash_inspect,0)
    internal.lc_add_internal(HashClass,"to_s",hash_inspect,   0)
    internal.lc_add_internal(HashClass,"each_key",hash_e_key, 0)
    internal.lc_add_internal(HashClass,"each_value",hash_e_value,    0)
    internal.lc_add_internal(HashClass,"has_key",hash_h_key,  1)
    internal.lc_add_internal(HashClass,"has_value",hash_has_v,1)
    internal.lc_add_internal(HashClass,"key_of",hash_key_of,  1)
    internal.lc_add_internal(HashClass,"keys",hash_keys,      0)
    internal.lc_add_internal(HashClass,"delete",hash_delete,  1)
    internal.lc_add_internal(HashClass,"clone",hash_clone,    0)
    internal.lc_add_internal(HashClass,"merge",hash_merge,    1)
    internal.lc_add_internal(HashClass,"merge!",hash_o_merge, 1)
    internal.lc_add_internal(HashClass,"size",hash_size,      0)
    internal.lc_add_internal(HashClass,"length",hash_size,    0)
    internal.lc_add_internal(HashClass,"to_a",hash_to_a,      0)


end