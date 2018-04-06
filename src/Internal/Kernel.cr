
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


    def self.lc_outl(arg)
        self.lc_out(arg)
        LibC.printf("\n")
    end 

    lc_printl = LcProc.new do |args|
        internal.lc_outl(args.as(T2)[1])
        next Null
    end

    def self.lc_out(arg)
        if arg.is_a? LcString
            LibC.printf("%s",arg.str_ptr)
        elsif arg.is_a? LcTrue
            LibC.printf("true")
        elsif arg.is_a? LcFalse
            LibC.printf("false")
        elsif arg == Null
            LibC.printf("null")
        elsif arg.is_a? LcNum
            LibC.printf("#{arg.as(LcNum).val}")
        elsif arg.is_a? LcArray
            LibC.printf("%s",internal.lc_ary_to_s(arg).as(LcString).str_ptr)
        else
            arg = arg.as(Internal::Value)
            if internal.lc_obj_responds_to? arg,"to_s"
                self.lc_out(Exec.lc_call_fun(arg,"to_s"))
            else 
                LibC.printf(internal.lc_typeof(arg))
            end
        end
    end

    private def self.print_str(arg)
        size = arg.size 
        ptr  = arg.str_ptr
        (0...size).each do |i|
            STDOUT.print(ptr[i])
        end
    end

    lc_print = LcProc.new do |args|
        internal.lc_out(args.as(T2)[1])
        next Null
    end

    def self.lc_in
        value = STDIN.gets
        str   = internal.build_string(value || "")
        return str 
    end

    reads = LcProc.new do |args|
        next internal.lc_in
    end

    def self.lc_include(klass : Value, mod : Value)
        if !(mod.is_a? Structure)
            lc_raise(LcTypeError,"Module expected (#{lc_typeof(mod)} given)")
        elsif !(struct_type(mod.as(Structure),SType::MODULE))
            lc_raise(LcTypeError,"Module expected (#{lc_typeof(mod)} given)")
        else
            if !klass.is_a? Structure
                klass = class_of(klass)
            end
            internal.lc_include_module(klass.as(Lc_Class),mod.as(LcModule))
        end
        return Null
    end

    include_m = LcProc.new do |args|
        next internal.lc_include(*args.as(T2))
    end
    

    



    LKernel = internal.lc_build_internal_module("Kernel")

    lc_module_add_internal(LKernel,"printl",lc_printl, 1)
    lc_module_add_internal(LKernel,"print",lc_print,   1)
    lc_module_add_internal(LKernel,"reads",reads,      0)
    lc_module_add_internal(LKernel,"include",include_m,1)

    lc_include_module(Lc_Class,LKernel)

    

end