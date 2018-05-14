
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
            Internal
        end

        macro obj_of(str_ptr)
            {{str_ptr}}.as(LcObject*).value
        end

        def self.outl(arg)
            self.out(arg)
            LibC.printf("\n")
        end 

        def self.out(arg)
            if arg.is_a? LcString
                LibC.printf("%s",arg.str_ptr)
            elsif arg.is_a? LcTrue
                LibC.printf("true")
            elsif arg.is_a? LcFalse
                LibC.printf("false")
            elsif arg == Null
                LibC.printf("null")
            elsif arg.is_a? Structure
                LibC.printf(arg.as(Structure).path.to_s)
            elsif arg.is_a? LcNum
                LibC.printf("#{arg.as(LcNum).val}")
            elsif arg.is_a? LcArray
                LibC.printf("%s",internal.lc_ary_to_s(arg).as(LcString).str_ptr)
            else
                arg = arg.as(Internal::Value)
                if internal.lc_obj_responds_to? arg,"to_s"
                    self.out(Exec.lc_call_fun(arg,"to_s"))
                else 
                    LibC.printf(internal.lc_typeof(arg))
                end
            end
        end

        def self.in
            value = STDIN.gets
            str   = internal.build_string(value || "")
            return str 
        end

        private def self.print_str(arg)
            size = arg.size 
            ptr  = arg.str_ptr
            (0...size).each do |i|
                STDOUT.print(ptr[i])
            end
        end
<<<<<<< HEAD
=======
        return lctrue
    end
>>>>>>> lc-vm

    end
<<<<<<< HEAD
=======

    private def self.define_argv
        ary = build_ary_new
        (1...ARGV.size).each do |i|
            lc_ary_push(ary,build_string(ARGV[i]))
        end
        return ary
    end

    private def self.define_env
        return build_hash
    end
    

    



    LKernel = internal.lc_build_internal_module("Kernel")

    lc_module_add_internal(LKernel,"printl",lc_printl, 1)
    lc_module_add_internal(LKernel,"print",lc_print,   1)
    lc_module_add_internal(LKernel,"reads",reads,      0)
    lc_module_add_internal(LKernel,"include",include_m,1)

    lc_define_const(LKernel,"ARGV",define_argv)
    lc_define_const(LKernel,"ENV", define_env)

    lc_include_module(Lc_Class,LKernel)

    
>>>>>>> lc-vm

end