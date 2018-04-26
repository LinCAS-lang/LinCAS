
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

        def +(obj : Variable) : Symbolic
            return Product.new(STWO,self) if self == obj 
            return Sum.new(self,obj)
        end

        def +(obj : BinaryOp) : Symbolic
            return obj + self
        end

        def +(obj : Negative) : Symbolic
            return self - obj.value 
        end

        def +(obj : Snumber) : Symbolic
            return self if obj == 0
            return Sum.new(self,obj)
        end

        def +(obj : Symbolic) : Symbolic
            return Sum.new(self,obj)
        end

        def opt_sum(obj : Variable) : Symbolic?
            return Product.new(STWO,self) if self == obj 
            return nil 
        end

        def -(obj : Variable) : Symbolic
            return SZERO if self == obj
            return Sub.new(self,obj)
        end

        def -(obj : Negative) : Symbolic
            return self + obj.value
        end

        def -(obj : Snumber) : Symbolic
            return self if obj == 0
            return Sub.new(self,obj)
        end

        def -(obj : Symbolic) : Symbolic
            return Sub.new(self,obj)
        end

        def - : Symbolic
            return Negative.new(self)
        end

        def opt_sub(obj : Variable) : Symbolic?
            return SZERO if self == obj 
            return nil 
        end

        def *(obj : Variable) : Symbolic
            return Power.new(self,STWO) if self == obj 
            return Product.new(self,obj)
        end

        def *(obj : BinaryOp) : Symbolic
            return obj * self 
        end

        def *(obj : Snumber) : Symbolic
            return obj if obj == 0
            return self if obj == 1
            return Product.new(obj, self)
        end

        def *(obj : Symbolic) : Symbolic
            return Product.new(self,obj)
        end

        def opt_prod(obj : Variable) : Symbolic?
            return Power.new(self,STWO) if self == obj
            return nil 
        end

        def /(obj : Snumber) : Symbolic
            return self if obj == 1
            return PinfinityC if obj == 0
            return Division.new(self,obj)
        end

        def /(obj : Variable) : Symbolic
            return SONE if self == obj 
            return Division.new(self,obj)
        end 

        def /(obj : Product) : Symbolic
            return self / (obj.right / obj.left).as(Symbolic)
        end

        def /(obj : Division) : Symbolic
            return (self * obj.right).as(Symbolic) / obj.left
        end

        def /(obj : Power) : Symbolic
            if obj.left == self
                exp = obj.right - SONE
                return self ** (- exp)
            end
            return Division.new(self,obj)
        end

        def /(obj : Symbolic) : Symbolic
            return Division.new(self,obj)
        end

        def opt_div(obj : Variable) : Symbolic?
            return SONE if self == obj
            nil 
        end

        def **(obj : Snumber) : Symbolic
            return SONE if obj == 0
            return self if obj == 1
            return Power.new(self,obj)
        end

        def **(obj : Symbolic) : Symbolic
            return Power.new(self,obj)
        end

        def diff(obj : Symbolic) : Symbolic
            return SONE if self == obj 
            return SZERO
        end

        def eval(dict : LcHash) : Num
            bytes = @name.to_slice
            if Internal.lc_hash_hash_key(dict,bytes)
                return num2num(lc_hash_fetch(dict,bytes))
            else
                Exec.lc_raise(LcKeyError,"Dictionary does not contain '#{@name}'")
                return 1 
            end
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
