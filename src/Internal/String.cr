
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

    STR_MAX_CAPA = 30000

    class LcString < BaseC
        def initialize
            @str_ptr = Pointer(LibC::Char).null
            @size    = 0
        end
        property str_ptr, size

<<<<<<< HEAD
        def to_s 
            return String.new(@str_ptr)
        end
=======
>>>>>>> lc-vm
    end 

    macro lc_str2str(str)
        String.new(pointer_of({{str}}))
    end

    macro set_size(lcStr,size)
        {{lcStr}}.as(LcString).size = {{size}}
    end

    macro str_size(lcStr)
        {{lcStr}}.as(LcString).size.as(Int32)
    end

    macro pointer_of(value)
        {{value}}.as(LcString).str_ptr 
    end

    macro resize_str_capacity(lcStr,value)
        st_len    = str_size({{lcStr}})
        final_size = st_len + {{value}}
        if final_size > STR_MAX_CAPA
            lc_raise(LcIndexError, "String size too big")
            return Null
        else
            {{lcStr}}.as(LcString).str_ptr = pointer_of({{lcStr}}).realloc(final_size.to_i)
            set_size({{lcStr}},final_size)
        end 
    end

    macro str_add_char(lcStr,index,char)
        pointer_of({{lcStr}})[{{index}}] = {{char}}
    end

    macro str_char_at(lcStr,index)
        pointer_of({{lcStr}})[{{index}}]
    end

    macro str_shift(str,to,index,length)
        (1..{{to}}).each do |i|
            char = str_char_at({{str}},{{index}} + {{to}} - i)
            str_add_char({{str}},{{length}} - i,char)
        end 
    end

<<<<<<< HEAD
    def self.compute_total_string_size(array : An)
=======
    macro str_check(string)
        if !({{string}}.is_a? LcString)
            lc_raise(LcTypeError,"No implicit conversion of #{lc_typeof({{string}})} into String")
            return Null
        end
    end

    macro check_string(string)
        str_check({{string}})
    end

    macro strcmp(str1,str2)
        libc.strcmp({{str1}},{{str2}})
    end

    @[AlwaysInline]
    def self.string2cr(string : Value)
        unless string.is_a? LcString
            lc_raise(LcTypeError,"No implicit conversion of #{lc_typeof(string)} into String")
            return nil
        else 
            return String.new(pointer_of(string))
        end
    end

    private def self.compute_total_string_size(array : An)
>>>>>>> lc-vm
        size = 0
        array.each do |val|
            if val.is_a? LcString
                size += str_size(val)
            else 
                lc_raise(LcTypeError,"No implicit conversion of #{lc_typeof(val)} into String")
                return -1
            end
        end
        return size 
    end

    def self.string2cr(value : Value)
        value = value.as(LcString)
        ptr   = value.str_ptr
        size  = value.size
        return String.new(pointer_of(value))
    end

    def self.new_string
        str   = LcString.new
        str.klass = StringClass
        str.data  = StringClass.data.clone
        return  str 
    end

    def self.build_string(value)
        str   = new_string
        internal.lc_init_string(str,value)
        return str.as(Value)
    end

    def self.build_string(value : LibC::Char)
        str = new_string
        resize_str_capacity(str,1)
        pointer_of(str)[0] = value 
        return str.as(Value)
    end

    def self.build_string(value : LibC::Char*)
        str = new_string
        strlen = LibC.strlen(value)
        resize_str_capacity(str,strlen)
        pointer_of(str).move_from(value,strlen)
        return str 
    end

<<<<<<< HEAD
    def self.lc_str_io_append(io , value : Value)
        #p value.class;gets
        if value.is_a? LcString 
            io << '"'
            io.write_utf8(pointer_of(value).to_slice(str_size(value)))
            io << '"'
        elsif value.is_a? LcNum 
            io << num2num(value)
        elsif value == Null 
            io << "null"
        elsif value.is_a? LcBool
            io << (value == lctrue ? "true" : "false")
        elsif value.is_a? LcArray
            io << lc_ary_to_s(value)
        elsif lc_obj_responds_to? value,"to_s"
            string = Exec.lc_call_fun(value,"to_s")
            io.write_utf8(pointer_of(string).to_slice(str_size(string)))
        else 
            lc_obj_to_s(value,io)
        end
    end
