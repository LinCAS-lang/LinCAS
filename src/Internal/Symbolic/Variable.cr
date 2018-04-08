
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

    struct Variable < BaseS

        getter name

        def initialize(@name : String)
            super()
        end

        def +(obj : Variable)
            return Sum.new(num2sym(2),self) if self == obj 
            return nil unless self.top 
            return Sum.new(self,obj)
        end

        @[AlwaysInline]
        def +(obj : BinaryOp)
            return obj + self
        end

        @[AlwaysInline]
        def +(obj)
            return nil unless self.top
            return Sum.new(self,obj).reduce
        end

        def -(obj : Variable)
            return num2sym(0) if self == obj
            return nil unless self.top
            return Sub.new(self,obj)
        end

        @[AlwaysInline]
        def -(obj)
            return nil unless self.top
            return Sub.new(self,obj).reduce
        end

        @[AlwaysInline]
        def -
            return Negative.new(self)
        end

        def *(obj : Variable)
            return Power.new(self,num2sym(2)) if self == obj 
            return nil unless self.top
            return Product.new(self,obj)
        end

        @[AlwaysInline]
        def *(obj : BinaryOp)
            return obj * self 
        end

        @[AlwaysInline]
        def *(obj : Snumber)
            return nil unless self.top
            return Product.new(obj, self)
        end

        @[AlwaysInline]
        def *(obj)
            return nil unless self.top
            return Product.new(self,obj).reduce
        end

        def /(obj : Variable)
            return num2sym(1) if self == obj 
            return nil unless self.top
            return Division.new(self,obj)
        end 

        @[AlwaysInline]
        def /(obj : BinaryOp)
            return nil unless self.top
            return Division.new(self,obj).reduce
        end

        @[AlwaysInline]
        def /(obj)
            return nil unless self.top
            return Division.new(self,obj).reduce
        end

        @[AlwaysInline]
        def **(obj)
            return nil unless self.top
            return Power.new(self,obj)
        end

        @[AlwaysInline]
        def reduce
            return self 
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

        def ==(obj)
            return false unless obj.is_a? Variable
            return @name == name 
        end

        @[AlwaysInline]
        def depend?(obj)
            return self == obj 
        end

    end

end
