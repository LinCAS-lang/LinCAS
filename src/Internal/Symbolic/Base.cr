
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

macro LinCAS
end

module LinCAS::Internal

    macro base(type,name)
        abstract {{type.id}} {{name}}
            {{"
            macro num2sym(value)
                Snumber.new({{value}})
            end
    
            macro sym2num(value)
                {{value.id}}.as(Snumber).val
            end
        
            macro string2sym(value)
                Variable.new({{value}})
            end
            
            macro num2num(num)
                num.as(LcNum).value
            end".id}}

            # abstract def +(obj)
            #abstract def -(obj)
            #abstract def /(obj)
            #abstract def **(obj)
            #abstract def diff(obj)
            #abstract def eval(dict)
            #abstract def ==(obj)
            #abstract def depend?(obj)

            {% for name in %w|opt_sum opt_sub opt_div opt_prod opt_power| %}
                def {{name.id}}(obj : Symbolic)
                    nil 
                end
            {% end %}

            {% for name in %w|+ - * / ** opt_sum opt_sub opt_div opt_prod opt_power| %}
                def {{name.id}}(obj : Nan)
                    return NanC 
                end
            {% end %}

            
        {{"end".id}}
    end

    base("class",SBaseC)
    base("struct",SBaseS)

    alias Symbolic = SBaseS | SBaseC

end