=======
    def self.build_string_with_ptr(ptr : LibC::Char*,size : Intnum = -1)
        str = new_string
        str.str_ptr = ptr 
        if size > 0
            set_size(str,size)
        else 
            set_size(str,libc.strlen(ptr).to_i64)
        end
        return str
    end

    def self.build_string_with_ptr(ptr : Slice(UInt8))
        str = new_string
        str.str_ptr = ptr.to_unsafe 
        set_size(str,ptr.size)
        return str
    end

    def self.build_string_recycle(string : String)
        str = new_string
        str.str_ptr = string.to_unsafe 
        set_size(str,string.size)
        return str
    end

    def self.string_char_iterate(string : LcString)
        ptr    = pointer_of(string)
        strlen = str_size(string)
        i      = 0
        while i < strlen
            yield(ptr[i].unsafe_chr)
            i += 1
        end
    end

    private def self.str_low_l_cmp(str1 : UInt8*,str2 : UInt8*)
        return false if libc.strlen(str1) != libc.strlen(str2)
        return true if strcmp(str1,str2).zero?
        return false
    end

    @[AlwaysInline]
    private def self.string2slice(string : Value)
        return pointer_of(string).to_slice(str_size(string))
    end

    private def self.string_buffer_appender(buffer : String_buffer,value : Value)
        if value.is_a? LcString 
            string_append(buffer,value)
        elsif value.is_a? LcNum 
            num_append(buffer,value)
        elsif value == Null 
            buffer_append(buffer,"null")
        elsif value.is_a? LcBool
            buffer_append(buffer,value == lctrue ? "true" : "false")
        elsif value.is_a? LcArray
            ary_append(buffer,value)
        elsif lc_obj_responds_to? value,"inspect"
            string = Exec.lc_call_fun(value,"inspect")
            string_append(buffer,string)
        else 
            string_append(buffer,lc_obj_to_s(value))
        end
    end

    @[AlwaysInline]
    private def self.string_append(buffer : String_buffer,value : Value)
        buffer_append_n(buffer,'"',pointer_of(value),'"')
    end

    def self.lc_string_allocate(klass : Value)
        klass     = klass.as(LcClass)
        str       = LcString.new
        str.klass = klass
        str.data  = klass.data.clone
        return  str
    end

    string_allocate = LcProc.new do |args|
        next lc_string_allocate(*args.as(T1))
    end
