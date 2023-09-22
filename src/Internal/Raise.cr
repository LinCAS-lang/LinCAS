
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

module LinCAS
    
    module Internal

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

        class LcError < LcBase
            @body      : String = ""
            @backtrace : String = ""
            property body, backtrace
        end

        # Warn: no check is performed to see if klass is an error class or
        def self.build_error(klass : LcClass, body : String, backtrace : String)
            body  = String.build { |io| io << class_path(klass) << ':' << ' ' << body}
            err   = lc_err_new(klass).as(LcError)
            err.body      = body 
            err.backtrace = backtrace
            return err.as( LcVal)
        end

        def self.lc_err_new(klass :  LcVal)
            klass = klass.as(LcClass)
            err   = lincas_obj_alloc LcError, klass
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
                err = build_error(lc_runtime_err,String.new(error.as(LcString).str_ptr),"")
                VM.lc_raise(err)
                return Null
            end 
            if !(error.is_a? LcError)
                lc_raise(lc_type_err,"(Error object expected)")
                return Null
            end 
            VM.lc_raise(error)
        end

        def self.init_error
            @@lc_error = internal.lc_build_internal_class("Error")
            define_allocator(@@lc_error,lc_err_allocate)
        
            define_protected_method(@@lc_error,"initialize",lc_err_init,          1)
            define_method(@@lc_error,"to_s",lc_err_msg,           0)
            alias_method_str(@@lc_error,"to_s","message"           )
            define_method(@@lc_error,"backtrace",lc_err_backtrace,0)
            define_method(@@lc_error,"full_msg",lc_err_full_msg,  0)
            define_method(@@lc_error,"defrost",lc_obj_defrost,    0)


            define_method(@@lc_kernel,"raise",lc_raise_err, 1)

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
            @@lc_syntax_err  = lc_build_internal_class("SyntaxError",@@lc_error   )
            @@lc_pyexception = lc_build_internal_class("PyException",@@lc_error   )
            @@lc_pyimport_err = lc_build_internal_class("PyImportError",@@lc_error)
            @@lc_not_impl_err = lc_build_internal_class("NotImplementedError",@@lc_error)
            @@lc_localjmp_err = lc_build_internal_class("LocalJumpError",@@lc_error)
            @@lc_range_err    = lc_build_internal_class("RangeError", @@lc_error   )
        end


        macro lc_raise(error_t,body)
            VM.lc_raise({{error_t}},{{body}})
        end

    end

    macro convert_error(name)
        Internal::ERR_MESSAGE[{{name}}]
    end
end
