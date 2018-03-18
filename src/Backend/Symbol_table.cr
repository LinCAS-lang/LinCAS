
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

class LinCAS::Symbol_Table_Stack

    private struct ID_table 
        def initialize
            @cache = [] of String
        end

        @[AlwaysInline]
        def fetch(name : String)
            return @cache.includes? name
        end

        @[AlwaysInline]
        def set(name : String)
            unless @cache.includes? name 
                @cache << name
            end
        end
    end

    def initialize
        @stack = [ID_table.new]
        @sp    = 1
    end

    @[AlwaysInline]
    def fetch(name : String, max_depth : Intnum)
        count = 0
        @stack.reverse_each do |table|
            if table.fetch(name)
                return count
            end
            break if max_depth == count
            count += 1
        end
        return -1
    end

    @[AlwaysInline]
    def set(name : String)
        @stack[@sp - 1].set(name)
    end 

    @[AlwaysInline]
    def push_table
        @stack.push ID_table.new 
        @sp        += 1
    end

    @[AlwaysInline]
    def pop_table
        @sp -= 1
    end

end