>>>>>>> lc-vm
    
    # Initializes a new string trough the keyword 'new' or just
    # assigning it. This is the 'init' method of the class
    # ```
    # # str = "Foo" #=> "Foo"
    # ```
    #
    # * argument:: string to initialize
    # * argument:: initial value
    def self.lc_init_string(lcStr : Value, value : (Value | String | LibC::Char))
        # To implement: argument check
        lcStr = lcStr.as(LcString)
        if value.is_a? LcString
            resize_str_capacity(lcStr,str_size(value))
            pointer_of(lcStr).copy_from(value.str_ptr,str_size(value))
        elsif value.is_a? String
            resize_str_capacity(lcStr,value.as(String).size)
            pointer_of(lcStr).move_from(value.to_unsafe,value.size)
        else
            lc_raise(
                LcTypeError,
                "No implicit conversion of #{lc_typeof(value.as(Value))} into String"
            )
            return Null
        end 
    end

    # Adds two strings.
    # This method can be invoked in two ways:
    # ```
    # foo    := "Foo"
    # bar    := "Bar"
    # foobar := foo + bar #=> "FooBar"
    # ```
    #
    # * argument:: first string to sum
    # * argument:: second string to concatenate
    # * returns:: new string
    def self.lc_str_add(lcStr : Value, str : Value)
        unless str.is_a? LcString
            lc_raise(
                LcTypeError,
                "No implicit conversion of #{lc_typeof(str)} into String"
            )
            return Null
        end
        concated_str = build_string("")
        strlen1      = str_size(lcStr)
        strlen2      = str_size(str)
        strlen_tot   = strlen1 + strlen2
        resize_str_capacity(concated_str,strlen_tot)
        pointer_of(concated_str).copy_from(pointer_of(lcStr),strlen1)
        (pointer_of(concated_str) + strlen1).copy_from(pointer_of(str),strlen2)
        return concated_str
    end

    str_add = LcProc.new do |args|
        args = args.as(T2)
        next internal.lc_str_add(*args)
    end

    # Concatenates other strings at the given one
    # ```
    # a := "1"
    # a.concat("2")     #=> "12"
    # a.concat("3","4") #=> "1234"
    # ```
    #
    # * argument:: first string to concatenate
    # * argument:: other strings to concatenate
    # * returns:: first string
    def self.lc_str_concat(str1 : Value, str2 : An)
        len = compute_total_string_size(str2)
        return Null unless len > 0
        strlen = str_size(str1)
        resize_str_capacity(str1,len)
        ptr    = pointer_of(str1) + strlen
        str2.each do |str|
            tmp = str_size(str)
            ptr.copy_from(pointer_of(str),tmp)
            ptr += tmp
        end
        return str1 
    end

    str_concat = LcProc.new do |args|
        args = args.as(An)
        arg1 = args[0]
        args.shift
        next internal.lc_str_concat(arg1,args)
    end

    # Performs a multiplication between a string and a number
    # ```
    # bark   := "Bark"
    # bark_3 := bark * 3 #=> "BarkBarkBark"
    # ```
    def self.lc_str_multiply(lcStr : Value, times : Value)
        new_str = build_string("")
        strlen  = str_size(lcStr)
        tms     = internal.lc_num_to_cr_i(times)
        return Null unless tms.is_a? Number 
        resize_str_capacity(new_str,strlen * tms)
        set_size(new_str,strlen * tms)
        tms.times do |n|
            (pointer_of(new_str) + n * strlen).copy_from(pointer_of(lcStr),strlen)
        end
        return new_str
    end 

    str_multiply = LcProc.new do |args|
        args = args.as(T2)
        next internal.lc_str_multiply(*args)
    end

    # Checks if a substring is contained in another one.
    # It works making a call like this:
    # ```
    # str := "A cat on the roof"
    # cat := "Cat"
    # str.include(cat)   #=> true
    # str.include("bed") #=> false
    # ```
    #
    # * argument:: string on which the method is called
    # * argument:: string to be searched
    # * returns:: true if the two strings equal; false else;
    def self.lc_str_include(str1 : Value ,str2 : Value)
        unless str2.is_a? LcString
            lc_raise(
                LcTypeError,
                "No implicit conversion of #{lc_typeof(str2)} into String"
            )
            return Null
        end
        s_ptr = libc.strstr(pointer_of(str1),pointer_of(str2))
        if s_ptr.null?
             return lcfalse
        end
        return lctrue
    end

    str_include = LcProc.new do |args|
        args = args.as(T2)
        next internal.lc_str_include(*args)
    end

    # Compares two strings or a string with another object
    # ```
    # bar := "Bar"
    # foo := "Foo"
    # bar == bar #=> true
    # bar == foo #=> false
    # bar == 2   #=> false
    # ```
    #
    # * argument:: string on which the method is called
    # * argument:: string to be compared
    # * returns:: true if the two strings equal; false else;
    def self.lc_str_compare(str1 : Value, str2 : Value)
        return lcfalse unless str2.is_a? LcString
        return lcfalse if str_size(str1) != str_size(str2)
        return internal.lc_str_include(str1,str2)
    end

    str_compare = LcProc.new do |args|
        args = args.as(T2)
        internal.lc_str_compare(*args)
    end

    # Same as lc_str_compare, but it checks if two strings are different
    def self.lc_str_icompare(str1 : Value, str2 : Value)
        unless str2.is_a? LcString
            lc_raise(
                LcTypeError,
                "No implicit conversion of #{lc_typeof(str2)} into String"
            )
            return Null
        end
        return lc_bool_invert(internal.lc_str_compare(str1,str2))
    end

    str_icompare = LcProc.new do |args|
        args = args.as(T2)
        next internal.lc_str_icompare(*args)
    end

    # Clones a string
    #
    # ```
    # a := "Foo"
    # b := a         # b and a are pointing to the same object
    # # Now b and c are going to point to two different objects
    # c := a.clone() #=> "Foo"
    # ```
    #
    # * argument:: string to clone
    # * returns:: new LcString*
    def self.lc_str_clone(str : Value)
        return internal.build_string(str)
    end

    str_clone = LcProc.new do |args|
        args = args.as(T1)
        next internal.lc_str_clone(args[0])
    end

    # Access the string characters at the given index
    # ```
    # str := "A quite long string"
    # str[0]    #=> "A"
    # str[8]    #=> "l"
    # str[2..6] #=> "quite"
    # ```
    #
    # * argument:: string to access
    # * argument:: index
    def self.lc_str_index(str : Value, index : Value)
        if index.is_a? LcRange
            strlen = str_size(str)
            return Null if index.left > index.right 
            left    = index.left 
            right   = index.right
            return Null if strlen < left
            return build_string("") if strlen == left
            range_size = right - left + (index.inclusive ? 1 : 0)
            if strlen < left + range_size -1 
                range_size = str_size(str) - left 
            end
            new_str = new_string
            resize_str_capacity(new_str, range_size)
            pointer_of(new_str).copy_from(pointer_of(str) + left,range_size)
            return new_str
        else
            x = internal.lc_num_to_cr_i(index)
            if x 
                if x > str_size(str) - 1 ||  x < 0
                    return Null 
                else
                    return internal.build_string(str_char_at(str,x))
                end
            end
        end
    end

    str_index = LcProc.new do |args|
        args = args.as(T2)
        next internal.lc_str_index(*args)
    end

    # Inserts a second string in the current one
    # ```
    # a := "0234"
    # a.insert(1,"1") #=> "01234"
    # a.insert(5,"5") #=> "012345"
    # a.insert(7,"6") #=> Raises an error
    # ```
    # * argument:: string on which inserting the second one
    # * argument:: index the second string must be inserted at
    # * argument:: string to insert
    def self.lc_str_insert(str : Value, index : Value, value : Value)
        x = internal.lc_num_to_cr_i(index)
        return Null unless x.is_a? Number  
        if x > str_size(str) || x < 0
            lc_raise(LcIndexError,"(index #{x} out of String)")
            return Null
        else 
            unless value.is_a? LcString
                lc_raise(
                    LcTypeError,
                    "No implicit conversion of #{lc_typeof(value)} into String"
                ) 
                return Null 
            end
            st_size    = str_size(str)
            val_size   = str_size(value)
            final_size = 0
            resize_str_capacity(str,val_size)
            str_shift(str,(st_size - x).abs,x,final_size)
            (pointer_of(str) + x).copy_from(pointer_of(value),val_size)
        end
        return str
    end

    str_insert = LcProc.new do |args|
        args = args.as(T3)
        next internal.lc_str_insert(*args)
    end

    # Sets a char or a set of chars in a specified index
    # ```
    # a    := "Gun"
    # a[0] := "F"    #=> "Fun"
    # a[2] := "fair" #=> "Funfair"
    # a[8] := "!"    #=> Raises an error
    # ```
    #
    # * argument:: string on which the method was invoked
    # * argument:: index to insert the character at
    # * argument:: string to assign
    def self.lc_str_set_index(str : Value,index : Value, value : Value)
        x = internal.lc_num_to_cr_i(index)
        return Null unless x.is_a? Number  
        if x > str_size(str) || x < 0
            lc_raise(LcIndexError,"(Index #{x} out of String)")
        else
            unless value.is_a? LcString
                lc_raise(
                    LcTypeError,
                    "No implicit conversion of #{lc_typeof(value)} into String"
                ) 
                return Null 
            end
            st_size  = str_size(str)
            val_size = str_size(value)
            if val_size > 1
                final_size = 0
                resize_str_capacity(str,val_size - 1)
                (pointer_of(str) + (x + val_size - 1)).copy_from(pointer_of(str) + x,val_size - 1)
                (pointer_of(str) + x - 1).copy_from(pointer_of(value),val_size)
            else 
                str_add_char(pointer_of(str),x,str_char_at(value,0))
            end
        end 
        return Null 
    end

    str_set_index = LcProc.new do |args|
        next internal.lc_str_set_index(*args.as(T3))
    end

    # Returns the string size
    # ```
    # a := "Hello, world"
    # a.size() #=> 12
    # ```
    #
    # * argument:: string the method was called on
    def self.lc_str_size(str : Value)
        return num2int(str_size(str))
    end

    str_size = LcProc.new do |args|
        next num2int(str_size(args.as(T1)[0]))
    end

    # Performs the upcase on the whole string overwriting the original one
    # ```
    # "foo".o_upcase() #=> "FOO"
    # ```
    #
    # * argument:: the string the method was called on
    def self.lc_str_upr_o(str : Value)
        strlen = str_size(str)
        ptr     = pointer_of(str)
        ptr.map!(strlen) do |char|
            char.unsafe_chr.upcase.ord.to_u8
        end
        return str
    end

    str_upr_o = LcProc.new do |args|
        next internal.lc_str_upr_o(*args.as(T1))
    end

    # Performs the upcase on the whole string 
    # without overwriting the original one
    # ```
    # "foo".o_upcase() #=> "FOO"
    # ```
    #
    # * argument:: the string the method was called on
    # * returns:: a new upcase string
    def self.lc_str_upr(str : Value)
        strlen = str_size(str)
        ptr    = Pointer(LibC::Char).malloc(strlen)
        s_ptr  = pointer_of(str)
        (0...strlen).each do |i|
            ptr[i] = s_ptr[i].unsafe_chr.upcase.ord.to_u8
        end
        return build_string(ptr)
    end

    str_upr = LcProc.new do |args|
        next internal.lc_str_upr(*args.as(T1))
    end

    # Performs the downcase on the whole string overwriting the original one
    # ```
    # "FOO.o_lowcase() #=> "foo"
    # ```
    #
    # * argument:: the string the method was called on
    def self.lc_str_lwr_o(str : Value)
        strlen = str_size(str)
        ptr     = pointer_of(str)
        ptr.map!(strlen) do |char|
            char.unsafe_chr.downcase.ord.to_u8
        end
        return str
    end

    str_lwr_o = LcProc.new do |args|
        next internal.lc_str_lwr_o(*args.as(T1))
    end

    # Performs the downcase on the whole string 
    # without overwriting the original one
    # ```
    # "FOO.o_lowcase() #=> "foo"
    # ```
    #
    # * argument:: the string the method was called on
    # * returns:: a new lowercase string
    def self.lc_str_lwr(str : Value)
        strlen = str_size(str)
        ptr    = Pointer(LibC::Char).malloc(strlen)
        s_ptr  = pointer_of(str)
        (0...strlen).each do |i|
            ptr[i] = s_ptr[i].unsafe_chr.downcase.ord.to_u8
        end
        return build_string(ptr)
    end

    str_lwr = LcProc.new do |args|
        next internal.lc_str_lwr(*args.as(T1))
    end


    # Splits a string according to a specific delimiter, returning an array
    # ```
    # a := "a,b,c,d"
    # a.split(",") #=> ["a","b","c","d"]
    # ```
    #
    # * argument:: string the method was called on
    # * argument:: delimiter
    # * returns:: array containing the splitted substrings
