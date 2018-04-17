
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
            {{"macro num2sym(value)
                Snumber.new({{value}})
            end
    
            macro sym2num(value)
                {{value.id}}.as(Snumber).value
            end
    
            macro neg2val(value)
                {{value.id}}.as(Negative).value 
            end
        
            macro string2sym(value)
                Variable.new({{value}})
            end".id}}

            abstract def +(obj)
            abstract def opt_sum(obj)
            abstract def -(obj)
            abstract def opt_sub(obj)
            abstract def *(obj)
            abstract def opt_prod(obj)
            abstract def /(obj)
            abstract def opt_div(obj)
            abstract def **(obj)
            abstract def opt_power(obj)
            # abstract def reduce()
            abstract def diff()
            abstract def eval(dict)
            abstract def ==(obj)
            abstract def depend?(obj)
        {{"end".id}}
    end

    base("class",SBaseC)
    base("struct",SBaseS)

    #alias Sym = BaseS 

end
