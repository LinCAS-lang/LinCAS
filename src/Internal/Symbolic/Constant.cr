
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

        def +(obj : Snumber)
            return SZERO if obj == 0
            return self if obj == 1
            return Sum.new(self,obj)
        end 

        def +(obj : Constant)
            return Product.new(STWO,obj) if self == obj
            return Sum.new(self,obj)
        end

        def +(obj : Negative)
            return self - obj.value 
        end

        def +(obj : Infinity)
            return obj 
        end

        def +(obj : BinaryOp)
            return obj + self 
        end

        def +(obj)
            return Sum.new(self,obj)
        end

        def opt_sum(obj : Constant)
            return Product.new(STWO,obj) if self == obj
            nil 
        end

        def -(obj : Constant)
            return num2sym(0) if self == obj 
            return nil unless self.top 
            return Sub.new(self,obj)
        end

        def -(obj : Negative)
            val = obj.value 
            return self - obj 
        end

        def -(obj : Sum)
             return self - obj.left - obj.right
        end

        def -(obj : Sub)
            return self - obj.left + obj.right
        end

        def -(obj)
            return nil unless self.top
            return Sub.new(self,obj).reduce
        end

        def - 
            return Negative.new(self)
        end

        def *(obj : Snumber)
            return obj if obj == 0
            return self if obj == 1
            return Product.new(obj,self)
        end

        def *(obj : Constant)
            return Power.new(self,STWO) if self == obj
            return Product.new(self,obj)
        end

        def *(obj : Negative)
            return -(self * obj.value)
        end

        def *(obj : BinaryOp)
            return obj * self 
        end

        def *(obj : Infinity)
            return obj 
        end

        def *(obj)
            return Prod.new(self,obj)
        end

        def opt_prod(obj : Constant)
            return self * obj if self == obj 
        end

        def /(obj : Snumber)
            return PinfinityC if obj == 0
            return self if obj == 1
            return Division.new(self,obj)
        end

        def /(obj : Negative)
            return -(self / obj.value)
        end

        def /(obj : Infinity)
            return SZERO
        end

        def /(obj : Constant)
            return SONE if obj == self
            return Division.new(self,obj)
        end

        def /(obj)
            return Division.new(self,obj)
        end

        def opt_div(obj : Constant)
            return SONE if self == obj 
            nil 
        end

        def **(obj : Snumber)
            return SONE if obj == 0
            return self if obj == 1
            return  Power.new(self,obj)
        end

        def **(obj : Negative)
            return SONE / (self ** obj.value)
        end

        def **(obj : PInfinity)
            return obj 
        end

        def **(obj : NInfinity)
            return SZERO
        end

        def **(obj)
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

    struct PI < Constant

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
