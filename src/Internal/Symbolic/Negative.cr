
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

    class Negative < SBaseC

        getter value : Symbolic


        def self.create(obj : Snumber)
            return obj if obj == 0
            return -obj
        end

        def self.create(obj : PInfinity)
            return NinfinityC
        end

        def self.create(obj : NInfinity)
            return PinfinityC
        end

        def self.create(obj : Negative)
            return obj.value
        end

        def self.create(obj : Symbolic)
            return Negative.new(obj)
        end

        def initialize(@value : Symbolic)
        end

        def +(obj : Negative)
            tmp = value + obj.value
            return Negative.create(tmp)
        end

        def +(obj : Symbolic)
            return obj - value
        end

        def opt_sum(obj : Negative)
            tmp = value.opt_sum(obj.value)
            if tmp 
                return Negative.create(tmp)
            end
            nil
        end

        def opt_sum(obj)
            return obj.opt_sub(value)
        end

        def -(obj : Negative)
            return self + obj.value 
        end

        def -(obj)
            tmp = value + obj 
            return Negative.create(tmp)
        end

        def - 
            return value
        end

        def opt_sub(obj : Negative)
            tmp = self.opt_sum(obj.value)
            return tmp if tmp
            nil 
        end

        def opt_sub(obj)
            tmp = value.opt_sum(obj)
            return Negative.create(tmp) if tmp 
            nil 
        end

        def *(obj : Negative)
            return value * obj.value
        end

        def *(obj)
            return -(obj * value)
        end

        def opt_prod(obj : Negative)
            return value.opt_prod(obj.value)
        end

        def opt_prod(obj)
            tmp = value.opt_prod(obj).as(Symbolic?)
            return Negative.create(tmp) if tmp 
            nil 
        end

        def /(obj : Negative)
            return value / obj.value
        end

        def /(obj : Symbolic)
            return Negative.create((value / obj).as(Symbolic))
        end

        def opt_div(obj : Negative)
            return value.opt_div(obj.value)
        end

        def opt_div(obj : Symbolic)
            tmp = value.opt_div(obj).as(Symbolic?)
            return Negative.create(tmp) if tmp 
            nil 
        end

        def **(obj : Negative)
            tmp = (value ** obj.value).as(Symbolic)
            return -(SONE / tmp)
        end

        def **(obj)
            return -(value ** obj)
        end

        def opt_power(obj)
            tmp = value.opt_power(obj)
            return -tmp if tmp 
            nil 
        end

        def ==(obj : Negative)
            return value == obj.value
        end

        def ==(obj)
            false 
        end

        def diff(obj)
            return SZERO unless self.depend?(obj)
            return -obj.diff(obj)
        end

        def eval(dict : LcHash)
            return -value.eval(dict)
        end

        def to_s(io)
            io << 'i'
            if v.is_a? (Sum | Sub | Product | Division)
                io << '('
                value.to_s(io)
                io << ')'
            else
                value.to_s(io)
            end
        end

        def to_s 
            return String.build do |io|
                io << '-'
                v = value
                if v.is_a? (Sum | Sub | Product | Division)
                    io << '(' << v << ')'
                else
                    io << v
                end
            end
        end

        def depend?(obj)
            return value.depend? obj 
        end

        
    end
    
end