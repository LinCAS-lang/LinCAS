
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

    class LcString < BaseC
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
        {{lcStr}}.as(LcString).size = {{size}}
    end

    macro str_size(lcStr)
        {{lcStr}}.as(LcString).size.as(Int32)
    end

    macro resize_str_capacity(lcStr,value)
        st_size  = str_size({{lcStr}})
        final_size = st_size + {{value}}
        if final_size > STR_MAX_CAPA
            # internal.lc_raise()
        end 
        if st_size < final_size
            {{lcStr}}.as(LcString).str_ptr = {{lcStr}}.as(LcString).str_ptr.realloc(final_size.to_i)
            set_size({{lcStr}},final_size)
        end 
    end

    macro str_add_char(lcStr,index,char)
        {{lcStr}}.as(LcString).str_ptr[{{index}}] = {{char}}
    end

    macro str_char_at(lcStr,index)
        {{lcStr}}.as(LcString).str_ptr[{{index}}]
    end

    macro str_shift(str,to,index,length)
        (1..{{to}}).each do |i|
            char = str_char_at({{str}},{{index}} + {{to}} - i)
            str_add_char({{str}},{{length}} - i,char)
        end 
    end

    def self.build_string(value)
        str   = LcString.new
        str.klass = StringClass
        str.data  = StringClass.data.clone
        internal.lc_init_string(str,value)
        return str.as(Value)
    end
    
    # Initializes a new string trough the keyword 'new' or just
    # assigning it. This is the 'init' method of the class
    # ```
    # # str = "Foo" #=> "Foo"
    # ```
    #
    # * argument:: string struct to initialize
    # * argument:: initial string value
    def self.lc_init_string(lcStr : Value, value)
        # To implement: argument check
        lcStr = lcStr.as(LcString)
        if value.is_a? LcString
            resize_str_capacity(lcStr,str_size(value))
            lcStr.str_ptr.copy_from(value.str_ptr,str_size(value))
        elsif value.is_a? String
            resize_str_capacity(lcStr,value.as(String).size)
            value.as(String).each_char_with_index do |chr,i|
                str_add_char(lcStr,i,chr)
            end 
        else
            # internal.lc_rasise()
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
    def self.lc_str_concat(lcStr : Value, str)
        # To implement: argument check
        lcStr = lcStr.as(LcString)
        concated_str = build_string("")
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
    def self.lc_str_multiply(lcStr : Value,times)
        lcStr   = lcStr.as(LcString)
        new_str = build_string("")
        strlen  = str_size(lcStr)
        tms     = internal.lc_num_to_cr_i(times)
        return Null unless tms.is_a? Number 
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
    def self.lc_str_include(str1 : Value ,str2)
        # To implement: argument check
        str1  = str1.as(LcString)
        s_ptr = libc.strstr(obj_of(str1).str_ptr,obj_of(str2).str_ptr)
        if s_ptr.null?
             return lcfalse
        else 
             return lctrue
        end
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
    def self.lc_str_compare(str1 : Value, str2)
        str1 = str1.as(LcString)
        return lcfalse unless str2.is_a? LcString
        str2 = str2.as(LcString)
        return lcfalse if str_size(str1) != str_size(str2)
        return internal.lc_str_include(str1,str2)
    end

    # Same as lc_str_compare, but it checks if two strings are different
    def self.lc_str_icompare(str1 : Value, str2)
        # To implement: argument check
        str1 = str1.as(LcString)
        return lc_bool_invert(internal.lc_str_compare(str1,str2))
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
        str = str.as(LcString)
        return internal.build_string(str)
    end

    # Access the string characters at the given index
    # ```
    # str = "A quite long string"
    # str[0]    #=> "A"
    # str[8]    #=> "l"
    # str[2..6] #=> "quite"
    # ```
    #
    # * argument:: string to access
    # * argument:: index
    def self.lc_str_index(str : Value, index)
        str = str.as(LcString)
        if index.is_a? LcRange
            
        else
            x = internal.lc_num_to_cr_i(index)
            if x > obj_of(str).size - 1
                return Null 
            else
                return internal.build_string(obj_of(str).str_ptr[x].to_s)
            end
        end
    end

    # Inserts a second string in the current one
    # ```
    # a = "0234"
    # a.insert(1,"1") #=> "01234"
    # a.insert(5,"5") #=> "012345"
    # a.insert(7,"6") #=> Raises an error
    # ```
    # * argument:: string on which inserting the second one
    # * argument:: index the second string must be inserted at
    # * argument:: string to insert
    def self.lc_str_insert(str : Value, index : Value, value)
        str = str.as(LcString)
#        if value.is_a? Value
            x = internal.lc_num_to_cr_i(index)
            return Null unless x.is_a? Number  
#        else 
#            x = value.as(Num).to_i
#        end
        if x > str_size(str)
            # internal.lc_raise()
            return Null
        else 
            # internal.lc_raise() unless value.is_a? LcString
            st_size    = str_size(str)
            val_size   = str_size(value)
            final_size = 0
            resize_str_capacity(str,val_size)
            str_shift(str,(st_size - x).abs,x,final_size)
            (1..val_size).each do |i|
                char = str_char_at(value,i - 1)
                str_add_char(str,x + i - 1,char)
            end 
        end
    end

    def self.lc_str_set_index(str : Value,index : Value,value)  #=> NOT TESTED YIET
        str = str.as(LcString)
#        if value.is_a? Value
             x = internal.lc_num_to_cr_i(index)
             return Null unless x.is_a? Number  
#        else 
#            x = value.as(Num).to_i
#        end
        if x > str_size(str)
            # internal.lc_raise()
        else
            # internal.lc_raise() unless value.is_a? LcString*
            st_size  = str_size(str)
            val_size = str_size(value)
            if val_size > 1
                final_size = 0
                resize_str_capacity(str,val_size - 1)
                str_shift(str,st_size - index,index + 1,final_size)
            else 
                obj_of(str).hidden.as(LcString).str_ptr[index] = obj_of(value).hidden.as(LcString).str_ptr[0]
            end
        end 
    end


    StringClass = internal.lc_build_class_only("String")
    internal.lc_set_parent_class(StringClass, Obj)

    internal.lc_add_internal(StringClass,"+",      :lc_str_concat,  1)
    internal.lc_add_internal(StringClass,"concat", :lc_str_concat,  1)
    internal.lc_add_internal(StringClass,"*",      :lc_str_multiply,1)
    internal.lc_add_internal(StringClass,"include",:lc_str_include, 1)
    internal.lc_add_internal(StringClass,"==",     :lc_str_compare, 1)
    internal.lc_add_internal(StringClass, "<>",    :lc_str_icompare,1)
    internal.lc_add_internal(StringClass,"clone",  :lc_str_clone,   0)
    internal.lc_add_internal(StringClass,"[]",     :lc_str_index,   1)


a = self.build_string("ciao")
b = self.build_string("Hola")
c = self.build_string("55")
#lc_str_insert(b,4,a)
#lc_str_set_index(b,3,c)
#LcKernel.outl(b)


end