
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

module LinCAS::Internal

    struct Snumber < BaseS

        private def mcd(a,b)
            a,b = b,a unless b < a 
            while b != 0 
                a,b = b, a % b 
            end 
            return a 
        end

        getter value

        def initialize(@value : Num)
            super()
        end

        @[AlwaysInline]
        def +(obj : Snumber)
            return num2sym(@value + obj.value)
        end

        @[AlwaysInline]
        def +(obj : BinaryOp)
            return obj + self
        end

        def +(obj)
            return nil unless self.top
            return Sum.new(self,obj).reduce
        end

        @[AlwaysInline]
        def -(obj : Snumber)
            return num2sym(@value - obj.value)
        end

        def -(obj)
            return nil unless self.top
            return Sub.new(self,obj).reduce
        end

        @[AlwaysInline]
        def -
            return Negative.new(self)
        end

        @[AlwaysInline]
        def *(obj : Snumber)
            return num2sym(@value * obj.value)
        end

        @[AlwaysInline]
        def *(obj : BinaryOp)
            return obj * self 
        end

        def *(obj)
            return nil unless self.top
            return Product.new(self,obj).reduce
        end

        def /(obj : Snumber)
            return InfinityC if obj == 0
            return self if obj == 1
            _mcd = mcd(@value,obj.value)
            return Division.new(@value,obj.value) if _mcd == 1
            v1 = @value / _mcd 
            v2 = obj.value / _mcd 
            return sym2num(v1) if v2 == 1 
            return Division.new(v1,v2)
        end 

        def /(obj)
            return nil unless self.top 
            return Division.new(self,obj).reduce
        end

        @[AlwaysInline]
        def **(obj : Snumber)
            return num2sym(@value ** obj.value)
        end

        def **(obj)
            return nil unless self.top 
            return Power.new(self,obj).reduce
        end

        @[AlwaysInline]
        def reduce 
            return self
        end

        @[AlwaysInline]
        def eval(dict)
            return @value 
        end

        @[AlwaysInline]
        def diff(obj)
            return num2sym(0)
        end


        @[AlwaysInline]
        def to_s(io)
            io << @value 
        end

        @[AlwaysInline]
        def to_s 
            return @value.to_s 
        end

        @[AlwaysInline]
        def ==(obj : Num)
            return @value == obj 
        end

        @[AlwaysInline]
        def ==(obj : Snumber)
            return @value == obj.value 
        end

        @[AlwaysInline]
        def ==(obj)
            return false 
        end

        @[AlwaysInline]
        def depend?(obj)
            return false 
        end

    end
    
end