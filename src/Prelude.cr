

# Copyright (c) 2017-2022 Massimiliano Dal Mas
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

require "./Internal/Internal"
require "./Internal/Base"
require "./Internal/LibC"
require "./Internal/Pythonlib"
# require "./Internal/PyHelper"
require "./Internal/Overload.cr"
require "./Internal/Sort"
require "./Internal/Internal"
require "./Internal/Method"
require "./Internal/Class"
require "./Internal/Module"
require "./Internal/Kernel"
require "./Internal/Raise"
require "./Internal/Matrix"
require "./Internal/Object"
require "./Internal/Null"
require "./Internal/Boolean"
require "./Internal/Range"
require "./Internal/Array"
require "./Internal/Number"
require "./Internal/Integer"
require "./Internal/Float"
require "./Internal/String"
require "./Internal/String_buffer"
require "./Internal/Symbol"
require "./Internal/Regexp"
require "./Internal/MatchData"
require "./Internal/Hash"
require "./Internal/Dir"
require "./Internal/File"
require "./Internal/Load"
require "./Internal/Math"

#require "./Symbolic"
require "./Internal/Smath"
require "./Internal/Integrals"
require "./Internal/GSL"
require "./Internal/Complex"
require "./Internal/Python"
# require "./Internal/Pymethod"
# require "./Internal/PyGC"
require "./Internal/PyObject"
require "./Internal/Proc"

module LinCAS::Internal

    def self.lc_initialize
        Python.initialize
        # These three initializers must always be called first and in the 
        # following order
        init_class
        init_module
        init_object
        {% for name in @type.class.methods.select(&.name.starts_with?("init_")).map(&.name) %}
            {% unless {"init_class", "init_module", "init_object"}.includes? name.stringify %}
              {{name.id}}
            {% end %}
        {% end %}
        VM.init
    end

    def self.lc_finalize
        Python.finalize if Python.initialized?
    end
end

{% begin %}
    
    module LinCAS::Internal 
        {{built_in = %w|
            class 
            module
            object
            
            kernel
            array
            error
            boolean
            number
            complex
            integer
            float
            string
            file
            hash
            regexp
            match_data
            matrix
            method
            unbound_method
            null
            pyobject
            pymodule
            symbol
            range
            math
            proc
            
        |}}  # symbolic

        {{extra_v = %w|
            type_err
            arg_err
            runtime_err
            name_err
            nomet_err
            frozen_err
            zerodiv_err
            systemstack_err
            index_err
            math_err
            instance_err
            load_err
            key_err
            not_supp_err
            syntax_err
            pyexception
            pyimport_err
            not_impl_err
            localjmp_err
            range_err
        |}}

        {% for name in built_in + extra_v %}
            @@lc_{{name.id}} = uninitialized LcClass
            class_getter lc_{{name.id}}
        {% end %}
    end  
    
    #require "./Internal/**"

{% end %}
