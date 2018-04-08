
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

    abstract struct Constant < BaseS
    
        def initialize
            super()
        end

        def +(obj : Constant)
            return Product.new(num2sym(2),obj) if self == obj
            return nil unless self.top 
            return Sum.new(self,obj)
        end

        def +(obj : Negative)
            val = obj.value
            return self - val 
        end

        @[AlwaysInline]
        def +(obj)
            return nil unless self.top
            return Sum.new(self,obj)
        end

        @[AlwaysInline]
        def -(obj : Constant)
            return num2sym(0) if self == obj 
            return nil unless self.top 
            return Sub.new(self,obj)
        end

        def -(obj : Negative)
            val = obj.value 
            return self - obj 
        end

        def -(obj)
            return nil unless self.top
            return Sub.new(self,obj).reduce
        end

        @[AlwaysInline]
        def - 
            return Negative.new(self)
        end

        def *(obj : Constant)
            return Power.new(self,num2sym(2)) if self == obj
            return nil unless self.top 
            return Product.new(self,obj)
        end

        def *(obj : Snumber)
            return nil unless self.top 
            return Product.new(obj,self)
        end

        def *(obj : Negative)
            val = obj.value 
            return nil unless self.top && self == val 
            return Negative.new(self * val)
        end

        @[AlwaysInline]
        def *(obj : BinaryOp)
            return obj * self 
        end

        def *(obj)
            return nil unless self.top 
            return Prod.new(self,obj)
        end

        def /(obj : Constant)
            return num2sym(1) if obj == self
            return nil unless self == obj 
            return Division.new(self,obj)
        end

        def /(obj)
            return nil unless self.top 
            return Division.new(self,obj).reduce 
        end

        def **(obj)
            return nil unless self.top 
            return Power.new(self,obj)
        end

        @[AlwaysInline]
        def reduce 
            return self 
        end

        @[AlwaysInline]
        def ==(obj)
            self.class == obj.class 
        end

        @[AlwaysInline]
        def diff(obj)
            return num2sym(0)
        end

    end

    abstract struct Mconst < Constant
       
        getter value

        @[AlwaysInline]
        def +(obj : Infinity)
            return obj 
        end

        @[AlwaysInline]
        def +(obj : Ninfinity)
            return obj 
        end

        def +(obj)
            return super(obj)
        end

        @[AlwaysInline]
        def -(obj : Infinity)
            return NinfinityC
        end

        @[AlwaysInline]
        def -(obj : Ninfinity)
            return InfinityC
        end

        @[AlwaysInline]
        def -(obj)
            return super(obj)
        end

        @[AlwaysInline]
        def *(obj : Infinity)
            return obj 
        end

        @[AlwaysInline]
        def *(obj : Ninfinity)
            return obj 
        end

        def *(obj)
            return super(obj)
        end

        @[AlwaysInline]
        def /(obj : Infinity)
            return num2sym(0)
        end

        @[AlwaysInline]
        def /(obj : Ninfinity)
            return num2sym(0)
        end

        def /(obj)
            super(obj)
        end

        @[AlwaysInline]
        def **(obj : Infinity)
            return obj 
        end

        @[AlwaysInline]
        def **(obj : Ninfinity)
            return num2sym(0)
        end

        def **(obj)
            return super(obj)
        end

    end

    struct E < Mconst
        def eval(dict)
            return Math::E 
        end

        def to_s(io)
            io << 'e'
        end 

        def to_s 
            return 'e'
        end
    end

    struct PI < Mconst
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
    
end