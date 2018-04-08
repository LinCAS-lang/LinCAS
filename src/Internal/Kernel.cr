
# Copyright (c) 2017-2018 Massimiliano Dal Mas
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