<<<<<<< HEAD
    def self.lc_str_split(str1 : Value, str2 : Value = build_string(" "))
        unless str2.is_a? LcString
            lc_raise(
                LcTypeError,
                "No implicit conversion of #{lc_typeof(str2)} into String"
            ) 
            return Null 
        end 
        strlen  = str_size(str1)
        strlen2 = str_size(str2)
        ptr     = Pointer(LibC::Char).malloc(strlen).copy_from(pointer_of(str1),strlen)
        ptr2    = pointer_of(str2)
        ary = build_ary_new nil 
        beg = 0
        final_address = ptr + strlen
        while beg < strlen
            tmp = libc.strtok(ptr.clone,ptr2)
            if tmp.null? 
                lc_ary_push(ary,str1)
                return ary 
            end 
            str = build_string(tmp)
            lc_ary_push(ary,str)
            beg += libc.strlen(tmp) + strlen2
            ptr = Pointer(LibC::Char).malloc(strlen).copy_from(
                pointer_of(str1) + beg ,strlen - beg
            ) unless beg > strlen  
=======
    def self.lc_str_split(str1 : Value, str2 : Value? = nil)
        if str2
            str_check(str2)
            ptr2 = pointer_of(str2)
            len  = str_size(str2) 
        else
            ptr2 = " ".to_unsafe
            len  = 1
        end
        beg_ptr = pointer_of(str1)
        end_ptr = beg_ptr + str_size(str1)
        ary     = build_ary_new
        i       = 0
        j       = 0
        while beg_ptr <= end_ptr
            if libc.memcmp(beg_ptr,ptr2,len) == 0 || beg_ptr == end_ptr
                unless i == j
                    str = str_index_range(lc_cast(str1,LcString),j,i,false)
                    if str.is_a? CHAR_PTR
                        str = build_string_with_ptr(str)
                    else
                        str = Null 
                    end
                    lc_ary_push(ary,str)
                end
                unless beg_ptr > end_ptr
                    beg_ptr += len 
                    i       += len
                    j        = i
                end
            else 
                beg_ptr += 1
                i += 1 
            end
