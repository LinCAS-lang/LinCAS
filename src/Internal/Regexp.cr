
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


# Regexp class implementation
#
# The algorithm bases on https://github.com/crystal-lang/crystal/blob/master/src/regex.cr
module LinCAS::Internal

    alias Pcre      = LibPCRE::Pcre
    alias PcreExtra = LibPCRE::PcreExtra

    PATTERN  = "\u{0}".to_unsafe.value
    SUB      = "\\0".to_unsafe
    ESCAPE   = '\\'
    SLASH    = '/'
    UTF_8    = Regex::Options::UTF_8
    OPT_NONE = Regex::Options::None
    NO_UTF8_CHECK = Regex::Options::NO_UTF8_CHECK

    INFO_CAPTURECOUNT = LibPCRE::INFO_CAPTURECOUNT

    enum RegexpFlag 
        Uncompiled
        Compiled
    end

    class LcRegexp < BaseC
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
        if regex_flag({{regex}}) == RegexpFlag::Uncompiled
            lc_raise(LcTypeError,"No impilicit conversion of #{lc_typeof({{regex}})} into Regexp")
            return Null 
        end
    end

    def self.build_regex
        return lc_regex_allocator(RegexpClass)
    end

    def self.lc_regex_allocator(klass : Value)
        klass     = klass.as(LcClass)
        reg       = LcRegexp.new
        reg.klass = klass
        reg.data  = klass.data.clone 
        reg.id    = reg.object_id
        return reg.as(Value)
    end

    regex_allocate = LcProc.new do |args|
        next lc_regex_allocator(*args.as(T1))
    end

    def self.lc_regex_initialize(regex : Value, source : Value)
        str_check(source)
        origin   = str_gsub_char(source,PATTERN,SUB)
        compiled = LibPCRE.compile(origin,(OPT_NONE | UTF_8 | NO_UTF8_CHECK),out error, out erroffset,nil)
        if compiled.null?
            lc_raise(LcArgumentError,"#{String.new(error)} at #{erroffset}") 
            return Null 
        end
        extra = LibPCRE.study(compiled, 0, out studyerror)
        if extra.null? && studyerror
            lc_raise(LcArgumentError,String.new(studyerror))
            return Null 
        end
        LibPCRE.full_info(compiled, nil, INFO_CAPTURECOUNT, out captured)
        set_regex_default(regex,origin,compiled,extra,captured)
        return Null
    end

    regex_init = LcProc.new do |args|
        next lc_regex_initialize(*lc_cast(args,T2))
    end

    def self.regex_to_s(regex : Value)
        return regex_origin(regex)
    end

    private def self.lc_regex_to_s(regex : Value)
        return build_string(regex_origin(regex))
    end

    regex_to_s_ = LcProc.new do |args|
        next lc_regex_to_s(*lc_cast(args,T1))
    end

    def self.regex_inspect(regex : Value)
        buffer = string_buffer_new
        buffer_append_n(buffer,SLASH,regex_origin(regex),SLASH)
        buffer_trunc(buffer)
        return buffer
    end

    def self.lc_regex_inspect(regex : Value)
        buffer = regex_inspect(regex)
        return build_string_with_ptr(buff_ptr(buffer),buff_size(buffer))
    end

    regex_inspect_ = LcProc.new do |args|
        next lc_regex_inspect(*lc_cast(args,T1))
    end

    def self.lc_regex_match(regex : Value,string : Value,position : Value? = nil)
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

    regex_match = LcProc.new do |args|
        args = args.as(An)
        next lc_regex_match(args[0],args[1],args[2]?)
    end

    def self.lc_regex_error(string : Value)
        str_check(string)
        gsub_str = str_gsub_char(string,PATTERN,SUB)
        compiled = LibPCRE.compile(gsub_str,(OPT_NONE | UTF_8 | NO_UTF8_CHECK),out error, out erroffset,nil)
        if compiled 
            return Null 
        end 
        return build_string("#{String.new(error)} at #{erroffset}")
    end

    regex_error = LcProc.new do |args|
        next lc_regex_error(lc_cast(args,T2)[1])
    end

    def self.lc_regex_escape(string : Value)
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

    regex_escape = LcProc.new do |args|
        next lc_regex_escape(lc_cast(args,T2)[1])
    end

    def self.lc_regex_union(other : An)
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
                lc_raise(LcTypeError,"Argument must be Regexp or String (#{lc_typeof(value)} given)")
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

    regex_union = LcProc.new do |args|
        args  = lc_cast(args,An)
        args.shift
        next lc_regex_union(args)
    end

    def self.lc_regex_union_part(value)
        if value.is_a? LcString
            return lc_regex_escape(value)
        elsif value.is_a? LcRegexp
            return lc_regex_to_s(value)
        end 
        lc_raise(LcTypeError,"Argument must be Regexp or String (#{lc_typeof(value)} given)")
        return Null
    end

    regex_union_part = LcProc.new do |args|
        next lc_regex_union_part(lc_cast(args,T2)[1])
    end

    def self.lc_regex_eq(regex : Value, other : Value)
        return lcfalse unless other.is_a? LcRegexp
        return str_low_l_cmp(regex_origin(regex),regex_origin(other)) ? lctrue : lcfalse 
    end

    regex_eq = LcProc.new do |args|
        next lc_regex_eq(*lc_cast(args,T2))
    end




    RegexpClass = internal.lc_build_internal_class("Regexp")
    internal.lc_set_parent_class(RegexpClass,Obj)
    internal.lc_set_allocator(RegexpClass,regex_allocate)

    internal.lc_add_static(RegexpClass,"error?",regex_error,   1)
    internal.lc_add_static(RegexpClass,"escape",regex_escape,  1)
    internal.lc_add_static(RegexpClass,"union",regex_union,   -1)
    internal.lc_add_static(RegexpClass,"union_part",regex_union_part,   1)

    internal.lc_add_internal(RegexpClass,"init",regex_init,    1)
    internal.lc_add_internal(RegexpClass,"to_s",regex_to_s_,   0)
    internal.lc_add_internal(RegexpClass,"inspect",regex_inspect_,      0)
    internal.lc_add_internal(RegexpClass,"origin",regex_to_s_, 0)
    internal.lc_add_internal(RegexpClass,"match",regex_match, -1)
    internal.lc_add_internal(RegexpClass,"+",regex_union,      1)
    internal.lc_add_internal(RegexpClass,"==",regex_eq,        1)
    
end