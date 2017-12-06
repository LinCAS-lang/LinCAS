
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

    class LcString #< Base
        def initialize
            @str_ptr = Pointer(Char).null
            @size    = Pointer(UInt32).malloc(1,0.to_u32) 
        end
        setter str_ptr
        setter size
        getter str_ptr
        getter size
    end

    macro build_string
        # To implement
        LcString.new 
    end 

    macro set_size(lcStr,size)
        {{lcStr}}.size[0] = {{size}}
    end

    macro str_size(lcStr)
        {{lcStr}}.size[0]
    end

    macro resize_capacity(lcStr,value)
        st_size  = str_size({{lcStr}})
        final_size = st_size + {{value}}
        if st_size < final_size
            {{lcStr}}.str_ptr = {{lcStr}}.str_ptr.realloc(final_size.to_i)
            set_size({{lcStr}},final_size)
        end 
    end

    macro str_add_char(lcStr,index,char)
        {{lcStr}}.str_ptr[{{index}}] = {{char}}
    end

    macro str_char_at(lcStr,index)
        {{lcStr}}.str_ptr[{{index}}]
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
    def self.lc_init_string(lcStr : LcString, value)
        # To implement: argument check
        resize_capacity(lcStr,value.size)
        value.each_char_with_index do |chr,i|
            str_add_char(lcStr,i,chr)
        end 
    end

    # Concatenates two strings.
    # This method can be invoked in two ways:
    # ```
    # foo    = "Foo"
    # bar    = "Bar"
    # foobar = foo + bar
    # # same as:
    # foobar = foo.concat(bar)
    # ```
    #
    # * argument:: first string struct to concatenate
    # * argument:: second string struct to concatenate
    # * returns:: new string struct
    def self.lc_str_concat(lcStr : LcString, str)
        # To implement: argument check
        concated_str = build_string
        strlen1      = str_size(lcStr)
        strlen2      = str_size(str)
        strlen_tot   = strlen1 + strlen2
        resize_capacity(concated_str,strlen_tot)
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
    # bark   = "Bark"
    # bark_3 = bark * 3 #=> "BarkBarkBark"
    def self.lc_str_multiply(lcStr : LcString,times)
        new_str = build_string 
        strlen  = str_size(lcStr)
        tms     = times #lc_num_to_i(times)
        resize_capacity(new_str,strlen * tms)
        set_size(new_str,strlen * tms)
        tms.times do |n|
            (0...strlen).each do |i|
                str_add_char(new_str,n * strlen + i ,str_char_at(lcStr,i))
            end 
        end
        return new_str
    end 


    # Converts a LinCAS string to a Crystal string
    #
    # * argument:: string struct
    def self.string_to_cr(lcStr : LcString)
        string = ""
        (0...str_size(lcStr)).each do |i|
            string += str_char_at(lcStr,i).to_s
        end 
        return string 
    end

#    str = build_string
#    self.lc_init_string(str,"ciao")
#    c = lc_str_multiply(str,3)
#    p self.string_to_cr(c)

end