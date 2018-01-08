
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
    
    module LcKernel

        macro internal 
            LinCAS::Internal
        end

        macro obj_of(str_ptr)
            {{str_ptr}}.as(LcObject*).value
        end

        def self.outl(arg)
            self.out(arg)
            STDOUT.puts "\n"
        end 

        def self.out(arg)
            if arg.is_a? LcString
                print_str(arg.as(LcString))
            elsif arg.is_a? LcTrue
                STDOUT.print "true"
            elsif arg.is_a? LcFalse
                STDOUT.print "false"
            elsif arg == Null
                STDOUT.print "Null"
            elsif arg.is_a? Structure
                STDOUT.print arg.as(Structure).path.to_s
            elsif arg.is_a? LcNum
                STDOUT.print arg.as(LcNum).val
            end
        end

        def self.in
            str = internal.build_string(STDIN.gets)
            return str 
        end

        private def self.print_str(arg)
            size = arg.size 
            ptr  = arg.str_ptr
            (0...size).each do |i|
                STDOUT.print(ptr[i])
            end
        end

    end

end