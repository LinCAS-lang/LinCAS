
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

    abstract struct Constant < SBaseS

        nan_ops

        abstract def value

        def +(obj : Snumber) : Symbolic
            return SZERO if obj == 0
            return self if obj == 1
            return Sum.new(self,obj)
        end 

        def +(obj : Constant) : Symbolic
            return Product.new(STWO,obj) if self == obj
            return Sum.new(self,obj)
        end

        def +(obj : Negative) : Symbolic
            return self - obj.value 
        end

        def +(obj : Infinity) : Symbolic
            return obj 
        end

        def +(obj : BinaryOp) : Symbolic
            return obj + self 
        end

        def +(obj : Symbolic) : Symbolic
            return Sum.new(self,obj)
        end

        def opt_sum(obj : Constant) : Symbolic?
            return Product.new(STWO,obj) if self == obj
            nil 
        end

        def -(obj : Constant) : Symbolic
            return SZERO if self == obj 
            return Sub.new(self,obj)
        end

        def -(obj : Negative) : Symbolic
            val = obj.value 
            return self - obj 
        end

        def -(obj : Sum) : Symbolic
             return self - obj.left - obj.right
        end

        def -(obj : Sub) : Symbolic
            return self - obj.left + obj.right
        end

        def -(obj : Symbolic) : Symbolic
            return Sub.new(self,obj)
        end

        def - : Symbolic
            return Negative.new(self)
        end

        def *(obj : Snumber) : Symbolic
            return obj if obj == 0
            return self if obj == 1
            return Product.new(obj,self)
        end

        def *(obj : Constant) : Symbolic
            return Power.new(self,STWO) if self == obj
            return Product.new(self,obj)
        end

        def *(obj : Negative) : Symbolic
            return -(self * obj.value)
        end

        def *(obj : BinaryOp) : Symbolic
            return obj * self 
        end

        def *(obj : Infinity) : Symbolic
            return obj 
        end

        def *(obj : Symbolic) : Symbolic
            return Product.new(self,obj)
        end

        def opt_prod(obj : Constant) : Symbolic?
            return self * obj if self == obj 
            nil
        end

        def /(obj : Snumber) : Symbolic
            return PinfinityC if obj == 0
            return self if obj == 1
            return Division.new(self,obj)
        end

        def /(obj : Negative) : Symbolic
            return -(self / obj.value)
        end

        def /(obj : Infinity) : Symbolic
            return SZERO
        end

        def /(obj : Constant) : Symbolic
            return SONE if obj == self
            return Division.new(self,obj)
        end

        def /(obj : Symbolic) : Symbolic
            return Division.new(self,obj)
        end

        def opt_div(obj : Constant) : Symbolic?
            return SONE if self == obj 
            nil 
        end

        def **(obj : Snumber) : Symbolic
            return SONE if obj == 0
            return self if obj == 1
            return  Power.new(self,obj)
        end

        def **(obj : Negative) : Symbolic
            return SONE / (self ** obj.value).as(Symbolic)
        end

        def **(obj : PInfinity) : Symbolic
            return obj 
        end

        def **(obj : NInfinity) : Symbolic
            return SZERO
        end

        def **(obj : Symbolic) : Symbolic
            return Power.new(self,obj)
        end

        def ==(obj)
            self.class == obj.class 
        end

        def diff(obj)
            return SZERO
        end

        def depend?(obj)
            false 
        end

    end


    struct E < Constant
        
        def value 
            return Math::E 
        end 

        def eval(dict)
            return Math::E 
        end

        def to_s(io)
            io << 'e'
        end 

        def to_s 
            return "e"
        end
    end

    EC = E.new

    struct PI < Constant

        def value 
            return Math::E 
        end

        def eval(dict)
            return Math::PI
        end

        def to_s(io)
            io << 'π'
        end 

        def to_s 
            return 'π'
        end
    end

    PiC = PI.new
    
end