>>>>>>> lc-vm
        end
        return ary 
    end

    str_split = LcProc.new do |args|
        next internal.lc_str_split(*args.as(T2))
    end

    # Converts a string into an integer number
    # ```
    # "12".to_i   #=> 12
    # "12x".to_i  #=> 12
    # "abcd".to_i #=> 0
    #
    # * argument:: String to convert
    def self.lc_str_to_i(str : Value)
        return num2int(libc.strtol(pointer_of(str),Pointer(LibC::Char).null,10))
    end

    str_to_i = LcProc.new do |args|
        next internal.lc_str_to_i(*args.as(T1))
    end

    # Converts a string into an integer number
    # ```
    # "12".to_f     #=> 12.0
    # "12.24".to_f  #=> 12.24
    # "12.ab".to_f  #=> 12.0
    # "abcd".to_i   #=> 0.0
    #
    # * argument:: String to convert
    def self.lc_str_to_f(str : Value)
        return num2float(libc.strtod(pointer_of(str),Pointer(LibC::Char*).null))
    end

    str_to_f = LcProc.new do |args|
        next internal.lc_str_to_f(*args.as(T1))
    end

    # Iterates over each char of the string
    # ```
    # "abcd".each_char() { (chr)
    #     print "Char: ",chr
    #     printl
    # }
    #
    # #=> Char: a
    # #=> Char: b
    # #=> Char: c
    # #=> Char: d
    #
    # * argument:: string on which the method is called
    def self.lc_str_each_char(str : Value)
        strlen = str_size(str)
        ptr    = pointer_of(str)
        strlen.times do |i|
            Exec.lc_yield(build_string(ptr[i]))
        end
    end

    str_each_char = LcProc.new do |args|
        next internal.lc_str_each_char(*args.as(T1))
    end

    # Returns an array containing each char of the string
    # ```
    # "abc".chars() #=> ["a","b","c"]
    # ```
    # * argument:: string on which the method is called
    def self.lc_str_chars(str : Value)
        strlen = str_size(str)
        ptr    = pointer_of(str)
        ary    = build_ary(strlen)
        (strlen).times do |i|
            lc_ary_push(ary,build_string(ptr[i]))
        end
        return ary 
    end

    str_chars = LcProc.new do |args|
        next internal.lc_str_chars(*args.as(T1))
    end


