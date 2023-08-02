
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

    #$M Kernel
    # This module is included in `Class` class.
    #
    # All its methods are available in every object,
    # and they do not need a receiver.
    #
    # Here methods are documented as static, but they are
    # available as instance methods in instantiated objects
    

    ExitProcs = [] of  LcVal
    @@running = false
    @@version = load_version.as(String)
    # ExitArg   = Ary.new(1)

    private def self.load_version : String
        if File.exists?(file = "/usr/local/lib/LinCAS/LinCAS/VERSION")
            version = File.read(file).chomp
            if version.empty?
                LinCAS.lc_bug("Missing LinCAS version")
            end
            return version
        else
            # LinCAS.lc_bug("Missing LinCAS version")
        end
        # Unreachable
        ""
    end

    private def self.set_at_exit_proc(proc :  LcVal)
        if @@running
            lc_raise(lc_runtime_err,"can't call at_exit() inside a finalization proc")
        else
            ExitProcs << proc 
        end
    end

    def self.invoke_at_exit_procs(status = 0)
        exitarg = Ary.new(1)
        exitarg[0] = num2int(status)
        @@running = true 
        while proc = ExitProcs.pop?
            Exec.call_proc(proc.as(LCProc),exitarg)
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

    def self.lc_outl(unused,arg)
        self.lc_out(nil,arg)
        LibC.printf("\n")
        return Null
    end 

    #$S print
    #$U print(obj1,obj2,...) -> null
    # Prints every object passed as parameter
    # on a single line in the console.
    # If no parameter is passed, `null` will e printed
    #
    # This method can be invoked without parenthesis
    # ```
    # print "hello", " everyone ", 123
    # ```
    #
    # Produces:
    # ```
    # hello everyone 123
    # ```

    def self.lc_out(unused,arg)
        if arg.is_a? LcString
            LibC.printf("%s",arg.str_ptr)
        elsif arg.is_a? LcTrue
            LibC.printf("true")
        elsif arg.is_a? LcFalse
            LibC.printf("false")
        elsif arg == Null
            LibC.printf("")
        elsif arg.is_a? LcNum
            LibC.printf("#{arg.as(LcNum).val}")
        elsif arg.is_a? LcArray
            LibC.printf("%s",internal.lc_ary_to_s(arg).as(LcString).str_ptr)
        else
            arg = arg.as( LcVal)
            if internal.lc_obj_responds_to? arg,"to_s"
                self.lc_out(nil,Exec.lc_call_fun(arg,"to_s"))
            else 
                LibC.printf(internal.lc_typeof(arg))
            end
        end
        return Null
    end

    private def self.print_str(arg)
        size = arg.size 
        ptr  = arg.str_ptr
        (0...size).each do |i|
            STDOUT.print(ptr[i])
        end
    end

    #$S reads
    #$U reads() -> string
    # Reads a line from the STDIN

    def self.lc_in(unused)
        value = STDIN.gets
        str   = internal.build_string(value || "")
        return str 
    end

    #$S include
    #$U include(module) -> boolean
    # Includes a module in a class or in a object class.
    # This is useful to add methods defined in a module
    # to a class or object, as a sort of multiple inheritance
    #
    # This method can be invoked without parenthesis
    # ```coffee
    # module Foo {
    #   let foo 
    #   {
    #     printl "Foo"
    #   }
    # 
    #   let self.bar
    #   {
    #     printl "Bar"
    #   }  
    # }
    # 
    # class Bar {
    #   include Foo
    # }
    #
    # Bar.bar()       #=> Bar
    # new Bar().foo() #=> Foo
    # Bar.foo         #=> NoMethodError
    # ```
    #
    # Static methods are passed as static, while non-static
    # as instance ones

    def self.lc_include(klass :  LcVal, mod :  LcVal)
        if !(mod.is_a? LcClass)
            lc_raise(lc_type_err,"Module expected (#{lc_typeof(mod)} given)")
        elsif !(struct_type(mod.as(LcClass),SType::MODULE))
            lc_raise(lc_type_err,"Module expected (#{lc_typeof(mod)} given)")
        else
            if !klass.is_a? LcClass
                klass = class_of(klass)
            end
            internal.lc_include_module(klass.as(LcClass),mod.as(LcClass))
            return lctrue
        end
        return lcfalse
    end

    private def self.define_argv
        ary = new_array
        (1...ARGV.size).each do |i|
            lc_ary_push(ary,build_string(ARGV[i]))
        end
        return ary
    end

    private def self.define_env
        return build_hash
    end

    #$S exit
    #$U exit(status := 0)
    # exits the program with the given status

    def self.lc_exit(unused,argv : LcVal)
        argv = lc_cast(argv,Ary)
        if !argv.empty?
            status = lc_num_to_cr_i(argv[0])
        else
            status = 0
        end
        lincas_exit status.to_i32 if status
        return Null
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

    def self.lc_at_exit(unused)
        block = Exec.get_block
        if block 
            proc = lincas_block_to_proc(block)
            set_at_exit_proc(proc)
            return proc
        else
            lc_raise(lc_arg_err,"invoked without a block")
            return Null 
        end
    end

    @[AlwaysInline]
    def self.lc_block_given(unised)
        return val2bool(Exec.caller_block_given?)
    end
    

    

    def self.init_kernel
        @@lc_kernel = internal.lc_build_internal_module("Kernel")

        define_method(@@lc_kernel,"class",lc_class_real,       0)
        define_method(@@lc_kernel,"printl",lc_outl,            1)
        define_method(@@lc_kernel,"print",lc_out,              1)
        define_method(@@lc_kernel,"reads",lc_in,               0)
        define_method(@@lc_kernel,"include",lc_include,        1)
        define_method(@@lc_kernel,"exit",lc_exit,             -1)
        define_method(@@lc_kernel,"at_exit",lc_at_exit,        0)
        define_method(@@lc_kernel,"method",lc_get_method,      1)
        define_method(@@lc_kernel,"is_a?", lc_is_a,            1)
        define_method(@@lc_kernel,"send",lc_obj_send,          -3)
        define_method(@@lc_kernel,"respond_to?",lc_obj_responds_to, 1)
        define_method(@@lc_kernel,"block_given?",lc_block_given,0)
    
        lc_include_module(@@lc_object,@@lc_kernel)
    end

    

end