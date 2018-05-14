
# Copyright (c) 2017-2018 Massimiliano Dal Mas
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

<<<<<<< HEAD
module LinCAS::Internal

    abstract struct BaseS
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
        abstract def depend?(obj)
    end

    abstract class BaseC
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
        abstract def depend?(obj)
    end
=======
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
                {{num}}.as(LcNum).val.as(NumR)
            end".id}}

            abstract def +(obj)
            abstract def -(obj)
            abstract def /(obj)
            abstract def **(obj)
            abstract def diff(obj)
            abstract def eval(dict)
            abstract def ==(obj)
            abstract def depend?(obj)

            {% for name in %w|opt_sum opt_sub opt_div opt_prod opt_power| %}
                def {{name.id}}(obj : Symbolic)
                    nil 
                end
            {% end %}

            macro nan_ops

            {% for name in %w|+ - * / ** opt_sum opt_sub opt_div opt_prod opt_power| %}
                def {{name.id}}(obj : Nan)
                    return NanC 
                end
            {% end %}

            end

            def get_params(ary)
            end

            
        {{"end".id}}
    end

    base("class",SBaseC)
    base("struct",SBaseS)
>>>>>>> lc-vm

    alias Symbolic = SBaseS | SBaseC

    macro num2sym(value)
        Snumber.new({{value}})
    end

    macro string2sym(value)
        Variable.new({{value}})
    end

end