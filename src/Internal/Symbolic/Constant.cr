
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
