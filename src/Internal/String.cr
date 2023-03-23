
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


module LinCAS::Internal

    #$C String
    # A string is a sequence of UTF-8 characters enclosed 
    # betweend double quotes.
    # 
    # Up to now no special characters have been introduced 
    # (like '\n' or similar) nor particular string options
    # like string interpolation, but they're planned to be implemented in future.
    #  
    # Users must be careful with method aliases: this type has methods
    # which modify the content of a sring, and others which return a new one.
    # The first ones usually end with `!`, but there are some exceptions
    # like `String#[]=`

    STR_MAX_CAPA   = 30000
    END_CHR        = '\u{0}'.ord.to_u8
    alias CHAR_PTR = Pointer(LibC::Char)

    class LcString < LcBase
        @size : IntnumR
        def initialize
            @str_ptr = CHAR_PTR.malloc(1,0).as(CHAR_PTR)
            @size    = IntD.new(0)
        end
        property str_ptr, size
    end 

    macro ptr_init(ptr,length)
        i = 0
        while i < {{length}}
            {{ptr}}[i] = END_CHR
            i += 1
        end
    end

    macro set_size(lcStr,size)
        {{lcStr}}.as(LcString).size = {{size}}
    end

    macro str_size(lcStr)
        {{lcStr}}.as(LcString).size
    end

    macro pointer_of(value)
        {{value}}.as(LcString).str_ptr 
    end

    macro resize_str_capacity(lcStr,value)
        st_len    = str_size({{lcStr}})
        final_size = st_len + {{value}}
        if final_size > STR_MAX_CAPA
            lc_raise(lc_index_err, "String size too big")
            return Null
        else
            {{lcStr}}.as(LcString).str_ptr = pointer_of({{lcStr}}).realloc(final_size.to_i + 1)
            set_size({{lcStr}},final_size)
            {{lcStr}}.as(LcString).str_ptr[final_size.to_i] = 0_u8
        end 
    end

    macro resize_str_capacity_2(str,value)
        if {{value}} > STR_MAX_CAPA
            lc_raise(lc_index_err, "String size too big")
            return Null
        else
            {{str}}.as(LcString).str_ptr = pointer_of({{str}}).realloc({{value}})
            set_size({{str}},{{value}})
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

    macro str_check(string)
        if !({{string}}.is_a? LcString)
            lc_raise(lc_type_err,"No implicit conversion of #{lc_typeof({{string}})} into String")
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
    def self.string2cr(string :  LcVal)
      unless string.is_a? LcString
        lc_raise(lc_type_err,"No implicit conversion of #{lc_typeof(string)} into String")
      end
      return String.new(pointer_of(string))
    end

    @[AlwaysInline]
    def self.str2py(obj :  LcVal)
        lc_bug("(Expecting LcString)") unless obj.is_a? LcString
        ptr = pointer_of(obj)
        return string2py(ptr)
    end

    private def self.compute_total_string_size(array : Array(LcVal))
        size = 0
        array.each do |val|
            if val.is_a? LcString
                size += str_size(val)
            else 
                lc_raise(lc_type_err,"No implicit conversion of #{lc_typeof(val)} into String")
                return -1
            end
        end
        return size 
    end

    private def self.stringify(array : Array(LcVal))
        array.map! do |obj|
            if !obj.is_a? LcString
                Exec.lc_call_fun(obj,"to_s")
            else
                obj 
            end
        end
    end

    def self.new_string
        str = lincas_obj_alloc(
            LcString, 
            @@lc_string, 
            data: IvarTable.new)
        # str   = LcString.new
        # str.klass = @@lc_string
        # str.data  = @@lc_string.data.clone
        str.id    = str.object_id
        return  str 
    end

    def self.build_string(value)
        str   = new_string
        internal.lc_init_string(str,value)
        return str.as( LcVal)
    end

    def self.build_string(value : LibC::Char)
        str = new_string
        resize_str_capacity(str,1)
        pointer_of(str)[0] = value 
        return str.as( LcVal)
    end

    def self.build_string(value : LibC::Char*)
        str = new_string
        strlen = LibC.strlen(value)
        resize_str_capacity(str,strlen)
        pointer_of(str).move_from(value,strlen)
        return str 
    end

    def self.build_string_with_ptr(ptr : LibC::Char*,size : Intnum = -1)
        str = new_string 
        return str if ptr.null?
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
    private def self.string2slice(string :  LcVal)
        return pointer_of(string).to_slice(str_size(string))
    end

    private def self.string_buffer_appender(buffer : String_buffer,value :  LcVal)
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
        elsif value.is_a? LcSymbol 
            buffer_append(buffer,get_sym_origin(value))
        elsif lc_obj_responds_to? value,"inspect"
            string = Exec.lc_call_fun(value,"inspect")
            string_append2(buffer,string)
        else 
            string_append2(buffer,lc_obj_to_s(value))
        end
    end

    @[AlwaysInline]
    private def self.string_append(buffer : String_buffer,value :  LcVal)
        buffer_append_n(buffer,'"',pointer_of(value),'"')
    end

    @[AlwaysInline]
    private def self.string_append2(buffer : String_buffer, value :  LcVal)
        buffer_append(buffer,lc_cast(value,LcString))
    end

    def self.lc_string_allocate(klass :  LcVal)
        return  lincas_obj_alloc LcString, lc_cast(klass, LcClass)
    end
    
    #$I init
    #$U init(string) -> new_string
    #
    # Initializes a new string through the keyword 'new' or just
    # assigning it. This is the 'init' method of the class
    # ```coffee
    # str := "Foo"             #=> Foo
    # str := new String("Foo") #=> Foo
    # ```
    
    # * argument:: string to initialize
    # * argument:: initial value
    def self.lc_init_string(lcStr :  LcVal, value : ( LcVal | String | LibC::Char))
        # To implement: argument check
        lcStr = lcStr.as(LcString)
        if value.is_a? LcString
            sz = str_size(value)
            resize_str_capacity(lcStr,sz)
            pointer_of(lcStr).copy_from(value.str_ptr,sz)
        elsif value.is_a? String
            sz = value.as(String).size
            resize_str_capacity(lcStr,sz)
            set_size(lcStr,sz)
            ptr = pointer_of(lcStr)
            ptr.move_from(value.to_unsafe,sz)
            #ptr[sz] = 0_u8
        else
            lc_raise(
                lc_type_err,
                "No implicit conversion of #{lc_typeof(value.as( LcVal))} into String"
            )
            return Null
        end 
    end

    def self.lincas_concat_literals(size)
        string = String.build do |io|
            size.times do |i|
                obj = yield(i).as(LcString)
                io.write_string(obj.str_ptr.to_slice(obj.size))
            end
        end
        return build_string_recycle string
    end

    #$I +
    #$U str + other_str -> new_str
    #
    # Adds two strings.
    # This method can be invoked in two ways:
    # ```coffee
    # foo    := "Foo"
    # bar    := "Bar"
    # foobar := foo + bar #=> "FooBar"
    # ```
    
    # * argument:: first string to sum
    # * argument:: second string to concatenate
    # * returns:: new string
    def self.lc_str_add(lcStr :  LcVal, str :  LcVal)
        str_check(str)
        concated_str = build_string("")
        strlen1      = str_size(lcStr)
        strlen2      = str_size(str)
        strlen_tot   = strlen1 + strlen2
        resize_str_capacity(concated_str,strlen_tot)
        pointer_of(concated_str).copy_from(pointer_of(lcStr),strlen1)
        (pointer_of(concated_str) + strlen1).copy_from(pointer_of(str),strlen2)
        return concated_str
    end

    #$I concat
    #$U concat(str1,str2,str3...) -> str
    # Concatenates other strings at the given one
    # ```coffee
    # a := "1"
    # a.concat("2")     #=> "12"
    # a.concat("3","4") #=> "1234"
    # ```
    
    # * argument:: first string to concatenate
    # * argument:: other strings to concatenate
    # * returns:: first string
    def self.lc_str_concat(str1 :  LcVal,argv :  LcVal | Array(LcVal))
        argv = argv.as(Ary | Array(LcVal))
        if argv.is_a? Ary
            copy = argv.array_copy
        else
            copy = argv 
        end
        stringify(copy)
        len  = compute_total_string_size(copy)
        return Null unless len > 0
        strlen = str_size(str1)
        resize_str_capacity(str1,len)
        ptr    = pointer_of(str1) + strlen
        copy.each do |str|
            tmp = str_size(str)
            ptr.copy_from(pointer_of(str),tmp)
            ptr += tmp
        end
        return str1 
    end

    #$I *
    #$U str * integer -> new_string
    # Performs a multiplication between a string and a number
    # ```coffee
    # bark   := "Bark"
    # bark_3 := bark * 3 #=> "BarkBarkBark"
    # ```

    def self.lc_str_multiply(lcStr :  LcVal, times :  LcVal)
        new_str = build_string("")
        strlen  = str_size(lcStr)
        tms     = lc_num_to_cr_i(times, IntD).as(IntD)
        return Null unless tms.is_a? Number 
        resize_str_capacity(new_str,strlen * tms)
        set_size(new_str,strlen * tms)
        tms.times do |n|
            (pointer_of(new_str) + n * strlen).copy_from(pointer_of(lcStr),strlen)
        end
        return new_str
    end 

    #$I include?
    #$U include?(string) -> boolean
    # Checks if a substring is contained in another one.
    # ```coffee
    # str := "A cat on the roof"
    # cat := "Cat"
    # str.include?(cat)   #=> true
    # str.include?("bed") #=> false
    # ```
    
    # * argument:: string on which the method is called
    # * argument:: string to be searched
    # * returns:: true if the two strings equal; false else;
    def self.lc_str_include(str1 :  LcVal ,str2 :  LcVal)
        str_check(str2)
        s_ptr = libc.strstr(pointer_of(str1),pointer_of(str2))
        if s_ptr.null?
             return lcfalse
        end
        return lctrue
    end

    #$I ==
    #$U str == other -> boolean
    # Compares two strings or a string with another object
    # ```coffee
    # bar := "Bar"
    # foo := "Foo"
    # bar == bar #=> true
    # bar == foo #=> false
    # bar == 2   #=> false
    # ```
    
    # * argument:: string on which the method is called
    # * argument:: string to be compared
    # * returns:: true if the two strings equal; false else;
    def self.lc_str_compare(str1 :  LcVal, str2 :  LcVal)
        return lcfalse unless str2.is_a? LcString
        return lcfalse if str_size(str1) != str_size(str2)
        return internal.lc_str_include(str1,str2)
    end
    
    # Same as lc_str_compare, but it checks if two strings are different
    def self.lc_str_icompare(str1 :  LcVal, str2 :  LcVal)
        unless str2.is_a? LcString
            lc_raise(
                lc_type_err,
                "No implicit conversion of #{lc_typeof(str2)} into String"
            )
            return Null
        end
        return lc_bool_invert(internal.lc_str_compare(str1,str2))
    end

    #$I clone
    #$U clone() -> new_str
    # Clones a string
    # ```coffee
    # a := "Foo"
    # b := a         # b and a are pointing to the same object
    # # Now b and c are going to point to two different objects
    # c := a.clone() #=> "Foo"
    # ```
    
    # * argument:: string to clone
    # * returns:: new LcString*
    def self.lc_str_clone(str :  LcVal)
        return internal.build_string(str)
    end

    private def self.str_index_range(str : LcString,left : Intnum,right : Intnum,inclusive = true)
        strlen = str_size(str)
        return Null if strlen < left
        return CHAR_PTR.null if strlen == left
        range_size = right - left + (inclusive ? 1 : 0)
        if strlen < left + range_size -1 
            range_size = str_size(str) - left 
        end
        ptr     = CHAR_PTR.malloc(range_size + 1)
        ptr_init(ptr,range_size + 1)
        str_ptr = pointer_of(str)
        i     = 0
        while i < range_size
            ptr[i] = str_ptr[left + i]
            i += 1
        end  
        return ptr
    end

    #$I []
    #$U str[index] -> string or null
    #$U str[range] -> string 
    # Access the string characters at the given index
    # ```coffee
    # str := "A quite long string"
    # str[0]    #=> "A"
    # str[8]    #=> "l"
    # str[2..6] #=> "quite"
    # ```
    
    # * argument:: string to access
    # * argument:: index
    def self.lc_str_index(str :  LcVal, index :  LcVal)
        if index.is_a? LcRange
            left    = index.left 
            right   = index.right
            return Null if left > right 
            ptr = str_index_range(lc_cast(str,LcString),left,right,index.inclusive)
            return ptr if ptr.is_a?  LcVal 
            return build_string_with_ptr(ptr)
        else
            x = internal.lc_num_to_cr_i(index)
            if x 
                if x > str_size(str) - 1 ||  x < 0
                    return Null 
                else
                    return internal.build_string(str_char_at(str,x))
                end
            end
            return Null
        end
    end

    #$I insert
    #$U insert(index,string) -> str
    # Inserts a second string in the current one
    # ```coffee
    # a := "0234"
    # a.insert(1,"1") #=> "01234"
    # a.insert(5,"5") #=> "012345"
    # a.insert(7,"6") #=> Raises an error
    # ```

    # * argument:: string on which inserting the second one
    # * argument:: index the second string must be inserted at
    # * argument:: string to insert
    def self.lc_str_insert(str :  LcVal, index :  LcVal, value :  LcVal)
        x = internal.lc_num_to_cr_i(index)
        return Null unless x.is_a? Number  
        if x > str_size(str) || x < 0
            lc_raise(lc_index_err,"(index #{x} out of String)")
            return Null
        else 
            str_check(value)
            st_size    = str_size(str)
            val_size   = str_size(value)
            final_size = 0
            resize_str_capacity(str,val_size)
            str_shift(str,(st_size - x).abs,x,final_size)
            (pointer_of(str) + x).copy_from(pointer_of(value),val_size)
        end
        return str
    end

    #$I []=
    #$U str[index] = string -> str
    # Sets a char or a set of chars in a specified index
    # ```coffee
    # a    := "Gun"
    # a[0] := "F"    #=> "Fun"
    # a[2] := "fair" #=> "Funfair"
    # a[8] := "!"    #=> Raises an error
    # ```
    
    # * argument:: string on which the method was invoked
    # * argument:: index to insert the character at
    # * argument:: string to assign
    def self.lc_str_set_index(str :  LcVal,index :  LcVal, value :  LcVal)
        x = internal.lc_num_to_cr_i(index)
        return Null unless x.is_a? Number  
        if x > str_size(str) || x < 0
            lc_raise(lc_index_err,"(Index #{x} out of String)")
        else
            str_check(value)
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
        return str
    end

    #$I size
    #$U size() -> integer
    #$U length() -> integer [alias]
    # Returns the string size
    # ```coffee
    # a := "Hello, world"
    # a.size() #=> 12
    # ```
    
    # * argument:: string the method was called on
    def self.lc_str_size(str :  LcVal)
        return num2int(str_size(str))
    end

    #$I upcase!
    #$U upcase!() -> str
    # Performs the upcase on the whole string overwriting the original one
    # ```coffee
    # "foo".upcase!() #=> "FOO"
    # ```
    
    # * argument:: the string the method was called on
    def self.lc_str_upr_o(str :  LcVal)
        strlen = str_size(str)
        ptr     = pointer_of(str)
        ptr.map!(strlen) do |char|
            char.unsafe_chr.upcase.ord.to_u8
        end
        return str
    end

    #$I upcase
    #$U upcase() -> new_string
    # Performs the upcase on the whole string 
    # without overwriting the original one
    # ```coffee
    # "foo".upcase() #=> "FOO"
    # ```
    
    # * argument:: the string the method was called on
    # * returns:: a new upcase string
    def self.lc_str_upr(str :  LcVal)
        strlen = str_size(str)
        ptr    = Pointer(LibC::Char).malloc(strlen)
        s_ptr  = pointer_of(str)
        (0...strlen).each do |i|
            ptr[i] = s_ptr[i].unsafe_chr.upcase.ord.to_u8
        end
        return build_string(ptr)
    end

    #$I lowcase!
    #$U lowcase!() -> str
    # Performs the downcase on the whole string overwriting the original one
    # ```coffee
    # "FOO".lowcase!() #=> "foo"
    # ```
    
    # * argument:: the string the method was called on
    def self.lc_str_lwr_o(str :  LcVal)
        strlen = str_size(str)
        ptr     = pointer_of(str)
        ptr.map!(strlen) do |char|
            char.unsafe_chr.downcase.ord.to_u8
        end
        return str
    end

    #$I lowcase
    #$U lowcase() -> new_string
    # Performs the downcase on the whole string 
    # without overwriting the original one
    # ```coffee
    # "FOO.lowcase() #=> "foo"
    # ```
    
    # * argument:: the string the method was called on
    # * returns:: a new lowercase string
    def self.lc_str_lwr(str :  LcVal)
        strlen = str_size(str)
        ptr    = Pointer(LibC::Char).malloc(strlen)
        s_ptr  = pointer_of(str)
        (0...strlen).each do |i|
            ptr[i] = s_ptr[i].unsafe_chr.downcase.ord.to_u8
        end
        return build_string(ptr)
    end

    #$I split
    #$U split(delimiter := " ") -> array
    # Splits a string according to a specific delimiter, returning an array.
    # If `delimiter` is not specified, a white space will be used
    # ```coffee
    # a := "a,b,c,d"
    # a.split(",") #=> ["a","b","c","d"]
    # ```
    
    # * argument:: string the method was called on
    # * argument:: delimiter
    # * returns:: array containing the splitted substrings
    def self.lc_str_split(str1 :  LcVal, argv :  LcVal)
        argv = argv.as(Ary)
        if !argv.empty?
            str2 = argv[0]
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
        end
        return ary
    end

    #$I to_i
    #$U to_i() -> integer
    # Converts a string into an integer number.
    # Warning: no overflow is checked yet
    # ```coffee
    # "12".to_i()   #=> 12
    # "12x".to_i()  #=> 12
    # "abcd".to_i() #=> 0
    # ```
    
    # * argument:: String to convert
    def self.lc_str_to_i(str :  LcVal)
        return num2int(libc.strtol(pointer_of(str),Pointer(LibC::Char).null,10))
    end

    #$I to_f
    #$U to_f() -> float
    # Converts a string into a float number
    # ```coffee
    # "12".to_f()     #=> 12.0
    # "12.24".to_f()  #=> 12.24
    # "12.ab".to_f()  #=> 12.0
    # "abcd".to_f()   #=> 0.0
    # ```
    
    # * argument:: String to convert
    def self.lc_str_to_f(str :  LcVal)
        return num2float(libc.strtod(pointer_of(str),Pointer(LibC::Char*).null))
    end

    #$I each 
    #$U each(&block) -> str
    # Iterates over each char of the string
    # ```coffee
    # "abcd".each_char() { (chr)
    #     print "Char: ",chr
    #     printl
    # }
    #
    # #=> Char: a
    # #=> Char: b
    # #=> Char: c
    # #=> Char: d
    # ```

    # * argument:: string on which the method is called
    def self.lc_str_each_char(str :  LcVal)
        strlen = str_size(str)
        ptr    = pointer_of(str)
        strlen.times do |i|
            Exec.lc_yield(build_string(ptr[i]))
        end
        return str
    end

    #$I chars
    #$U chars() -> array 
    # Returns an array containing each char of the string
    # ```coffee
    # "abc".chars() #=> ["a","b","c"]
    # ```

    # * argument:: string on which the method is called
    # * returns:: array of chars
    def self.lc_str_chars(str :  LcVal)
        strlen = str_size(str)
        ptr    = pointer_of(str)
        ary    = build_ary(strlen)
        (strlen).times do |i|
            lc_ary_push(ary,build_string(ptr[i]))
        end
        return ary 
    end

    #$I compact
    #$U compact() -> new_str
    # Clones the string and deletes the spaces on this last
    # one
    # ```coffee
    # "Compacting This String".compact() #=> "CompactingThisString"
    # ```
    
    # * argument:: String the method is called on
    def self.lc_str_compact(str :  LcVal)
        strlen = str_size(str)
        ptr    = pointer_of(str)
        tmp    = new_string
        resize_str_capacity(tmp,strlen)
        tmp_ptr = pointer_of(tmp)
        count   = 0
        strlen.times do |i|
            if ptr[i] != ' '.ord.to_u8
                tmp_ptr[count] = ptr[i]
                count += 1
            end
        end
        resize_str_capacity_2(tmp,count)
        return tmp
    end

    #$I compact!
    #$U compact!() -> str
    # Deletes the spaces of str
    # ```coffee
    # "Compacting This String".compact!() #=> "CompactingThisString"
    # ```

    # * argument:: String the method is called on
    # * returns:: self
    def self.lc_str_o_compact(str :  LcVal)
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

    private def self.str_gsub_char(string :  LcVal,char : LibC::Char,sub : LibC::Char*)
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

    private def self.str_gsub_str(string :  LcVal,pattern : CHAR_PTR, sub : CHAR_PTR)
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

    #$I gsub
    #$U gsub(pattern,replacement) -> new_str
    # Returns a new string where every occurrence 
    # of `pattern` is replaced with the content in `replacement`
    # ```coffee
    # "comfort".gsub("o","*")    #=> c*mf*rt
    # "comfort".gsub("com","ef") #=> effort
    # ```

    def self.lc_str_gsub(str :  LcVal,pattern :  LcVal, sub :  LcVal)
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

    private def self.string_starts_with(string :  LcVal,char : LibC::Char)
        return false unless str_size(string) > 0
        return str_char_at(string,0) == char
    end

    private def self.string_starts_with(string1 :  LcVal, string2 :  LcVal)
        strlen = str_size(string2)
        ptr1   = pointer_of(string1)
        ptr2   = pointer_of(string2)
        return libc.memcmp(ptr1,ptr2,strlen) == 0
    end

    #$I starts_with?
    #$U starts_with?(str_beg) -> boolean
    # Returns true if the beginning of `str` matches `str_beg`, 
    # false in all the other cases
    # ```coffee
    # "hola".starts_with? ("h")  #=> true
    # "hola".statrs_with? ("ho") #=> true
    # ```

    def self.lc_str_starts_with(string :  LcVal, other :  LcVal)
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

    @[AlwaysInline]
    private def self.prepare_string_for_sym(string : String)
        return ":\"#{string}\"" if Symbol.needs_quotes? string
        return ":#{string}"
    end


    def self.string_to_symbol(string : String)
        hash   = string.hash 
        sym    = symbol_new(string)
        set_sym_hash(sym,hash)
        register_sym(string,sym)
        return sym
    end

    #$I to_sym
    #$U to_sym() -> symbol
    # Converts `str` into a symbol
    # ```coffee
    # "foo".to_sym() #=> :foo
    # "32".to_sym()  #=> :"32"
    # ```

    def self.lc_str_to_symbol(string :  LcVal)
        string = string2cr(string)
        lc_bug("(String type should always be converted into symbol)") unless string 
        string = prepare_string_for_sym(string)
        return build_symbol(string)
    end

    @[AlwaysInline]
    def self.pystring_to_s(pystr : PyObject)
        if !is_pystring(pystr)
            return build_string(pyobj2string(pystr))
        end
        return build_string(pystring2cstring(pystr))
    end

    #$I hash
    #$U hash() -> integer
    # Return string hash based on length and content
    
    def self.lc_str_hash(str :  LcVal)
        return num2int(string2slice(str).hash.to_i64)
    end

        

    def self.init_string
        @@lc_string = lc_build_internal_class("String")
        lc_set_allocator(@@lc_string,wrap(lc_string_allocate,1))

        lc_add_internal(@@lc_string,"+",       wrap(lc_str_add,2),        1)
        lc_add_internal(@@lc_string,"concat",  wrap(lc_str_concat,2),    -1)
        alias_method_str(@@lc_string,"concat","<<"                         )
        lc_add_internal(@@lc_string,"*",       wrap(lc_str_multiply,2),   1)
        lc_add_internal(@@lc_string,"include?",wrap(lc_str_include,2),    1)
        lc_add_internal(@@lc_string,"==",      wrap(lc_str_compare,2),    1)
        lc_add_internal(@@lc_string, "!=",     wrap(lc_str_icompare,2),   1)
        lc_add_internal(@@lc_string,"clone",   wrap(lc_str_clone,1),      0)
        lc_add_internal(@@lc_string,"[]",      wrap(lc_str_index,2),      1)
        lc_add_internal(@@lc_string,"[]=",     wrap(lc_str_set_index,3),  2)
        lc_add_internal(@@lc_string,"insert",  wrap(lc_str_insert,3),     2)
        lc_add_internal(@@lc_string,"size",    wrap(lc_str_size,1),       0)
        alias_method_str(@@lc_string,"size","length"                       )
        lc_add_internal(@@lc_string,"upcase!", wrap(lc_str_upr_o,1),      0)
        lc_add_internal(@@lc_string,"upcase",  wrap(lc_str_upr,1),        0)
        lc_add_internal(@@lc_string,"lowcase!",wrap(lc_str_lwr_o,1),      0)
        lc_add_internal(@@lc_string,"lowcase", wrap(lc_str_lwr,1),        0)
        lc_add_internal(@@lc_string,"split",   wrap(lc_str_split,2),     -1)
        lc_add_internal(@@lc_string,"to_i",    wrap(lc_str_to_i,1),       0)
        lc_add_internal(@@lc_string,"to_f",    wrap(lc_str_to_f,1),       0)
        lc_add_internal(@@lc_string,"to_s",    wrap(lc_obj_self,1),       0)
        lc_add_internal(@@lc_string,"to_sym",  wrap(lc_str_to_symbol,1),  0)
        lc_add_internal(@@lc_string,"hash",    wrap(lc_str_hash,1),       0)
        lc_add_internal(@@lc_string,"each_char",wrap(lc_str_each_char,1), 0)
        lc_add_internal(@@lc_string,"chars",   wrap(lc_str_chars,1),      0)
        lc_add_internal(@@lc_string,"compact", wrap(lc_str_compact,1),    0)
        lc_add_internal(@@lc_string,"compact!",wrap(lc_str_o_compact,1),  0)
        lc_add_internal(@@lc_string,"gsub",    wrap(lc_str_gsub,3),       2)
        lc_add_internal(@@lc_string,"starts_with",wrap(lc_str_starts_with,2),1)
        
        lc_define_const(@@lc_kernel,"VERSION", define_version)
    end

end