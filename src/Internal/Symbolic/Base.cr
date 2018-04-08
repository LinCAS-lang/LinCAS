
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

    abstract struct SBaseS
        macro num2sym(value)
            Snumber.new({{value}})
        end

        macro sym2num(value)
            {{value}}.as(Snumber).value
        end

        macro neg2val(value)
            {{value}}.as(Negative).value 
        end
    
        macro string2sym(value)
            Variable.new({{value}})
        end

        macro return_with_top(obj,top)
            {{obj.top}} == top 
            return obj 
        end

        property top
        def initialize(@top = true)
        end

        abstract def +(obj)
        abstract def -(obj)
        abstract def *(obj)
        abstract def /(obj)
        abstract def **(obj)
        abstract def reduce()
        abstract def diff()
        abstract def eval(dict)
        abstract def ==(obj)
        abstract def =~(obj)
        abstract def depend?(obj)
    end

    abstract class SBaseC
        macro num2sym(value)
            Snumber.new({{value}})
        end

        macro sym2num(value)
            {{value}}.as(Snumber).value
        end

        macro neg2val(value)
            {{value}}.as(Negative).value 
        end
    
        macro string2sym(value)
            Variable.new({{value}})
        end

        macro return_with_top(obj,top)
            {{obj.top}} == top 
            return obj 
        end

        property top
        def initialize(@top = true)
        end

        abstract def +(obj)
        abstract def -(obj)
        abstract def *(obj)
        abstract def /(obj)
        abstract def **(obj)
        abstract def reduce()
        abstract def diff()
        abstract def eval(dict)
        abstract def ==(obj)
        abstract def =~(obj)
        abstract def depend?(obj)
    end

    alias Sym = BaseS 

end
