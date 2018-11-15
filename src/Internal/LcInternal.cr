

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
    @@main_class = uninitialized LcClass
    {% begin %}  
        {{built_in = %w|
            class 
            module
            object
            kernel
            array
            boolean
            complex
            string
            file
            integer
            float
            hash
            regexp
            match_data
            matrix
        |}}  
        {% for name in built_in %}
            @@lc_{{name.id}} = uninitialized LcClass
        {% end %}

        def self.lc_initialize
            Python.PyInitialize
            {% for name in built_in %}
                init_{{name.id}}
            {% end %}
            init_load
        end
    {% end %}
end

require "./LibC"
require "./Pythonlib"
require "./PyHelper"
require "./Overload.cr"
require "./Sort"
require "./Internal"
require "./Method"
require "./Structures"
require "./Class"
require "./Module"
require "./Kernel"
require "./Raise"
require "./Matrix"
require "./Object"
require "./Null"
require "./Boolean"
require "./Range"
require "./Array"
require "./Number"
require "./Integer"
require "./Float"
require "./String"
require "./String_buffer"
require "./Symbol"
require "./Regexp"
require "./MatchData"
require "./Hash"
require "./Dir"
require "./File"
require "./Load"
require "./Math"
require "./Symbolic/Symbolic"
require "./Symbolic"
require "./Smath"
require "./Integrals"
require "./GSL"
require "./Complex"
require "./Python"
require "./Pymethod"
require "./PyGC"
require "./PyObject"
require "./Proc"
