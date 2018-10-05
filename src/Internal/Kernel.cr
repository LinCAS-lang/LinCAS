
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

    #$M Kernel
    # This module is included in `Class` class.
    #
    # All its methods are available in every object,
    # and they do not need a receiver.
    #
    # Here methods are documented as static, but they are
    # available as instance methods in instantiated objects
    

    ExitProcs = [] of Value
    @@running = false
    @@version = load_version.as(String)
    ExitArg   = [Null]

    private def self.load_version : String
        if File.exists?(file = "/usr/local/lib/LinCAS/LinCAS/VERSION")
            version = File.read(file).chomp
            if version.empty?
                LinCAS.lc_bug("Missing LinCAS verion")
            end
            return version
        else
            LinCAS.lc_bug("Missing LinCAS verion")
        end
        # Unreachable
        ""
    end

    private def self.set_at_exit_proc(proc : Value)
        if @@running
            lc_raise(LcRuntimeError,"can't call at_exit() inside a finalization proc")
        else
            ExitProcs << proc 
        end
    end

    def self.invoke_at_exit_procs(status = 0)
        ExitArg[0] = num2int(status)
        @@running = true 
        while proc = ExitProcs.pop?
            Exec.call_proc(proc.as(LCProc),ExitArg)
        end
        @@running = false
    end

    #$S printl
    #$U printl(obj1,obj2,...) -> null
    # Prints every object passed as parameter
    # on a new line in the console.
    # If no parameter is passed, a new line will be printed
    #
    # This method can be invoked without parenthesis
    # ```
    # printl "hello", "everyone ", 123
    # ```
    #
    # Produces:
    # ```
    # hello
    # everyone
    # 123
    # ```

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
        elsif !((struct_type(mod.as(Structure),SType::MODULE)) || 
                (struct_type(mod.as(Structure),SType::PyMODULE)))
            lc_raise(LcTypeError,"Module expected (#{lc_typeof(mod)} given)")
        else
            if !klass.is_a? Structure
                klass = class_of(klass)
            end
            internal.lc_include_module(klass.as(Lc_Class),mod.as(LcModule))
        end
        return lctrue
    end

    include_m = LcProc.new do |args|
        next internal.lc_include(*args.as(T2))
    end

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

    def self.lc_exit(status : Value? = nil)
        if status
            status = lc_num_to_cr_i(status)
        else
            status = 0
        end
        lincas_exit status.to_i32 if status
        return Null
    end

    exit_ = LcProc.new do |args|
        next lc_exit(lc_cast(args,An)[1]?)
    end

    private def self.define_version
        return build_string(@@version)
    end

    #$S at_exit
    #$U at_exit(&block) -> proc or null
    # Registers the given `block` as proc for execution
    # when the program exits.
    # If multiple Procs are registered, they're invoked in 
    # reverse order.
    # ```
    # at_exit() { printl "people"}
    # at_exit() { print "Goodbye "}
    # ```
    #
    # Produces:
    # ```
    # Goodbye people
    # ```

    def self.lc_at_exit()
        block = Exec.get_block
        if block 
            proc = lincas_block_to_proc(block)
            set_at_exit_proc(proc)
            return proc
        else
            lc_raise(LcArgumentError,"invoked without a block")
            return Null 
        end
    end

    at_exit_ = LcProc.new do |args|
        next lc_at_exit
    end
    

    



    LKernel = internal.lc_build_internal_module("Kernel")

    lc_module_add_internal(LKernel,"printl",lc_printl, 1)
    lc_module_add_internal(LKernel,"print",lc_print,   1)
    lc_module_add_internal(LKernel,"reads",reads,      0)
    lc_module_add_internal(LKernel,"include",include_m,1)
    lc_module_add_internal(LKernel,"exit",exit_,      -1)
    lc_module_add_internal(LKernel,"at_exit",at_exit_, 0)

    lc_define_const(LKernel,"ARGV",define_argv)
    lc_define_const(LKernel,"ENV", define_env)
    lc_define_const(LKernel,"VERSION", define_version)

    lc_include_module(Lc_Class,LKernel)

    

end