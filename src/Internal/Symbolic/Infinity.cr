
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

    abstract struct Infinity < SBaseS

        abstract def value

        nan_ops

        def +(obj : Variable)
            return Sum.new(self,obj)
        end

        def +(obj : Negative)
            return self - obj.value 
        end

        def +(obj : Infinity)
            return self 
        end

        def +(obj : NInfinity)
            return NanC
        end

        def +(obj : Function)
            return Sum.new(self,obj)
        end

        def +(obj : BinaryOp)
            return obj + self 
        end

        def +(obj)
            return self 
        end

        def opt_sum(obj : PInfinity)
            return self
        end

        def opt_sum(obj : Snumber)
            return self 
        end

        def -(obj : Snumber)
            return self 
        end

        def -(obj : Variable)
            return Sub.new(self,obj)
        end

        def -(obj : Negative)
            return self + obj.value
        end

        def -(obj : NInfinity)
            return self 
        end

        def -(obj : Infinity)
            return NanC
        end

        def -(obj : Constant)
            return self 
        end

        def -(obj : Function)
            return Sub.new(self,obj)
        end

        def -(obj : Sum)
            return self - obj.left - obj.right
        end

        def -(obj : Sub)
            return self - obj.left + obj.right
        end

        def -(obj)
            return Sub.new(self,obj)
        end

        def -
            return NinfinityC
        end

        def opt_sub(obj : Snumber)
            return self 
        end

        def opt_sub(obj : NInfinity)
            return self 
        end

        def *(obj : Snumber)
            return NanC
        end

        def *(obj : Variable)
            return Product.new(self,obj)
        end

        def *(obj : Negative)
            return -(self * obj.value)
        end

        def *(obj : Infinity)
            return obj 
        end

        def *(obj : Function)
            return Product.new(self,obj)
        end

        def *(obj : BinaryOp)
            return obj * self
        end

        def *(obj)
            return self
        end

        def opt_prod(obj : Infinity)
            return obj 
        end

        def /(obj : Snumber)
            return self 
        end

        def /(obj : Infinity)
            return NanC
        end

        def /(obj : Constant)
            return self 
        end
        
        def /(obj : Product)
            return self / obj.left / obj.right 
        end

        def /(obj : Division)
            return self / obj.left * obj.right 
        end

        def /(obj)
            return Division.new(self,obj)
        end

        def **(obj : Snumber)
            if obj == 0
                return SONE
            end
            return self 
        end

        def **(obj : PInfinity)
            return self 
        end

        def **(obj : NInfinity)
            return SZERO
        end

        def **(obj : Constant)
            return self
        end

        def **(obj)
            return Power.new(self,obj)
        end

        def eval(dict)
            return Float64::INFINITY 
        end

        def diff(obj)
            return SZERO
        end

        def to_s(io)
            io << '∞'
        end

        def to_s 
            return "∞"
        end

        def depend?(obj)
            false 
        end

    end

    struct PInfinity < Infinity
        def value 
            return Float64::INFINITY
        end
    end

    struct NInfinity < Infinity

        def value 
            return -Float64::INFINITY
        end

        def +(obj : PInfinity)
            return  NanC
        end

        def +(obj : NInfinity)
            return self 
        end

        def opt_sum(obj : NInfinity)
            return self 
        end

        def -(obj : NInfinity)
            return NanC
        end

        def -(obj : Infinity)
            return self 
        end

        def - 
            return NinfinityC
        end

        def opt_sub(obj : NInfinity)
            nil 
        end

        def opt_sub(obj : PInfinity)
            return self 
        end

        def *(obj : NInfinity)
            return PinfinityC
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

    PinfinityC  = PInfinity.new 
    NinfinityC  = NInfinity.new

end