<<<<<<< HEAD


    StringClass = internal.lc_build_class_only("String")
    internal.lc_set_parent_class(StringClass, Obj)
=======
    # Deletes the spaces of a string
    # ```
    # "Compacting This String".compact!() #=> "CompactingThisString"
    # ```
    # * argument:: String the method is called on
    # * returns:: self
    def self.lc_str_o_compact(str : Value)
        strlen = str_size(str)
        ptr    = pointer_of(str)
        tmp    = Pointer(LibC::Char).malloc(strlen)
        count  = 0
        strlen.times do |i|
            if ptr[i] != ' '.ord.to_u8
                tmp[count] = ptr[i]
                count += 1
            end
        end
        ptr.copy_from(tmp,count)
        resize_str_capacity_2(str,count)
        tmp = tmp.realloc(0)
        return str 
    end

    str_o_compact = LcProc.new do |args|
        next internal.lc_str_o_compact(*args.as(T1))
    end

    private def self.str_gsub_char(string : Value,char : LibC::Char,sub : LibC::Char*)
        buffer = string_buffer_new
        strlen = str_size(string)
        ptr    = pointer_of(string)
        i      = 0
        while i < strlen
            if ptr[i] == char 
                buffer_append(buffer,sub)
            else
                buffer_append(buffer,ptr[i])
            end 
            i += 1
        end
        return buff_ptr(buffer)
    end

    private def self.str_gsub_str(string : Value,pattern : CHAR_PTR, sub : CHAR_PTR)
        buffer = string_buffer_new
        strlen = str_size(string)
        ptr    = pointer_of(string)
        len    = libc.strlen(pattern)
        i      = 0
        while i < strlen
            if libc.memcmp(ptr,pattern,len) == 0
                buffer_append(buffer,sub)
                i   += len
                ptr += len
            else
                buffer_append(buffer,ptr[0])
                i   += 1
                ptr += 1
            end
        end
        buffer_trunc(buffer)
        return buffer
    end

    def self.lc_str_gsub(str : Value,pattern : Value, sub : Value)
        str_check(pattern)
        str_check(sub)
        return str if str_size(pattern) == 0
        if str_size(pattern) == 1
            return build_string_with_ptr(str_gsub_char(str,pointer_of(pattern)[0],pointer_of(sub)))
        else
            buffer = str_gsub_str(str,pointer_of(pattern),pointer_of(sub))
            return build_string_with_ptr(buff_ptr(buffer),buff_size(buffer))
        end
    end

    str_gsub = LcProc.new do |args|
        next lc_str_gsub(*lc_cast(args,T3))
    end

    private def self.string_starts_with(string : Value,char : LibC::Char)
        return false unless str_size(string) > 0
        return str_char_at(string,0) == char
    end

    private def self.string_starts_with(string1 : Value, string2 : Value)
        strlen = str_size(string2)
        ptr1   = pointer_of(string1)
        ptr2   = pointer_of(string2)
        return libc.memcmp(ptr1,ptr2,strlen) == 0
    end

    def self.lc_str_starts_with(string : Value, other : Value)
        str_check(other)
        strlen1 = str_size(string)
        strlen2 = str_size(other)
        return lctrue if (strlen1 == 0 && strlen2 == 0) || strlen2 == 0
        return lcfalse if strlen1 == 0
        if strlen2 > 1
            return string_starts_with(string,other) ? lctrue : lcfalse
        else
            ptr2 = pointer_of(other)
            return string_starts_with(string,ptr2[0]) ? lctrue : lcfalse 
        end
    end

    str_s_with = LcProc.new do |args|
        next lc_str_starts_with(*lc_cast(args,T2))
    end


        




    StringClass = internal.lc_build_internal_class("String")
    internal.lc_set_allocator(StringClass,string_allocate)

