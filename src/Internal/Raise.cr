
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

module LinCAS
    
    module Internal

        @@err_dict = uninitialized Hash(ErrType,LcClass)
        
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
            IndexError
            MathError
            InstanceError
            LoadError
            KeyError
            NotSupportedError
            SintaxError
            PyException
            PyImportError
            NotImplementedError
        end

        ERR_MESSAGE = {
            :wrong_node_reached => "Wrong node reached",
            :not_a_const    => "'%s' is not a constant",
            :not_a_struct   => "'%s' is not a class nor a module",
            :not_a_class    => "'%s' is not a class",
            :not_a_module   => "'%s' is not a module",
            :const_defined  => "constant '%s' already defined",
            :superclass_err => "Superclass missmatch for '%s'",
            :undefined_const => "Undefined constant '%s'",
            :undef_const_2  => "Undefined constant '%s' for '%s'",
            :no_s_method    => "Undefined method for %s : %s",
            :no_method      => "Undefined method for '%s' object",
            :undefined_id   => "Undefined local variable or constant '%s'",
            :undef_var      => "Undefined local variable '%s'",
            :protected_method => "Protected method called for '%s' object",
            :private_method => "Private method called for '%s' object",
            :no_coerce      => "Cant't coerce %s into %s",
            :few_args       => "Wrong number of arguments (%i instead of %i)",
            :modify_frozen  => "Attempted to modify a frozen object",
            :frozen_class   => "Can't reopen a frozen class",
            :frozen_module  => "Can't reopen a frozen module",
            :failed_comparison => "Comparison between %s and %s failed",
            :no_parent      => "Parent must be a class (%s given)",
            :no_block       => "No block given %s"
        }

        class LcError < LcVal
            @body      : String = ""
            @backtrace : String = ""
            property body, backtrace
        end

        def self.build_error(error : ErrType,body : String, backtrace : String)
            body  = String.build { |io| io << error << ':' << ' ' << body}
            klass = @@err_dict[error]
            err   = lc_err_new(klass).as(LcError)
            err.body      = body 
            err.backtrace = backtrace
            return err.as( LcVal)
        end

        def self.lc_err_new(klass :  LcVal)
            klass = klass.as(LcClass)
            err   = lincas_obj_alloc LcError, klass, data: klass.data.clone
            return err.as( LcVal)
        end

        def self.lc_err_allocate(klass : LcVal)
            return lc_err_new(klass)
        end

        def self.lc_err_init(err :  LcVal, body :  LcVal)
            body = string2cr(body)
            return Null unless body
            err = err.as(LcError)
            klass         = err.klass.name
            err.body      = klass + ':' + ' ' + body
            err.backtrace = ""
            Null
        end

        def self.lc_err_msg(err :  LcVal)
            return internal.build_string(err.as(LcError).body)
        end

        def self.lc_err_backtrace(err :  LcVal)
            return internal.build_string(err.as(LcError).backtrace)
        end

        def self.lc_err_full_msg(err :  LcVal)
            err = err.as(LcError)
            internal.build_string(String.build do |io|
                io << err.body << err.backtrace
            end)
        end

        def self.lc_raise_err(unused,error :  LcVal)
            if error.is_a? LcString 
                err = build_error(LcRuntimeError,String.new(error.as(LcString).str_ptr),"")
                Exec.lc_raise(err)
                return Null
            end 
            if !(error.is_a? LcError)
                lc_raise(LcTypeError,"(Error object expected)")
                return Null
            end 
            Exec.lc_raise(error)
        end

        def self.init_error
            @@lc_error = internal.lc_build_internal_class("Error")
            define_allocator(@@lc_error,lc_err_allocate)
        
            add_method(@@lc_error,"init",lc_err_init,          1)
            add_method(@@lc_error,"to_s",lc_err_msg,           0)
            alias_method_str(@@lc_error,"to_s","message"           )
            add_method(@@lc_error,"backtrace",lc_err_backtrace,0)
            add_method(@@lc_error,"full_msg",lc_err_full_msg,  0)
            add_method(@@lc_error,"defrost",lc_obj_defrost,    0)


            lc_module_add_internal(@@lc_kernel,"raise",wrap(lc_raise_err,2), 1)

            @@lc_type_err    = lc_build_internal_class("TypeError",@@lc_error     )
            @@lc_arg_err     = lc_build_internal_class("ArgumentError",@@lc_error )
            @@lc_runtime_err = lc_build_internal_class("RuntimeError",@@lc_error  )
            @@lc_name_err    = lc_build_internal_class("NameError",@@lc_error     )
            @@lc_nomet_err   = lc_build_internal_class("NoMethodError",@@lc_error )
            @@lc_frozen_err  = lc_build_internal_class("FrozenError",@@lc_error   )
            @@lc_zerodiv_err = lc_build_internal_class("ZeroDivisionError",@@lc_error   )
            @@lc_systemstack_err = lc_build_internal_class("SystemStackError",@@lc_error)
            @@lc_index_err   = lc_build_internal_class("IndexError",@@lc_error    )
            @@lc_math_err    = lc_build_internal_class("MathError",@@lc_error     )
            @@lc_instance_err = lc_build_internal_class("InstanceError",@@lc_error)
            @@lc_load_err    = lc_build_internal_class("LoadError",@@lc_error     )
            @@lc_key_err     = lc_build_internal_class("KeyError",@@lc_error      )
            @@lc_not_supp_err = lc_build_internal_class("NotSupportedError",@@lc_error)
            @@lc_sintax_err  = lc_build_internal_class("SintaxError",@@lc_error   )
            @@lc_pyexception = lc_build_internal_class("PyException",@@lc_error   )
            @@lc_pyimport_err = lc_build_internal_class("PyImportError",@@lc_error)
            @@lc_not_impl_err = lc_build_internal_class("NotImplementedError",@@lc_error)

            @@err_dict = {
                ErrType::TypeError         => @@lc_type_err,
                ErrType::ArgumentError     => @@lc_arg_err,
                ErrType::RuntimeError      => @@lc_runtime_err,
                ErrType::NameError         => @@lc_name_err,
                ErrType::NoMethodError     => @@lc_nomet_err,
                ErrType::ZeroDivisionError => @@lc_zerodiv_err,
                ErrType::SystemStackError  => @@lc_systemstack_err,
                ErrType::FrozenError       => @@lc_frozen_err,
                ErrType::IndexError        => @@lc_index_err,
                ErrType::MathError         => @@lc_math_err,
                ErrType::InstanceError     => @@lc_instance_err,
                ErrType::LoadError         => @@lc_load_err,
                ErrType::KeyError          => @@lc_key_err, 
                ErrType::NotSupportedError => @@lc_not_supp_err,
                ErrType::SintaxError       => @@lc_sintax_err,
                ErrType::PyException       => @@lc_pyexception,
                ErrType::PyImportError     => @@lc_pyimport_err,
                ErrType::NotImplementedError => @@lc_not_impl_err
            }
        end


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
    LcSystemStackError  = Internal::ErrType::SystemStackError
    LcIndexError    = Internal::ErrType::IndexError
    LcMathError     = Internal::ErrType::MathError
    LcInstanceErr   = Internal::ErrType::InstanceError
    LcLoadError     = Internal::ErrType::LoadError
    LcKeyError      = Internal::ErrType::KeyError
    LcNotSupportedError = Internal::ErrType::NotSupportedError
    LcSintaxError   = Internal::ErrType::SintaxError
    LcPyException   = Internal::ErrType::PyException
    LcPyImportError = Internal::ErrType::PyImportError
    LcNotImplError  = Internal::ErrType::NotImplementedError

    macro convert_error(name)
        Internal::ERR_MESSAGE[{{name}}]
    end
end
