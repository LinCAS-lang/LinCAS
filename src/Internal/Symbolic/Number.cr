
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

    struct Snumber < SBaseS

        private def mcd(a,b)
            a,b = b,a unless b < a 
            while b != 0 
                a,b = b, a % b 
            end 
            return a 
        end

        getter value

        def initialize(@value : Num)
        end

        @[AlwaysInline]
        def +(obj : Snumber)
            return obj if self == 0
            return num2sym(@value + sym2num(obj))
        end

        def +(obj : BinaryOp)
            return obj if self == 0
            return obj + self
        end

        def +(obj : Infinity)
            return obj 
        end

        def +(obj : Negative)
            return self - obj.value 
        end

        def +(obj)
            return Sum.new(obj,self)
        end

        def opt_sum(obj : Snumber)
            return num2sym(@value + sym2num(obj))
        end

        def opt_sum(obj : Infinity)
            return obj 
        end

        def -(obj : Snumber)
            return -obj if self == 0
            tmp = @value - obj.value
            if tmp < 0
                return -num2sym(-tmp)
            end
            return num2sym(tmp)
        end

        def -(obj : Negative)
            return self + obj.value 
        end

        def -(obj : NInfinity)
            return PinfinityC
        end

        def -(obj : PInfinity)
            return NinfinityC
        end

        def -(obj)
            return Sub.new(self,obj)
        end

        def -
            return Negative.create(self)
        end

        def opt_sub(obj : Snumber)
            return -obj if self == 0
            tmp = @value - obj.value
            if tmp < 0
                return -num2sym(-tmp)
            end
            return num2sym(tmp)
        end

        def opt_sub(obj : PInfinity)
            return NinfinityC
        end

        def opt_sub(obj : NInfinity)
            return PinfinityC
        end

        def *(obj : Snumber)
            return self if self == 0
            return obj if self == 1
            return num2sym(@value * obj.value)
        end

        def *(obj : BinaryOp)
            return obj * self 
        end

        def *(obj : Negative)
            return -(self * obj.value )
        end

        def *(obj : Infinity)
            return NanC if self == 0
            return obj 
        end

        def *(obj)
            return Product.new(self,obj)
        end

        def opt_prod(obj : Snumber)
            return self * obj 
        end

        def /(obj : Snumber)
            return NanC if self == 0 && obj == 0
            return PinfinityC if obj == 0
            return self if obj == 1
            _mcd = mcd(@value,obj.value)
            return Division.new(@value,obj.value) if _mcd == 1
            v1 = @value / _mcd 
            v2 = obj.value / _mcd 
            return sym2num(v1) if v2 == 1 
            return Division.new(num2sym(v1),num2sym(v2))
        end 

        def /(obj : Negative)
            return -(self / obj.value)
        end

        def /(obj : Infinity)
            NanC if self == 0
            return SZERO
        end

        def /(obj)
            return self if self == 0
            return Division.new(self,obj)
        end

        def opt_div(obj : Snumber)
            return self / obj 
        end

        def **(obj : Snumber)
            return num2sym(@value ** obj.value)
        end

        def **(obj : Negative)
            return self if self == 1 || self == 0
            tmp = self ** obj.value 
            if tmp.is_a? Infinity
                return SZERO
            end
            return SONE / tmp
        end

        def **(obj : PInfinity)
            return NanC if self == 0
            return self if self == 1
            return obj
        end

        def **(obj : NInfinity)
            return NanC if self == 0
            return self if self == 0
            return SZERO
        end

        def **(obj)
            return Power.new(self,obj)
        end

        def opt_power(obj : Snumber)
            return self ** obj 
        end

        def eval(dict : LcHash)
            return @value 
        end

        def diff(obj)
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
            return @value == obj.value 
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
