
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

    class Sqrt < Function

        def self.create(obj : Snumber)
            return obj if obj == 0 || obj == 1
            return Sqrt.new(obj)
        end

        def self.create(obj : Negative)
            return NanC if obj.value.is_a? Snumber
            return Sqrt.new(obj)
        end

        def self.create(obj : PInfinity)
            return obj 
        end

        def self.create(obj : NInfinity)
            return NanC 
        end

        def self.create(obj)
            return Sqrt.new(obj)
        end

        def +(obj : Sqrt)
            return self * STWO if obj == self 
            return Sum.new(self,obj)
        end

        def opt_sum(obj : Sqrt)
            return self * STWO if obj == self
            nil 
        end

        def -(obj : Sqrt)
            return SZERO if self == obj 
            return Sub.new(self,obj)
        end

        def opt_sub(obj : Sqrt)
            return SZERO if self == obj 
            nil 
        end

        def *(obj : Sqrt)
            return Sqrt.create(value * obj.value)
        end

        def *(obj : Power)
            if (tmp = value) == obj.left 
                return tmp ** (STWO + obj.right)
            end
            return Product.new(self,obj)
        end

        def opt_prod(obj : Sqrt)
            tmp = value.opt_prod(obj.value)
            return Sqrt.create(tmp) if tmp 
            nil 
        end

        def opt_prod(obj : Power)
            if (tmp = value) == obj.left 
                return tmp ** (STWO + obj.right)
            end
            nil 
        end

        def /(obj : Sqrt)
            return Sqrt.create(value / obj.value)
        end

        def /(obj : Power)
            if (tmp = value) == obj.left 
                return tmp ** (STWO - obj.right)
            end
            return Division.new(self,obj)
        end

        def opt_div(obj : Sqrt)
            tmp = value.opt_div(obj.value)
            return Sqrt.create(obj) if tmp 
            nil 
        end

        def opt_div(obj : Power)
            if (tmp = value) == obj.left 
                return tmp ** (STWO - obj.right)
            end
            nil 
        end

        def **(obj : Snumber)
            if obj == 0 || obj == 1
                return super(obj)
            end
            return value if obj == 2
            return value ** (obj / STWO)
        end

        def opt_power(obj : Snumber)
            if obj == 1 || obj == 1
                return super(obj)
            end
            return value if obj == 2
            if obj.val.even?
                return value ** (obj / STWO)
            end
            nil 
        end

        def diff(obj : Symbolic)
            return SZERO unless self.depend? obj 
            tmp = value 
            return tmp.diff(obj) / (self * STWO)
        end

        def eval(dict : LcHash)
            return Math.sqrt(value.eval(dict))
        end

        def to_s(io)
            io << "sqrt("
            value.to_s(io)
            io << ')'
        end

        def to_s 
            return String.build do |io|
                to_s(io)
            end
        end



    end
    
end