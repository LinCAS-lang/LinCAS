
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

    struct Snumber < SBaseS

        nan_ops

        private def mcd(a,b)
            a,b = b,a unless b < a 
            while b != 0 
                a,b = b, a % b 
            end 
            return a 
        end

        def val 
            @value 
        end

        def initialize(@value : IntnumR)
        end

        def +(obj : Snumber) : Symbolic
            return obj if self == 0
            return num2sym(@value + sym2num(obj))
        end

        def +(obj : BinaryOp) : Symbolic
            return obj if self == 0
            return obj + self
        end

        def +(obj : Infinity) : Symbolic
            return obj 
        end

        def +(obj : Negative) : Symbolic
            return self - obj.value 
        end

        def +(obj) : Symbolic
            return Sum.new(obj,self)
        end

        def opt_sum(obj : Snumber) : Symbolic
            return num2sym(@value + sym2num(obj))
        end

        def opt_sum(obj : Infinity) : Symbolic
            return obj 
        end

        def -(obj : Snumber) : Symbolic
            return -obj if self == 0
            tmp = @value - obj.val
            if tmp < 0
                return -num2sym(-tmp)
            end
            return num2sym(tmp)
        end

        def -(obj : Negative) : Symbolic
            return obj.value if self == 0
            return self + obj.value 
        end

        def -(obj : NInfinity) : Symbolic
            return PinfinityC
        end

        def -(obj : PInfinity) : Symbolic
            return NinfinityC
        end

        def -(obj) : Symbolic
            return -obj if self == 0
            return Sub.new(self,obj)
        end

        def - : Symbolic
            return Negative.create(self)
        end

        def opt_sub(obj : Snumber) : Symbolic
            return -obj if self == 0
            tmp = @value - obj.val
            if tmp < 0
                return -num2sym(tmp.abs)
            end
            return num2sym(tmp)
        end

        def opt_sub(obj : PInfinity) : Symbolic?
            return NinfinityC
        end

        def opt_sub(obj : NInfinity) : Symbolic?
            return PinfinityC
        end

        def *(obj : Snumber) : Symbolic
            return self if self == 0
            return obj if self == 1
            return num2sym(@value * obj.val)
        end

        def *(obj : BinaryOp) : Symbolic
            return obj * self 
        end

        def *(obj : Negative) : Symbolic
            return -(self * obj.value )
        end

        def *(obj : Infinity) : Symbolic
            return NanC if self == 0
            return obj 
        end

        def *(obj) : Symbolic
            return SZERO if self == 0
            return obj if self == 1
            return Product.new(self,obj)
        end

        def opt_prod(obj : Snumber) : Symbolic?
            return self * obj 
        end

        def /(obj : Snumber) : Symbolic
            return NanC if self == 0 && obj == 0
            return PinfinityC if obj == 0
            return self if obj == 1
            _mcd = mcd(@value,obj.val)
            return Division.new(self,obj) if _mcd == 1
            v1 = @value / _mcd 
            v2 = obj.val / _mcd 
            return num2sym(v1) if v2 == 1 
            return Division.new(num2sym(v1),num2sym(v2))
        end 

        def /(obj : Negative) : Symbolic
            return -(self / obj.value)
        end

        def /(obj : Infinity) : Symbolic
            NanC if self == 0
            return SZERO
        end

        def /(obj) : Symbolic
            return self if self == 0
            return Division.new(self,obj)
        end

        def opt_div(obj : Snumber) : Symbolic
            return self / obj
        end

        def **(obj : Snumber) : Symbolic
            return num2sym(@value ** obj.val)
        end

        def **(obj : Negative) : Symbolic
            return self if self == 1 || self == 0
            tmp = self ** obj.value 
            if tmp.is_a? Infinity
                return SZERO
            end
            return SONE / tmp.as(Symbolic)
        end

        def **(obj : PInfinity) : Symbolic
            return NanC if self == 0
            return self if self == 1
            return obj
        end

        def **(obj : NInfinity) : Symbolic
            return NanC if self == 0
            return self if self == 0
            return SZERO
        end

        def **(obj) : Symbolic
            return Power.new(self,obj)
        end

        def opt_power(obj : Snumber) : Symbolic?
            tmp = val ** obj.val
            if tmp != Float64::INFINITY
                return num2sym(tmp)
            else
                return Power.new(self,obj)
            end 
        end

        def eval(dict : LcHash) : Num
            return @value 
        end

        def diff(obj : Symbolic) : Symbolic
            return SZERO
        end

        def to_s(io)
            io << @value 
        end

        def to_s 
            return @value.to_s 
        end

        def ==(obj : Num)
            return @value == obj 
        end

        def ==(obj : Snumber)
            return @value == obj.val
        end

        def ==(obj)
            return false 
        end

        def depend?(obj)
            return false 
        end

    end

    SZERO = Snumber.new(0)
    SONE  = Snumber.new(1)
    STWO  = Snumber.new(2)
    
end