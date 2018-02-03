
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

    struct Sub < BinaryOp

        def +(obj : Variable | Snumber | Constant | Function)
            lft = @left + obj 
            return Sub.new(lft,@right).reduce if lft 
            rht = @right + obj
            return Sub.new(@left,rht).reduce if rht
            return nil unless self.top 
            return Sub.new(self,obj).reduce 
        end

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
            return nil unless self.top 
            return Sum.new(self,obj).reduce 
        end

        def -(obj : Variable | Snumber | Constant | Function)
            lft = @left - obj 
            return Sub.new(lft,@right).reduce if lft 
            rht = @right - obj 
            return Sub.new(@left,rht).reduce if rht 
            return nil unless self.top 
            return Sub.new(self,obj).reduce 
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
            return nil unless self.top 
            return Sub.new(self,obj)
        end

        def -
            return @right - @left
        end

        def *(obj)
            return nil unless self.top 
            return Product.new(self,obj).reduce 
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

        end

        def diff(obj)
            return num2sym(0) unless self.depends? obj 
            lft = @left.diff(obj)
            rht = @right.diff(obj)
            return lft - rht 
        end

        def eval(dict)
            lft = @left.eval(dict)
            rht = @right.eval(dict)
            return lft - rht 
        end
    end
    
end