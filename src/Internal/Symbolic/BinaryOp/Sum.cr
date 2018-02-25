
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
    
    struct Sum < BinaryOp
        
        def +(obj : Variable | Snumber | Constant | Function)
            lft = @left + obj 
            return Sum.new(lft,@right) if lft 
            rht = @right + obj 
            return Sum.new(@left,rht) if rht 
            return nil unless self.top 
            return Sum.new(self,obj)
        end

        def +(obj : Negative)
            return self - obj.value 
        end

        def +(obj : Sum)
            tmp = self + obj.left + obj.right
            # return nil unless self.top 
            return tmp 
        end

        def +(obj : Sub)
            tmp = self + obj.left - obj.right
            return tmp 
        end

        def +(obj)
            return nil unless sel.top 
            return Sum.new(self,obj)
        end

        def -(obj : Sum)
            return self - obj.left - obj.right 
        end

        def -(obj : Sub)
            return self - obj.left + obj.right 
        end

        def -(obj : Variable | Snumber | Constant | Function)
            lft = @left - obj 
            return Sum.new(lft,@right) if lft 
            rht = @right - obj 
            return Sum.new(@left,rht) if rht 
            return nil unless self.top 
            return Sub.new(self,obj)
        end

        def -(obj)
            return nil unless self.top 
            return Sub.new(self,obj)
        end

        def -
            return Negative.new(self)
        end

        def *(obj)
            return nil unless self.top 
            return Product.new(self,obj)
        end

        def /(obj)
            return nil unless self.top 
            return Division.new(self,obj)
        end

        def **(obj)
            return nil unless self.top
            return Power.new(self,obj)
        end

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
                Exec.lc_raise(LcMathError,"(∞-∞)")
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

        def diff(obj)
            return num2sym(0) unless self.depend? obj
            lft = @left.diff(obj)
            rht = @right.diff(obj)
            return lft + rht 
        end

        def eval(dict)
            lft = @left.eval(dict)
            rht = @right.eval(dict)
            return lft + rht 
        end

    end

end