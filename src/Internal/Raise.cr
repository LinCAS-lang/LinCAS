
# Copyright (c) 2017 Massimiliano Dal Mas
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
            StandardError
            InternalError
            NameError
            NoMethodError
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
            :no_method      => "Undefined method for %s"
        }

    end

    LcTypeError     = Internal::ErrType::TypeError
    LcArgumentError = Internal::ErrType::ArgumentError
    LcRuntimeError  = Internal::ErrType::RuntimeError
    LcStandardError = Internal::ErrType::StandardError
    LcInternalError = Internal::ErrType::InternalError
    LcNameError     = Internal::ErrType::NameError
    LcNoMethodError = Internal::ErrType::NoMethodError

    macro convert_error(name)
        Internal::ERR_MESSAGE[{{name}}]
    end
end