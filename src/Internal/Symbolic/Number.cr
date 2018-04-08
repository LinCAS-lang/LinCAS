
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

    struct Snumber < BaseS

        private def mcd(a,b)
            a,b = b,a unless b < a 
            while b != 0 
                a,b = b, a % b 
            end 
            return a 
        end

        getter value

        def initialize(@value : Num)
            super()
        end

        @[AlwaysInline]
        def +(obj : Snumber)
            return num2sym(@value + obj.value)
        end

        @[AlwaysInline]
        def +(obj : BinaryOp)
            return obj + self
        end

        def +(obj)
            return nil unless self.top
            return Sum.new(self,obj).reduce
        end

        @[AlwaysInline]
        def -(obj : Snumber)
            return num2sym(@value - obj.value)
        end

        def -(obj)
            return nil unless self.top
            return Sub.new(self,obj).reduce
        end

        @[AlwaysInline]
        def -
            return Negative.new(self)
        end

        @[AlwaysInline]
        def *(obj : Snumber)
            return num2sym(@value * obj.value)
        end

        @[AlwaysInline]
        def *(obj : BinaryOp)
            return obj * self 
        end

        def *(obj)
            return nil unless self.top
            return Product.new(self,obj).reduce
        end

        def /(obj : Snumber)
            return InfinityC if obj == 0
            return self if obj == 1
            _mcd = mcd(@value,obj.value)
            return Division.new(@value,obj.value) if _mcd == 1
            v1 = @value / _mcd 
            v2 = obj.value / _mcd 
            return sym2num(v1) if v2 == 1 
            return Division.new(v1,v2)
        end 

        def /(obj)
            return nil unless self.top 
            return Division.new(self,obj).reduce
        end

        @[AlwaysInline]
        def **(obj : Snumber)
            return num2sym(@value ** obj.value)
        end

        def **(obj)
            return nil unless self.top 
            return Power.new(self,obj).reduce
        end

        @[AlwaysInline]
        def reduce 
            return self
        end

        @[AlwaysInline]
        def eval(dict)
            return @value 
        end

        @[AlwaysInline]
        def diff(obj)
            return num2sym(0)
        end


        @[AlwaysInline]
        def to_s(io)
            io << @value 
        end

        @[AlwaysInline]
        def to_s 
            return @value.to_s 
        end

        @[AlwaysInline]
        def ==(obj : Num)
            return @value == obj 
        end

        @[AlwaysInline]
        def ==(obj : Snumber)
            return @value == obj.value 
        end

        @[AlwaysInline]
        def ==(obj)
            return false 
        end

        @[AlwaysInline]
        def depend?(obj)
            return false 
        end

    end
    
end
