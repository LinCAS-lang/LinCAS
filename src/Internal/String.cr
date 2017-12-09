
# Copyright (c) 2017 Massimiliano Dal Mas
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

    STR_MAX_CAPA = 3000

    struct LcString < Base
        def initialize
            @str_ptr = Pointer(Char).null
            @size    = 0
        end
        setter str_ptr
        setter size
        getter str_ptr
        getter size
    end 

    macro set_size(lcStr,size)
        obj_of({{lcStr}}).size = {{size}}
    end

    macro str_size(lcStr)
        obj_of({{lcStr}}).size
    end

    macro resize_str_capacity(lcStr,value)
        st_size  = str_size({{lcStr}})
        final_size = st_size + {{value}}
        if final_size > STR_MAX_CAPA
            # internal.lc_raise()
        end 
        if st_size < final_size
            obj_of({{lcStr}}).str_ptr = obj_of({{lcStr}}).str_ptr.realloc(final_size.to_i)
            set_size({{lcStr}},final_size)
        end 
    end

    macro str_add_char(lcStr,index,char)
        obj_of({{lcStr}}).str_ptr[{{index}}] = {{char}}
    end

    macro str_char_at(lcStr,index)
        obj_of({{lcStr}}).str_ptr[{{index}}]
    end

    macro str_insert()
        
    end

    def self.build_string(value) : LcString*
        str = Pointer.malloc(instance_sizeof(LcString),LcString.new) 
        internal.lc_init_string(str,value)
        return str 
    end
    
    # Initializes a new string trough the keyword 'new' or just
    # assigning it. This is the 'init' method of the class
    # ```
    # str = new String("Foo") #=> "Foo"
    # # same as:
    # str = "Foo" #=> "Foo"
    # ```
    #
    # * argument:: string struct to initialize
    # * argument:: initial string value
    def self.lc_init_string(lcStr : LcString*, value)
        # To implement: argument check
        if value.is_a? LcString*
            resize_str_capacity(lcStr,obj_of(value).size)
            obj_of(lcStr).str_ptr.copy_from(obj_of(value).str_ptr,obj_of(value).size)
        else
            resize_str_capacity(lcStr,value.size)
            value.each_char_with_index do |chr,i|
                str_add_char(lcStr,i,chr)
            end 
        end 
    end

    # Concatenates two strings.
    # This method can be invoked in two ways:
    # ```
    # foo    := "Foo"
    # bar    := "Bar"
    # foobar := foo + bar
    # # same as:
    # foobar := foo.concat(bar)
    # ```
    #
    # * argument:: first string struct to concatenate
    # * argument:: second string struct to concatenate
    # * returns:: new string struct
    def self.lc_str_concat(lcStr : LcString*, str)
        # To implement: argument check
        concated_str = build_string
        strlen1      = str_size(lcStr)
        strlen2      = str_size(str)
        strlen_tot   = strlen1 + strlen2
        resize_str_capacity(concated_str,strlen_tot)
        (0...strlen1).each do |i|
            str_add_char(concated_str,i,str_char_at(lcStr,i))
        end 
        (strlen1...strlen_tot).each do |i|
            str_add_char(concated_str, i, str_char_at(str,i - strlen1))
        end
        return concated_str
    end

    # Performs a multiplication between a string and a number
    # ```
    # bark   := "Bark"
    # bark_3 := bark * 3 #=> "BarkBarkBark"
    def self.lc_str_multiply(lcStr : LcString*,times)
        new_str = build_string 
        strlen  = str_size(lcStr)
        tms     = times #internal.lc_num_to_cr_i(times)
        resize_str_capacity(new_str,strlen * tms)
        set_size(new_str,strlen * tms)
        tms.times do |n|
            (0...strlen).each do |i|
                str_add_char(new_str,n * strlen + i ,str_char_at(lcStr,i))
            end 
        end
        return new_str
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
    def self.lc_str_include(str1 : LcString* ,str2)
        # To implement: argument check
        s_ptr = libc.strstr(obj_of(str1).str_ptr,obj_of(str2).str_ptr)
        if s_ptr.null?
             return lcfalse
        else 
             return lctrue
        end
    end

    # Compares two strings
    # ```
    # bar := "Bar"
    # foo := "Foo"
    # bar == bar #=> true
    # bar == foo #=> false
    # ```
    #
    # * argument:: string on which the method is called
    # * argument:: string to be compared
    # * returns:: true if the two strings equal; false else;
    def self.lc_str_compare(str1 : LcString*, str2)
        # To implement: argument check
        return lcfalse if str_size(str1) != str_size(str2)
        return internal.lc_str_include(str1,str2)
    end

    # Same as lc_str_compare, but it checks if two strings are not equal
    def self.lc_str_icompare(str1 : LcString*, str2)
        # To implement: argument check
        return lc_bool_invert(internal.lc_str_compare(str1,str2))
    end

    def self.lc_str_index(str : LcString*, index)
        x = internal.lc_num_to_cr_i(index)
        if x > obj_of(str).size
            return Null 
        else
            return internal.build_string(obj_of(str).str_ptr[x])
        end
    end

    def self.lc_str_insert(str : LcString*, index, value)
        x = internal.lc_num_to_cr_i(index)
        if x > obj_of(str).size
            # internal.lc_raise()
        else 
            # internal.lc_raise() unless value.is_a? LcString*
            str_size   = str_size(str)
            val_size   = str_size(value)
            final_size = 0
            resize_str_capacity(str,val_size)
            final_size.downto x do |i|
                str_add_char(str,i - 1,str_char_at(i - val_size -1))
            end 
            (x...val_size).each do |i|
                str_add_char(str,i,str_char_at(value,i - val_size))
            end 
        end
    end

    def self.lc_str_set_index(str : LcString*,index,value)
        x = internal.lc_num_to_cr_i(index)
        if x > obj_of(str).size
            # internal.lc_raise()
        else
            # internal.lc_raise() unless value.is_a? LcString*
            if str_s(value) > 1
                # internal.lc_str_insert(str,index,value)
            else 
                obj_of(str).str_ptr[i] = obj_of(value).str_ptr[0]
            end
        end 
    end



    str = build_string("ciao")
    str2 = build_string(str)
    LcKernel.outl(str2)
#    str2 = build_string
#    self.lc_init_string(str2,"a tutti")
#    p self.lc_str_include(str2,str)
#    c = lc_str_multiply(str,3)
#    p self.string_to_cr(c)

end