>>>>>>> lc-vm

    internal.lc_add_internal(StringClass,"+",      str_add,     1)
    internal.lc_add_internal(StringClass,"concat", str_concat, -1)
    internal.lc_add_internal(StringClass,"*",      str_multiply,1)
    internal.lc_add_internal(StringClass,"include?",str_include,1)
    internal.lc_add_internal(StringClass,"==",     str_compare, 1)
    internal.lc_add_internal(StringClass, "!=",    str_icompare,1)
    internal.lc_add_internal(StringClass,"clone",  str_clone,   0)
    internal.lc_add_internal(StringClass,"[]",     str_index,   1)
    internal.lc_add_internal(StringClass,"[]=",    str_set_index,2)
    internal.lc_add_internal(StringClass,"insert", str_insert,  2)
    internal.lc_add_internal(StringClass,"size",   str_size,    0)
    internal.lc_add_internal(StringClass,"length", str_size,    0)
    internal.lc_add_internal(StringClass,"upcase!",str_upr_o,   0)
    internal.lc_add_internal(StringClass,"upcase", str_upr,     0)
    internal.lc_add_internal(StringClass,"lowcase!",str_lwr_o,  0)
    internal.lc_add_internal(StringClass,"lowcase",str_lwr,     0)
    internal.lc_add_internal(StringClass,"split",  str_split,   1)
    internal.lc_add_internal(StringClass,"to_i",   str_to_i,    0)
    internal.lc_add_internal(StringClass,"to_f",   str_to_f,    0)
<<<<<<< HEAD
    internal.lc_add_internal(StringClass,"each_char",str_each_char,0)
    internal.lc_add_internal(StringClass,"chars",  str_chars,   0)
=======
    internal.lc_add_internal(StringClass,"each_char",str_each_char, 0)
    internal.lc_add_internal(StringClass,"chars",  str_chars,       0)
    internal.lc_add_internal(StringClass,"compact",str_compact,     0)
    internal.lc_add_internal(StringClass,"compact!",  str_o_compact,0)
    internal.lc_add_internal(StringClass,"gsub",      str_gsub,     2)
    internal.lc_add_internal(StringClass,"starts_with",str_s_with,  1)
>>>>>>> lc-vm


end