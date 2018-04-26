
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

    struct Nan < SBaseS

        {% for name in %w|+ - * / ** opt_sum opt_sub opt_prod opt_div opt_power diff| %}
            def {{name.id}}(obj)
                return self 
            end
        {% end %}

        def -
            return self 
        end

        def eval(dict)
            return Float64::NAN
        end

        def to_s(io)
            io << "Nan"
        end

        def to_s 
            "Nan"
        end

        def ==(obj : Nan)
            true 
        end

        def ==(obj)
            false 
        end
        
    end

    NanC = Nan.new
    
end