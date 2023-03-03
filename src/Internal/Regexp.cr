
# Copyright (c) 2017-2023 Massimiliano Dal Mas
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


# Regexp class implementation
#
# The algorithm bases on https://github.com/crystal-lang/crystal/blob/master/src/regex.cr
module LinCAS::Internal

    alias Pcre      = LibPCRE::Pcre
    alias PcreExtra = LibPCRE::PcreExtra

    PATTERN  = '\u{0}'.ord.to_u8
    SUB      = "\\0".to_unsafe
    ESCAPE   = '\\'
    SLASH    = '/'
    UTF_8    = Regex::Options::UTF_8
    OPT_NONE = Regex::Options::None
    NO_UTF8_CHECK = Regex::Options::NO_UTF8_CHECK

    INFO_CAPTURECOUNT  = LibPCRE::INFO_CAPTURECOUNT
    INFO_NAMECOUNT     = LibPCRE::INFO_NAMECOUNT
    INFO_NAMEENTRYSIZE = LibPCRE::INFO_NAMEENTRYSIZE
    INFO_NAMETABLE     = LibPCRE::INFO_NAMETABLE

    enum RegexpFlag 
        Uncompiled
        Compiled
    end

    class LcRegexp < LcBase
        @flag     = RegexpFlag::Uncompiled
        @origin   = Pointer(LibC::Char).null
        @compiled = uninitialized Pcre
        @extra    = uninitialized PcreExtra
        @captured = 0
        property origin,compiled,extra,captured,flag
    end

    macro regex_origin(regexp)
        {{regexp}}.as(LcRegexp).origin
    end

    macro set_regex_origin(regexp,origin)
        {{regexp}}.as(LcRegexp).origin = {{origin}}
    end

    macro regex_compiled(regexp)
        {{regexp}}.as(LcRegexp).compiled 
    end

    macro set_regex_compiled(regexp,compiled)
        {{regexp}}.as(LcRegexp).compiled = {{compiled}}
    end

    macro regex_extra(regexp)
        {{regexp}}.as(LcRegexp).extra 
    end

    macro set_regex_extra(regexp,extra)
        {{regexp}}.as(LcRegexp).extra = {{extra}}
    end

    macro regex_captured(regexp)
        {{regexp}}.as(LcRegexp).captured
    end

    macro set_regex_captured(regexp,captured)
        {{regexp}}.as(LcRegexp).captured = {{captured}}
    end

    macro set_regex_flag(regex,flag)
        lc_cast({{regex}},LcRegexp).flag = {{flag}}
    end

    macro regex_flag(regex)
        lc_cast({{regex}},LcRegexp).flag
    end

    macro set_regex_default(regex,origin,compiled,extra,captured)
        set_regex_origin({{regex}},{{origin}})
        set_regex_compiled({{regex}},{{compiled}})
        set_regex_extra({{regex}},{{extra}}) 
        set_regex_captured({{regex}},{{captured}})
        set_regex_flag({{regex}},RegexpFlag::Compiled)
    end

    macro regex_check(regex)
        if !({{regex}}.is_a? LcRegexp)
            lc_raise(lc_type_err,"No impilicit conversion of #{lc_typeof({{regex}})} into Regexp")
            return Null 
        end
        if regex_flag({{regex}}) == RegexpFlag::Uncompiled
            lc_raise(lc_type_err,"Uncompiled regexp")
            return Null 
        end
    end

    def self.build_regex
        return lc_regex_allocate(@@lc_regexp)
    end

    def self.lc_regex_allocate(klass :  LcVal)
        klass = klass.as(LcClass)
        reg   = lincas_obj_alloc LcRegexp, klass
        return reg.as( LcVal)
    end

    def self.lc_regex_initialize(regex :  LcVal, source :  LcVal)
        str_check(source)
        origin   = str_gsub_char(source,PATTERN,SUB)
        compiled = LibPCRE.compile(origin,(OPT_NONE | UTF_8 | NO_UTF8_CHECK),out error, out erroffset,nil)
        if compiled.null?
            lc_raise(lc_arg_err,"#{String.new(error)} at #{erroffset}") 
            return Null 
        end
        extra = LibPCRE.study(compiled, 0, out studyerror)
        if extra.null? && studyerror
            lc_raise(lc_arg_err,String.new(studyerror))
            return Null 
        end
        LibPCRE.full_info(compiled, nil, INFO_CAPTURECOUNT, out captured)
        set_regex_default(regex,origin,compiled,extra,captured)
        return Null
    end

    def self.regex_to_s(regex :  LcVal)
        return regex_origin(regex)
    end

    private def self.lc_regex_to_s(regex :  LcVal)
        origin = regex_to_s(regex)
        if origin.null?
            return build_string("")
        else
            return build_string(origin)
        end
    end

    def self.regex_inspect(regex :  LcVal)
        buffer = string_buffer_new
        origin = regex_origin(regex)
        buffer_append_n(buffer,SLASH,origin.null? ? "" : origin,SLASH)
        buffer_trunc(buffer)
        return buffer
    end

    def self.lc_regex_inspect(regex :  LcVal)
        buffer = regex_inspect(regex)
        return build_string_with_ptr(buff_ptr(buffer),buff_size(buffer))
    end

    def self.lc_regex_match(regex :  LcVal,argv : LcVal)
        argv     = argv.as(Ary)
        string   = argv[0]
        position = argv.size > 1 ? argv[1] : nil
        str_check(string)
        regex_check(regex)
        if position 
            pos = lc_num_to_cr_i(position)
            return Null unless pos
        else 
            pos = 0 
        end
        return Null unless str_size(string) > pos
        pos = pos.to_i32
        arylen   = (regex_captured(regex) + 1) * 3
        ary      = Pointer(Int32).malloc(arylen)
        compiled = regex_compiled(regex)
        extra    = regex_extra(regex)
        str_ptr  = pointer_of(string)
        match = LibPCRE.exec(compiled,extra, str_ptr,str_size(string),pos,(OPT_NONE | NO_UTF8_CHECK),ary, arylen)
        return Null unless match > 0
        return build_match_data(regex,compiled,string,pos.to_i32,ary.to_slice(arylen),regex_captured(regex))
    end

    def self.lc_regex_error(unused,string :  LcVal)
        str_check(string)
        gsub_str = str_gsub_char(string,PATTERN,SUB)
        compiled = LibPCRE.compile(gsub_str,(OPT_NONE | UTF_8 | NO_UTF8_CHECK),out error, out erroffset,nil)
        if compiled 
            return Null 
        end 
        return build_string("#{String.new(error)} at #{erroffset}")
    end

    @[AlwaysInline]
    def self.lc_regex_escape(string : LcVal)
        return lc_regex_escape(nil,string)
    end

    def self.lc_regex_escape(unused,string :  LcVal)
        str_check(string)
        buffer  = string_buffer_new
        string_char_iterate(lc_cast(string,LcString)) do |chr|
            if {' ', '.', '\\', '+', '*', '?', '[',
                '^', ']', '$', '(', ')', '{', '}',
                '=', '!', '<', '>', '|', ':', '-'}.includes? chr 
                buffer_append_n(buffer,ESCAPE,chr)
            else
                buffer_append(buffer,chr)
            end
        end
        buffer_trunc(buffer)
        return build_string_with_ptr(buff_ptr(buffer),buff_size(buffer))
    end

    def self.lc_regex_union(unused,other : LcVal | Array(LcVal))
        other  = other.as(Ary | Array(LcVal))
        buffer = string_buffer_new
        error  = false
        size   = other.size - 1
        other.each_with_index do |value,i|
            if value.is_a? LcRegexp
                buffer_append(buffer,regex_to_s(value))
            elsif value.is_a? LcString
                buffer_append(buffer,pointer_of(value))
            else
                error = true 
                lc_raise(lc_type_err,"Argument must be Regexp or String (#{lc_typeof(value)} given)")
                break 
            end
            buffer_append(buffer,'|') if i < size
        end
        return Null if error
        buffer_trunc(buffer)
        regex  = build_regex
        string = build_string_with_ptr(buff_ptr(buffer),buff_size(buffer))
        lc_regex_initialize(regex,string)
        return regex
    end
    
    def self.lc_regex_sum(regex : LcVal, other : LcVal)
        return lc_regex_union(nil,[regex,other])
    end

    def self.lc_regex_union_part(unused,value :  LcVal)
        if value.is_a? LcString
            return lc_regex_escape(value)
        elsif value.is_a? LcRegexp
            return lc_regex_to_s(value)
        end 
        lc_raise(lc_type_err,"Argument must be Regexp or String (#{lc_typeof(value)} given)")
        return Null
    end

    def self.lc_regex_eq(regex :  LcVal, other :  LcVal)
        return lcfalse unless other.is_a? LcRegexp
        return str_low_l_cmp(regex_origin(regex),regex_origin(other)) ? lctrue : lcfalse 
    end

    def self.lc_regex_name_table(regex :  LcVal)
        compiled  = regex_compiled(regex)
        extra     = regex_extra(regex)
        t_pointer = CHAR_PTR.null
        LibPCRE.full_info(compiled,extra,INFO_NAMECOUNT, out n_count)
        LibPCRE.full_info(compiled,extra,INFO_NAMEENTRYSIZE, out n_entry_size)
        LibPCRE.full_info(compiled,extra,INFO_NAMETABLE, pointerof(t_pointer).as(Pointer(Int32)))
        n_table_size = n_count * n_entry_size
        table        = build_hash
        i            = 0
        while i < n_count
            offset   = i * n_entry_size
            c_num    = (t_pointer[offset].to_i32 << 8) | t_pointer[offset + 1].to_i32
            n_offset = offset + 2
            if 0 <= n_entry_size - 3 <= n_table_size - n_offset
                name = build_string(t_pointer + n_offset)
            else 
                name = build_string("")
            end 
            lc_hash_set_index(table,num2int(c_num),name)
            i += 1
        end
        return table
    end


    def self.init_regexp
        @@lc_regexp = internal.lc_build_internal_class("Regexp")
        define_allocator(@@lc_regexp,lc_regex_allocate)

        add_static_method(@@lc_regexp,"error?",lc_regex_error,          1)
        add_static_method(@@lc_regexp,"escape",lc_regex_escape,         1)
        add_static_method(@@lc_regexp,"union",lc_regex_union,          -1)
        add_static_method(@@lc_regexp,"union_part",lc_regex_union_part, 1)

        add_method(@@lc_regexp,"init",lc_regex_initialize,              1)
        add_method(@@lc_regexp,"to_s",lc_regex_to_s,                    0)
        alias_method_str(@@lc_regexp,"to_s","origin")
        add_method(@@lc_regexp,"inspect",lc_regex_inspect,              0)
        add_method(@@lc_regexp,"match",lc_regex_match,                 -2)
        add_method(@@lc_regexp,"+",lc_regex_sum,                        1)
        add_method(@@lc_regexp,"==",lc_regex_eq,                        1)
        add_method(@@lc_regexp,"name_table",lc_regex_name_table,        0)

        regex_clone = LcProc.new do |args|
            next lc_cast(args,T1)[0]
        end

        lc_add_internal(@@lc_regexp,"clone",regex_clone,                   1)
    end
    
    
end