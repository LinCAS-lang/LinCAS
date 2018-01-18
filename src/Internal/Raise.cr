
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

module LinCAS
    
    module Internal
        
        enum ErrType
            TypeError
            ArgumentError
            RuntimeError
            InternalError
            NameError
            NoMethodError
            ZeroDivisionError
            SystemStackError
            FrozenError
        end

        ERR_MESSAGE = {
            :wrong_node_reached => "Wrong node reached",
            :not_a_const    => "'%s' is not a constant",
            :not_a_struct   => "'%s' is not a class nor a module",
            :not_a_class    => "'%s' is not a class",
            :not_a_module   => "'%s' is not a module",
            :const_defined  => "constant '%s' already defined",
            :superclass_err => "Superclass missmatch in '%s'",
            :undefined_const=> "Undefined constant '%s'",
            :no_s_method    => "Undefined method for %s : %s",
            :no_method      => "Undefined method for '%s' object",
            :undefined_id   => "Undefined local variable or constant '%s'",
            :protected_method => "Protected method called for '%s' object",
            :private_method => "Private method called for '%s' object",
            :no_coerce      => "Cant't coerce %s into %s",
            :few_args       => "Wrong number of arguments (%i instead of %i)",
            :modify_frozen  => "Attempted to modify a frozen object"
        }

        class LcError < BaseC
            @body      : String = ""
            @backtrace : String = ""
            getter error, body, backtrace
            setter error, body, backtrace
        end

        def self.build_error(error : ErrType,body : String, backtrace : String)
            body  = String.build { |io| io << error << ':' << ' ' << body}
            klass = ErrDict[error]
            err   = lc_err_new(klass).as(LcError)
            err.body      = body 
            err.backtrace = backtrace
            return err.as(Value)
        end

        def self.lc_err_new(klass : Value)
            klass     = klass.as(ClassEntry)
            err       = LcError.new 
            err.klass = klass 
            err.data  = klass.data.clone
            return err.as(Value)
        end

        def self.lc_err_init(err : Value, body : Value, backtrace : Value)
            err = err.as(LcError)
            klass         = err.klass.to_s
            err.body      = klass + ':' + ' ' + string2cr(body)
            err.backtrace = string2cr(backtrace)
        end

        def self.lc_err_msg(err : Value)
            return internal.build_string(err.as(LcError).body)
        end

        def self.lc_err_backtrace(err : Value)
            return internal.build_string(err.as(LcError).backtrace)
        end

        def self.lc_err_full_msg(err : Value)
            err = err.as(LcError)
            internal.build_string(String.build do |io|
                io << err.body << err.backtrace
            end)
        end

        ErrClass = internal.lc_build_class_only("Error")
        internal.lc_set_parent_class(ErrClass,Obj)
        internal.lc_add_static_singleton(ErrClass,"new",:lc_err_new,    0)
        internal.lc_add_internal(ErrClass,"init",:lc_err_init,          2)
        internal.lc_add_internal(ErrClass,"to_s",:lc_err_msg,           0)
        internal.lc_add_internal(ErrClass,"backtrace",:lc_err_backtrace,0)
        internal.lc_add_internal(ErrClass,"full_msg",:lc_err_full_msg,  0)

        TypeErrClass = internal.lc_build_class_only("TypeError")
        internal.lc_set_parent_class(TypeErrClass,ErrClass)

        ArgErrClass  = internal.lc_build_class_only("ArgumentError")
        internal.lc_set_parent_class(ArgErrClass,ErrClass)

        RuntimeErrClass = internal.lc_build_class_only("RuntimeError")
        internal.lc_set_parent_class(RuntimeErrClass,ErrClass)

#        InternalErrClass = internal.lc_build_class_only("InternalError")
#        internal.lc_set_parent_class(ErrClass,Obj)

        NameErrClass = internal.lc_build_class_only("NameError")
        internal.lc_set_parent_class(NameErrClass,ErrClass)

        NoMErrClass  = internal.lc_build_class_only("NoMethodError")
        internal.lc_set_parent_class(NoMErrClass,ErrClass)

        FrozenErrClass = internal.lc_build_class_only("FrozenError")
        internal.lc_set_parent_class(FrozenErrClass,ErrClass)

        ZeroDivErrClass = internal.lc_build_class_only("ZeroDivisionError")
        internal.lc_set_parent_class(ZeroDivErrClass,ErrClass)

        SysStackErrClass = internal.lc_build_class_only("SystemStackError")
        internal.lc_set_parent_class(SysStackErrClass,ErrClass)

        ErrDict = {
            ErrType::TypeError      => TypeErrClass,
            ErrType::ArgumentError  => ArgErrClass,
            ErrType::RuntimeError   => RuntimeErrClass,
            ErrType::NameError      => NameErrClass,
            ErrType::NoMethodError  => NoMErrClass,
            ErrType::ZeroDivisionError => ZeroDivErrClass,
            ErrType::SystemStackError  => SysStackErrClass,
            ErrType::FrozenError       => FrozenErrClass
        }


        macro lc_raise(error_t,body)
            Exec.lc_raise({{error_t}},{{body}})
        end

    end

    LcTypeError     = Internal::ErrType::TypeError
    LcArgumentError = Internal::ErrType::ArgumentError
    LcRuntimeError  = Internal::ErrType::RuntimeError
    LcInternalError = Internal::ErrType::InternalError
    LcNameError     = Internal::ErrType::NameError
    LcNoMethodError = Internal::ErrType::NoMethodError
    LcFrozenError   = Internal::ErrType::FrozenError
    LcZeroDivisionError = Internal::ErrType::ZeroDivisionError
    LcSystemStackError = Internal::ErrType::SystemStackError

    macro convert_error(name)
        Internal::ERR_MESSAGE[{{name}}]
    end
end