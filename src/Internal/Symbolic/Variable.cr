
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

    struct Variable < SBaseS

        getter name

        def initialize(@name : String)
        end

        def +(obj : Variable)
            return Product.new(STWO,self) if self == obj 
            return Sum.new(self,obj)
        end

        def +(obj : BinaryOp)
            return obj + self
        end

        def +(obj : Negative)
            return self - obj.value 
        end

        def +(obj : Snumber)
            return self if obj == 0
            return Sum.new(self,obj)
        end

        def +(obj)
            return Sum.new(self,obj)
        end

        def opt_sum(obj : Variable)
            return Product.new(STWO,self) if self == obj 
            return nil 
        end

        def -(obj : Variable)
            return SZERO if self == obj
            return Sub.new(self,obj)
        end

        def -(obj : Negative)
            return self + obj.value
        end

        def -(obj : Snumber)
            return self if obj == 0
            return Sub.new(self,obj)
        end

        def -(obj)
            return Sub.new(self,obj).reduce
        end

        def -
            return Negative.new(self)
        end

        def opt_sub(obj : Variable)
            return SZERO if self == obj 
            return nil 
        end

        def *(obj : Variable)
            return Power.new(self,STWO) if self == obj 
            return Product.new(self,obj)
        end

        def *(obj : BinaryOp)
            return obj * self 
        end

        def *(obj : Snumber)
            return obj if obj == 0
            return self if obj == 1
            return Product.new(obj, self)
        end

        def *(obj)
            return Product.new(self,obj)
        end

        def opt_prod(obj : Variable)
            return Power.new(self,STWO) if self == obj
            return nil 
        end

        def /(obj : Snumber)
            return self if obj == 1
            return PinfinityC if obj == 0
            return Division.new(self,obj)
        end

        def /(obj : Variable)
            return SONE if self == obj 
            return Division.new(self,obj)
        end 

        def /(obj : Product)
            return self / obj.right / obj.left
        end

        def /(obj : Division)
            return (self * obj.right) / obj.left
        end

        def /(obj : Power)
            if obj.left == self
                exp = obj.right - SONE
                return self ** (- exp)
            end
            return Division.new(self,obj)
        end

        @[AlwaysInline]
        def /(obj)
            return Division.new(self,obj).reduce
        end

        def opt_div(obj : Variable)
            return SONE if self == obj
            nil 
        end

        def **(obj : Snumber)
            return SONE if obj == 0
            return self if obj == 1
            return Power.new(self,obj)
        end

        def **(obj)
            return Power.new(self,obj)
        end

        def opt_power(obj)
            return nil 
        end

        def diff(obj)
            return num2sym(1) if self == obj 
            return num2sym(0)
        end

        def eval(dict)

        end

        @[AlwaysInline]
        def to_s(io)
            io << @name 
        end
        
        @[AlwaysInline]
        def to_s
            return @name 
        end

        def ==(obj : Variable)
            return @name == obj.name
        end
        
        def ==(obj)
            false 
        end

        @[AlwaysInline]
        def depend?(obj)
            return self == obj 
        end

    end

end
