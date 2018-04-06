
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

    MATCH_DATA_HEADER = "#<MatchData: \""
    MATCH_DATA_TAIL   = "\">"

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
        buffer = string_buffer_new
        buffer_append(buffer,MATCH_DATA_HEADER)
        buffer_append(buffer,matched_data(lc_cast(mdata,LcMatchData),0))
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

    def self.lc_mdata_index(mdata : Value,index : Value)
        mdata = lc_cast(mdata,LcMatchData)
        i     = lc_num_to_cr_i(index)
        return Null unless i 
        return Null if i < 0 || i >= get_mdata_size(mdata)
        return Null if match_start(mdata,i) < 0
        return build_string_with_ptr(matched_data(mdata,i))
    end

    mdata_index = LcProc.new do |args|
        next lc_mdata_index(*lc_cast(args,T2))
    end

    MatchDataClass = internal.lc_build_internal_class("MatchData")
    internal.lc_set_parent_class(MatchDataClass,Obj)

    internal.lc_undef_allocator(MatchDataClass)

    internal.lc_add_internal(MatchDataClass,"inspect",mdata_inspect,   0)
    internal.lc_add_internal(MatchDataClass,"to_s",mdata_inspect,      0)
    internal.lc_add_internal(MatchDataClass,"size",mdata_size,         0)
    internal.lc_add_internal(MatchDataClass,"group_size",mdata_gsize_, 0)
    internal.lc_add_internal(MatchDataClass,"[]",mdata_index,          1)
    
    


end