
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

    abstract struct Constant < SBaseS

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
