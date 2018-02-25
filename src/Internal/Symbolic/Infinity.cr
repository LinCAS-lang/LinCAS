
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