
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

    abstract class Function < SBaseC

        getter value : Symbolic

        def initialize(@value : Symbolic)
        end

        def +(obj : Snumber)
            return self if obj == 1
            return Sum.new(self,obj)
        end

        def +(obj : Negative)
            return self - obj.value 
        end

        def +(obj : PInfinity)
            if value.is_a? Snumber
                return obj 
            end
            return Sum.new(self,obj)
        end 

        def +(obj : NInfinity)
            if value.is_a? Snumber
                return obj 
            end
            return Sub.new(self,PinfinityC)
        end

        def +(obj : Sum)
            return obj + self 
        end

        def +(obj : Sub)
            return obj + self 
        end

        def +(obj)
            return Sum.new(self,obj)
        end

        def opt_sum(obj : Snumber)
            return self if obj == 0
            nil 
        end

        def opt_sum(obj : Infinity)
            return obj if value.is_a? Snumber
        end

        def -(obj : Snumber)
            return self if obj == 0
            return Sub.new(self,obj)
        end

        def -(obj : Negative)
            return self + obj.value 
        end

        def -(obj : PInfinity)
            if value.is_a? Snumber
                return NinfinityC
            end
            return Sub.new(self,obj)
        end

        def -(obj : NInfinity)
            if value.is_a? Snumber
                return PinfinityC 
            end
            return Sum.new(self,PinfinityC)
        end

        def -(obj : Sum)
            return self - obj.left - obj.right 
        end

        def -(obj : Sub)
            return self - obj.left + obj.right 
        end

        def -(obj)
            return Sub.new(self,obj)
        end

        def -
            return Negative.new(self)
        end

        def opt_sub(obj : Snumber)
            return self if obj == 0
            nil 
        end

        def opt_sub(obj : PInfinity)
            return NinfinityC if value.is_a? Snumber
            nil 
        end

        def opt_sub(obj : NInfinity)
            return PinfinityC if value.is_a? Snumber
            nil 
        end

        def *(obj : Snumber)
            return self if obj == 1
            return SZERO if obj == 0
            return Product.new(obj,self)
        end

        def *(obj : Negative)
            return -(self * obj.value)
        end

        def *(obj : PInfinity)
            return obj if value.is_a? Snumber
            return Product.new(self,obj.as(Symbolic))
        end

        def *(obj : NInfinity)
            return obj if value.is_a? Snumber
            return -Product.new(self,obj)
        end

        def *(obj : Product)
            return obj * self 
        end

        def *(obj : Division)
            return self / obj.right * obj.left 
        end

        def *(obj)
            return Product.new(self,obj)
        end

        def opt_prod(obj : Snumber)
            return self if obj == 1
            return SZERO if obj == 0
        end

        def opt_prod(obj : Infinity)
            return obj if value.is_a? Snumber
            nil 
        end

        def /(obj : Snumber)
            return self if obj == 1
            return self * PinfinityC if obj == 0
            return Division.new(self,obj)
        end

        def /(obj : Negative)
            return -(self / obj.value)
        end

        def /(obj : Infinity)
            return SZERO
        end

        def /(obj : Product)
            return self / obj.left / obj.right 
        end

        def /(obj : Division)
            return self / obj.left * obj.right
        end

        def /(obj)
            return Division.new(self,obj)
        end

        def opt_div(obj : Snumber)
            return self if obj == 1
            return self.opt_prod PinfinityC if obj == 0
            nil 
        end

        def **(obj : Snumber)
            return SONE if obj == 0
            return self if obj == 1
            return Power.new(self,obj)
        end

        def **(obj : Negative)
            return SONE / self ** obj.value
        end

        def **(obj : PInfinity)
            return obj if value.is_a? Snumber
            return Power.new(self,obj)
        end

        def **(obj : NInfinity)
            return SONE / self ** PinfinityC
        end

        def **(obj)
            return Power.new(self,obj)
        end

        def opt_power(obj : Snumber)
            return self if obj == 1
            return SONE if obj == 0
            nil 
        end

        def opt_power(obj : Infinity)
            return self ** obj if value.is_a? Snumber
            nil 
        end

        def depend?(obj : Symbolic)
            return value.depend? obj 
        end
    
        def ==(obj : Function)
            return false unless self.class == obj.class 
            return value == obj.value 
        end

        def ==(obj : Symbolic)
            false 
        end

    end

    macro define_function(name)

        {% string_n = "#{name}".downcase %}

        class {{name}} < Function
            def self.create(obj)
                return Sin.new(obj)
            end

            def +(obj : {{name}})
                return self * STWO if self == obj 
                return Sum.new(self,obj)
            end

            def opt_sum(obj : {{name}})
                return self * STWO if self == obj
                nil 
            end

            def -(obj : {{name}})
                return SZERO if self == obj 
                return Diff.new(self,obj)
            end

            def opt_sub(obj : {{name}})
                return SZERO if self == obj
                nil 
            end

            def *(obj : {{name}})
                return self ** STWO if self == obj 
                return Product.new(self,obj)
            end

            def opt_prod(obj : {{name}})
                return self ** STWO if self == obj 
                nil 
            end

            def /(obj : {{name}})
                return SONE if self == obj 
                return Division.new(self,obj)
            end

            def opt_div(obj : {{name}})
                return SONE if self == obj
                nil 
            end

            def diff(obj)
                {{yield}}
            end

            def eval(dict : LcHash)
                return Math.{{string_n.id}}(value.eval(dict))
            end

            def to_s(io)
                io << "#{{{string_n}}}("
                value.to_s(io)
                io << ')'
            end

            def to_s
                return String.new do |io|
                    to_s(io)
                end
            end
        end
 
    end

end