
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

    class Sub < BinaryOp

        nan_ops

        def +(obj : Negative)
            return self - obj.value
        end

        def +(obj : Sum)
            return self + obj.left + obj.right
        end

        def +(obj : Sub)
            return self + obj.left - obj.right 
        end

        def +(obj)
            return self if obj == 0
            lft = @left.opt_sum(obj).as(Symbolic?)
            return Sub.new(lft,@right) if lft 
            rht = @right.opt_sum(obj).as(Symbolic?)
            return Sub.new(@left,rht) if rht 
            return Sum.new(self,obj)
        end

        def opt_sum(obj)
            return self if obj == 0
            lft = @left.opt_sum(obj).as(Symbolic?)
            return Sub.new(lft,@right) if lft 
            rht = @right.opt_sum(obj).as(Symbolic?)
            return Sub.new(@left,rht) if rht
            nil
        end

        def -(obj : Negative)
            return self + obj.value
        end

        def -(obj : Sum)
            return self - obj.left - obj.right 
        end

        def -(obj : Sub)
            return self - obj.left + obj.right 
        end

        def -(obj)
            return self if obj == 0
            lft = @left.opt_sub(obj)
            return Sub.new(lft,@right) if lft 
            rht = @right.opt_sum(obj)
            return Sub.new(@left,rht) if rht 
            return Sub.new(self,obj)
        end

        def -
            return @right - @left
        end

        def opt_sub(obj)
            return self if obj == 0
            lft = @left.opt_sub(obj).as(Symbolic?)
            return Sub.new(lft,@right) if lft 
            rht = @right.opt_sub(obj).as(Symbolic?)
            return Sub.new(@left,rht) if rht 
            nil
        end

        def *(obj : Negative)
            return -(self * obj.value)
        end

        def *(obj : NInfinity)
            return -(self * PinfinityC)
        end

        def *(obj)
            return SZERO if obj == 0
            return self if obj == 1
            lft = @left.opt_prod(obj)
            rht = @right.opt_prod(obj)
            return lft - rht if lft && rht 
            return Product.new(self,obj) unless obj.is_a? Snumber
            return Product.new(obj,self)
        end

        def opt_prod(obj)
            return SZERO if obj == 0
            return self if obj == 1
            lft = @left.opt_prod(obj)
            rht = @right.opt_prod(obj)
            return lft - rht if lft && rht
            return self ** STWO if self == obj
            nil 
        end

        def /(obj : Negative)
            return -(self / obj.value)
        end

        def /(obj : Sub)
            return SONE if self == obj 
            return Division.new(self,obj)
        end

        def /(obj : Infinity)
            return SZERO
        end

        def /(obj : Division)
            return (self / obj.left).as(Symbolic) * obj.right
        end

        def /(obj)
            return self if obj == 1
            lft = @left.opt_div(obj).as(Symbolic?)
            rht = @right.opt_div(obj).as(Symbolic?)
            return lft - rht if lft && rht
            return Product.new(self,PinfinityC) if obj == 0
            return Division.new(self,obj)
        end

        def opt_div(obj) : Symbolic?
            return self if obj == 1
            lft = @left.opt_div(obj).as(Symbolic?) 
            rht = @right.opt_div(obj).as(Symbolic?)
            return lft - rht if lft && rht
            nil
        end

<<<<<<< HEAD
        def reduce

=======
        def **(obj : Negative)
            return SONE / (self ** obj.value).as(Symbolic)
        end

        def **(obj : PInfinity)
            return obj 
        end

        def **(obj : NInfinity)
            return SZERO
        end

        def **(obj)
            return SONE if obj == 0
            return self if obj == 1
            return Power.new(self,obj)
>>>>>>> lc-vm
        end

        def diff(obj)
            return SZERO unless self.depend? obj 
            lft = @left.diff(obj)
            rht = @right.diff(obj)
            return lft - rht 
        end

        def eval(dict : LcHash)
            lft = @left.eval(dict)
            rht = @right.eval(dict)
            return lft - rht 
        end

        def to_s(io)
            @left.to_s(io)
            io << " - "
            @right.to_s(io)
        end

        def to_s
            return String.build do |io|
                to_s(io)
            end
        end

        protected def append(io,elem)
            unless ({Sum,Sub,Power}.includes? elem.class) || !(elem.is_a? BinaryOp)
                io << '('
                elem.to_s(io)
                io << ')'
            else
                elem.to_s(io)
            end 
        end
        
    end
    
end