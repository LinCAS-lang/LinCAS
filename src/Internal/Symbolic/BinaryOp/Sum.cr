
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
    
    class Sum < BinaryOp

        nan_ops
        
        def +(obj : Negative) : Symbolic
            return self - obj.value.as(Symbolic) 
        end

        def +(obj : Sum) : Symbolic
            return (self + obj.left).as(Symbolic) + obj.right
        end

        def +(obj : Sub) : Symbolic
            return self + obj.left - obj.right
        end

        def +(obj) : Symbolic
            return self if obj == 0
            lft = @left.opt_sum(obj).as(Symbolic?)
            return lft + @right if lft
            rht = @right.opt_sum(obj).as(Symbolic?)
            return @left + rht if rht 
            return Sum.new(self,obj)
        end

        def opt_sum(obj : Symbolic) : Symbolic?
            lft = @left.opt_sum(obj).as(Symbolic?)
            return left + @right if lft
            rht = @right.opt_sum(obj).as(Symbolic?)
            return @left + rht if rht 
            nil 
        end

        def -(obj : Negative) : Symbolic
            return self + obj.value
        end

        def -(obj : Sum) : Symbolic
            return self - obj.left - obj.right 
        end

        def -(obj : Sub) : Symbolic
            return self - obj.left + obj.right 
        end

        def -(obj : Symbolic) : Symbolic
            return self if obj == 0
            lft = @left.opt_sub(obj)
            return left + @right if lft
            rht = @right.opt_sub(obj)
            return @left + rht if rht 
            return Sub.new(self,obj)
        end

        def - : Symbolic
            return Negative.new(self)
        end

        def opt_sub(obj : Symbolic) : Symbolic?
            lft = @left.opt_sub(obj).as(Symbolic?)
            return left + @right if lft
            rht = @right.opt_sub(obj).as(Symbolic?)
            return @left + rht if rht 
            nil 
        end

        def *(obj : Negative) : Symbolic
            return -(self * obj.value)
        end

        def *(obj : Infinity) : Symbolic
            lft = @left.opt_prod(obj)
            return lft + @right if lft 
            rht = @right.opt_prod(obj)
            return @left + rht if rht 
            return Product.new(self,obj)
        end

        def *(obj : Symbolic) : Symbolic
            return self if obj == 1
            return SZERO if obj == 0
            return Power.new(self,STWO) if self == obj
            return Product.new(self,obj)
        end

        def opt_prod(obj : Symbolic) : Symbolic?
            return self if obj == 1
            lft = @left.opt_prod(obj)
            return lft + @right if lft 
            rht = @right.opt_prod(obj)
            return @left + rht if rht 
            return self ** STWO if self == obj
            nil
        end

        def /(obj : Negative) : Symbolic
            return -(self / obj.value)
        end

        def /(obj : Infinity) : Symbolic
            return SZERO
        end

        def /(obj : Sum) : Symbolic
            return SONE if self == obj
            return Division.new(self,obj)
        end

        def /(obj) : Symbolic
            return self if obj == 1
            lft = @left.opt_div(obj).as(Symbolic?)
            rht = @right.opt_div(obj).as(Symbolic?)
            return lft + rht if lft && rht 
            return Product.new(self,PinfinityC) if obj == 0
            return Division.new(self,obj)
        end

<<<<<<< HEAD
        def reduce
            super 
            if @left == 0
                return @right 
            elsif @right == 0
                return @left 
            elsif @left == InfinityC && @right == InfinityC
                return InfinityC
            elsif @left == NinfinityC && @right == NinfinityC
                return NinfinityC
            elsif @left.is_a? Infinity && @right.is_a? Infinity 
                Exec.lc_raise(LcMathError,"(∞-∞)"))
                return @left 
            elsif (@left.is_a? Snumber) && (@right.is_a? Snumber)
                return sym2num(@left.value + @right.value)
            elsif @left.is_a? Negative
                return Sub.new(@right,@left.value)
            elsif @right.is_a? Negative
                return Sub.new(@left,@right.value)
            elsif (@left.is_a? Constant) && (@right.is_a? Constant)
                return @left + @right
            elsif @left == @right
                return Product.new(num2sym(2),@left) 
            end 
            return self
        end 
=======
        def opt_div(obj : Symbolic) : Symbolic?
            return self if obj == 1
            lft = @left.opt_div(obj).as(Symbolic?)
            rht = @right.opt_div(obj).as(Symbolic?)
            return lft + rht if lft && rht  
            nil
        end
>>>>>>> lc-vm

        def **(obj : PInfinity) : Symbolic
            return obj 
        end

        def **(obj : NInfinity) : Symbolic
            return SZERO
        end

        def **(obj : Symbolic) : Symbolic
            return SONE if obj == 0
            return self if obj == 1
            return Power.new(self,obj)
        end

        def diff(obj : Symbolic) : Symbolic
            return SZERO unless self.depend? obj
            lft = @left.diff(obj)
            rht = @right.diff(obj)
            return lft + rht 
        end

        def eval(dict : LcHash) : Num
            lft = @left.eval(dict)
            rht = @right.eval(dict)
            return lft + rht 
        end

        def to_s(io)
            @left.to_s(io)
            io << " + "
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