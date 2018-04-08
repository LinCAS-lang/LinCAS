
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
    

    struct Infinity < Constatnt

        def +(obj : Infinity)
            return self 
        end

        def +(obj : Ninfinity)
            Exec.lc_raise(LcMathError,"(∞-∞)")
            return self 
        end

        def +(obj : Constant)
            return self
        end 

        def +(obj : BinaryOp)
            return obj + self 
        end

        def +(obj : Snumber)
            return self 
        end

        def +(obj : Negative)
            return self - obj.value 
        end

        def -(obj : Ninfinity)
            return self 
        end

        def -(obj : Infinity)
            Exec.lc_raise(LcMathError,"(∞-∞)")
            return self 
        end

        def -
            return NinfinityC
        end

        def *(obj : Ninfinity)
            return obj 
        end

        def *(obj : Negative)
            return -(self * obj.value)
        end

        def *(obj : Constant)
            return self 
        end

        def *(obj : Snumber)
            if obj == 0
                Exec.lc_raise(LcMathError,"(∞*0)")
                return num2sym(0)
            end
            return self 
        end

        def *(obj : BinaryOp)
            return obj * self
        end

        def *(obj)
            return nil unless self.top 
            return Product.new(self,obj)
        end

        def /(obj : Infinity | Ninfinity)
            Exec.lc_raise(LcMathError,"(∞/∞)")
            return num2sym(0)
        end

        def /(obj : Constant)
            return self 
        end

        def /(obj : Snumber)
            if obj == 0
                Exec.lc_raise(LcMathError,"(∞/0)")
            end
            return self
        end

        def **(obj : Snumber)
            if obj == 0
                Exec.lc_raise(LcMathError,"(∞^0)")
                return num2sym(0)
            end
            return self 
        end

        def **(obj : Infinity | Ninfinity)
            Exec.lc_raise(LcMathError,"(∞^∞)")
            return self 
        end

        def **(obj : Constant)
            return self
        end

        def eval(dict)
            return Float64::INFINITY 
        end

        def reduce
            return self 
        end

        def diff(obj)
            return num2sym(0)
        end

        def to_s(io)
            io << '∞'
        end

        def to_s 
            return '∞'
        end

    end

    struct Ninfinity < Infinity

        def +(obj : Infinity)
            Exec.lc_raise(LcMathError,"(∞-∞)")
            return self  
        end

        def +(obj : Ninfinity)
            return self 
        end

        def -(obj : Ninfinity)
            Exec.lc_raise(LcMathError,"(∞-∞)")
            return self 
        end

        def -(obj : Infinity)
            return self 
        end

        def - 
            return InfinityC
        end

        def *(obj : Ninfinity)
            return InfinityC
        end

        def *(obj : Infinity)
            return self 
        end

        def eval(dict)
            return -Float64::INFINITY 
        end

        def to_s(io)
            io << "-∞"
        end

        def to_s 
            return "-∞"
        end

    end

    InfinityC  = Infinity.new 
    NinfinityC = Ninfinity.new

end
