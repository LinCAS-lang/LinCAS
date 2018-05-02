
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

    MATCH_DATA_HEADER = "#<MatchData:"
    MATCH_DATA_TAIL   = '>'

    class LcMatchData < BaseC
        def initialize(
            @regexp   : Value,
            @captured : LibPCRE::Pcre,
            @string   : Value,
            @position : Int32,
            @ary      : Slice(Int32),
            @g_size   : Int32)
        end
        property regexp,captured,string,position,ary,g_size
    end

    macro mdata_regexp(mdata)
        lc_cast({{mdata}},LcMatchData).regexp
    end

    macro mdata_captured(mdata)
        lc_cast({{mdata}},LcMatchData).captured
    end

    macro mdata_string(mdata)
        lc_cast({{mdata}},LcMatchData).string 
    end

    macro mdata_position(mdata)
        lc_cast({{mdata}},LcMatchData).position
    end

    macro mdata_ary(mdata)
        lc_cast({{mdata}},LcMatchData).ary 
    end

    macro mdata_gsize(mdata)
        lc_cast({{mdata}},LcMatchData).g_size
    end

    macro mdata_check(mdata)
        if !({{mdata}}.is_a? LcMatchData)
            lc_raise(LcTypeError,"No inplicit_conversion of #{lc_typeof({{mdata}})} into MatchData")
            return Null 
        end
    end

    macro get_mdata_size(mdata)
        mdata_gsize({{mdata}}) + 1
    end

    def self.build_match_data(
        regexp   : Value,
        captured : LibPCRE::Pcre,
        string   : Value,
        position : Int32,
        ary      : Slice(Int32),
        g_size   : Int32)

        data = LcMatchData.new(regexp,captured,string,position,ary,g_size).as(Value)
        data.klass = MatchDataClass
        data.data  = MatchDataClass.data.clone
        return data
    end

    @[AlwaysInline]
    private def self.match_start(mdata : LcMatchData,index : Intnum)
        return mdata_ary(mdata)[index * 2]
    end

    @[AlwaysInline]
    private def self.match_finish(mdata : LcMatchData,index : Intnum)
        return mdata_ary(mdata)[index * 2 + 1]
    end

    private def self.matched_data(mdata : LcMatchData,index : Intnum)
        start  = match_start(mdata,index)
        finish = match_finish(mdata,index)
        return CHAR_PTR.null if start < 0
        string = lc_cast(mdata_string(mdata),LcString)
        result = str_index_range(string,start,finish,false)
        if result.is_a? Value 
            return CHAR_PTR.null 
        else
            return result
        end
    end

    def self.lc_mdata_inspect(mdata : Value)
        mdata_check(mdata)
        buffer     = string_buffer_new
        size       = get_mdata_size(mdata)
        regex      = mdata_regexp(mdata)
        name_table = lc_regex_name_table(regex)
        buffer_append(buffer,MATCH_DATA_HEADER)
        size.times do |i|
            index = num2int(i)
            buffer_append(buffer,' ')
            if i > 0
                value = hash_fetch(name_table,index,index)
                if value.is_a? LcInt 
                    string_buffer_appender(buffer,value)
                elsif value.is_a? LcString
                    buffer_append(buffer,pointer_of(value))
                else 
                    #lc_raise_internal()
                end
                buffer_append(buffer,':')
            end 
            string_buffer_appender(buffer,lc_mdata_index(mdata,index))
        end
        buffer_append(buffer,MATCH_DATA_TAIL)
        buffer_trunc(buffer)
        return build_string_with_ptr(buff_ptr(buffer),buff_size(buffer))
    end

    mdata_inspect = LcProc.new do |args|
        next lc_mdata_inspect(*args.as(T1))
    end

    @[AlwaysInline]
    def self.lc_mdata_size(mdata : Value)
        return num2int(get_mdata_size(mdata))
    end

    mdata_size = LcProc.new do |args|
        next lc_mdata_size(*lc_cast(args,T1))
    end

    @[AlwaysInline]
    def self.lc_mdata_string(mdata : Value)
        return mdata_string(mdata)
    end

    mdata_string_ = LcProc.new do |args|
        next lc_mdata_string(*lc_cast(args,T1))
    end

    @[AlwaysInline]
    def self.lc_mdata_gsize(mdata : Value)
        return num2int(mdata_gsize(mdata))
    end

    mdata_gsize_ = LcProc.new do |args|
        next lc_mdata_gsize(*lc_cast(args,T1))
    end

    private def self.mdata_named_index(mdata : Value, index : Value)
        m_start      = -1 
        match        = nil
        ary          = mdata_ary(mdata)
        n_entry_size = LibPCRE.get_stringtable_entries(mdata_captured(mdata),pointer_of(index), out ptr_beg, out ptr_end)
        return Null if n_entry_size < 0
        while ptr_beg <= ptr_end  
            c_number = (ptr_beg[0].to_i32 << 8) | ptr_beg[1].to_i32
            beg      = ary[c_number * 2]
            if beg > m_start
                m_start = beg 
                match   = matched_data(lc_cast(mdata,LcMatchData),c_number)
            end
            ptr_beg += n_entry_size
        end
        if match
            if !match.null?
                return build_string_with_ptr(match)
            end 
        end 
        return Null 
    end

    def self.lc_mdata_index(mdata : Value,index : Value)
        if index.is_a? LcString
            return mdata_named_index(mdata,index)
        elsif index.is_a? LcNum
            mdata = lc_cast(mdata,LcMatchData)
            i     = lc_num_to_cr_i(index)
            return Null unless i 
            return Null if i < 0 || i >= get_mdata_size(mdata)
            return Null if match_start(mdata,i) < 0
            return build_string_with_ptr(matched_data(mdata,i))
        end
        lc_raise(LcTypeError,"Integer or String expected (#{lc_typeof(index)} given)")
        return Null
    end

    mdata_index = LcProc.new do |args|
        next lc_mdata_index(*lc_cast(args,T2))
    end

    def self.lc_mdata_captrured_names(mdata : Value)
        regex      = mdata_regexp(mdata)
        size       = get_mdata_size(mdata)
        range      = 0...size 
        name_table = lc_regex_name_table(regex)
        hash       = build_hash 
        hash_each_key(name_table) do |key|
            index = int2num(key)
            if range.includes? index 
                name = lc_hash_fetch(name_table,key)
                if !hash_has_key(hash,key)
                    lc_hash_set_index(hash,name,lc_mdata_index(mdata,name))
                end 
            end
        end
        return hash
    end

    mdata_c_names = LcProc.new do |args|
        next lc_mdata_captrured_names(*lc_cast(args,T1))
    end

    def self.lc_mdata_to_h(mdata : Value)
        regex      = mdata_regexp(mdata)
        size       = get_mdata_size(mdata)
        range      = 0...size 
        name_table = lc_regex_name_table(regex)
        hash       = build_hash 
        size.times do |i|
            index = num2int(i)
            name  = lc_hash_fetch(name_table,index)
            if test(name) 
                lc_hash_set_index(hash,name,lc_mdata_index(mdata,name)) if !hash_has_key(hash,index)
            else 
                lc_hash_set_index(hash,index,lc_mdata_index(mdata,index))
            end 
        end
        return hash
    end

    mdata_to_h = LcProc.new do |args|
        next lc_mdata_to_h(*lc_cast(args,T1))
    end

    def self.lc_mdata_to_a(mdata : Value)
        ary  = build_ary_new
        size = get_mdata_size(mdata)
        size.times do |i|
            matched = matched_data(lc_cast(mdata,LcMatchData),i)
            lc_ary_push(ary,matched.null? ? Null : build_string_with_ptr(matched))
        end
        return ary
    end

    mdata_to_a = LcProc.new do |args|
        next lc_mdata_to_a(*lc_cast(args,T1))
    end

    def self.lc_mdata_to_s(mdata : Value)
        match = matched_data(lc_cast(mdata,LcMatchData),0)
        return match.null? ? Null : build_string_with_ptr(match)
    end

    mdata_to_s = LcProc.new do |args|
        next lc_mdata_to_s(*lc_cast(args,T1))
    end

    mdata_string_ = LcProc.new do |args|
        string = mdata_string(lc_cast(args,T1)[0])
        next build_string(string)
    end

    mdata_regex = LcProc.new do |args|
        next mdata_regexp(lc_cast(args,T1)[0])
    end

    MatchDataClass = internal.lc_build_internal_class("MatchData")
    internal.lc_set_parent_class(MatchDataClass,Obj)

    internal.lc_undef_allocator(MatchDataClass)

    internal.lc_add_internal(MatchDataClass,"inspect",mdata_inspect,   0)
    internal.lc_add_internal(MatchDataClass,"to_s",mdata_to_s,         0)
    internal.lc_add_internal(MatchDataClass,"size",mdata_size,         0)
    internal.lc_add_internal(MatchDataClass,"group_size",mdata_gsize_, 0)
    internal.lc_add_internal(MatchDataClass,"[]",mdata_index,          1)
    internal.lc_add_internal(MatchDataClass,"captured_names",mdata_c_names,    0)
    internal.lc_add_internal(MatchDataClass,"to_h",mdata_to_h,         0)
    internal.lc_add_internal(MatchDataClass,"to_a",mdata_to_a,         0)
    internal.lc_add_internal(MatchDataClass,"string",mdata_string_,    0)
    internal.lc_add_internal(MatchDataClass,"regexp",mdata_regex,      0)
    
    


end
