
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

    class Exp < Function
        
        def self.create(obj : Snumber)
            return SONE if obj == 0
            return EC if obj == 1
            return Exp.new(obj)
        end

        def self.create(obj : Log)
            return obj.value 
        end

        def self.create(obj)
            return Exp.new(obj)
        end

        def +(obj : Exp)
            return self * STWO if self == obj 
            return Sum.new(self,obj)
        end

        def opt_sum(obj : Exp)
            return self * STWO if self == obj 
            nil 
        end

        def -(obj : Exp)
            return SZERO if self == obj 
            return Sub.new(self,obj)
        end

        def opt_sub(obj : Exp)
            return SZERO if self == obj 
            nil 
        end

        def *(obj : Exp)
            return Exp.create(value + obj.value)
        end

        def opt_prod(obj : Exp)
            return self * obj 
        end

        def /(obj : Exp)
            return Exp.create(value - obj.value)
        end

        def opt_div(obj : Exp)
            return self * obj 
        end

        def **(obj : Symbolic)
            return Exp.create(value * obj)
        end

        def diff(obj : Symbolic)
            return SZERO unless self.depend? obj
            return value.diff(obj) * self 
        end

        def eval(dict : LcHash)
            return Math.exp(value.eval(dict))
        end

        def to_s(io)
            io << "e^"
            append(io,value)
        end

        def to_s
            return String.build do |io|
                to_s(io)
            end
        end

        protected def append(io,elem)
            unless !(elem.is_a? BinaryOp) || elem.is_a? Power
                io << '('
                elem.to_s(io)
                io << ')'
            else
                elem.to_s(io)
            end
        end


    end

end