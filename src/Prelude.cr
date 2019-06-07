

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

{% begin %}
    
    require "./Internal/Internal"
    require "./Internal/Structures"
    module LinCAS::Internal
        @@main_class = uninitialized LcClass  
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
            symbolic
        |}}  

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
            sintax_err
            pyexception
            pyimport_err
            not_impl_err
        |}}

        {{ extra_init = %w|
            load
            pyhelper
        |}}

        {% for name in built_in + extra_v %}
            @@lc_{{name.id}} = uninitialized LcClass
        {% end %}
    end  
    
    require "./Internal/**"

    module LinCAS::Internal

        def self.lc_initialize
            Python.Py_Initialize
            {% for name in built_in + extra_init%}
                init_{{name.id}}
            {% end %}
        end

        def self.lc_finalize
            PyGC.clear_all
            Python.Py_Finalize 
        end
    end

{% end %}

# require "./LibC"
# require "./Pythonlib"
# require "./PyHelper"
# require "./Overload.cr"
# require "./Sort"
# require "./Internal"
# require "./Method"
# require "./Structures"
# require "./Class"
# require "./Module"
# require "./Kernel"
# require "./Raise"
# require "./Matrix"
# require "./Object"
# require "./Null"
# require "./Boolean"
# require "./Range"
# require "./Array"
# require "./Number"
# require "./Integer"
# require "./Float"
# require "./String"
# require "./String_buffer"
# require "./Symbol"
# require "./Regexp"
# require "./MatchData"
# require "./Hash"
# require "./Dir"
# require "./File"
# require "./Load"
# require "./Math"
# 
# require "./Symbolic"
# require "./Smath"
# require "./Integrals"
# require "./GSL"
# require "./Complex"
# require "./Python"
# require "./Pymethod"
# require "./PyGC"
# require "./PyObject"
# require "./Proc"
