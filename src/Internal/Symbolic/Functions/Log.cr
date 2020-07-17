
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

    class Log < Function

        def self.create(obj : E)
            return SONE 
        end

        def self.create(obj : Snumber)
            return SZERO if obj == 1
            return NinfinityC if obj == 0
            return Log.new(obj)
        end

        def self.create(obj : Negative)
            if obj.value.is_a? Snumber 
                return NanC 
            end
            return Log.new(obj)
        end

        def self.create(obj : Product)
            tmp = obj.opt_div(EC)
            return Log.create(tmp) if tmp 
            return Log.new(obj)
        end

        def self.create(obj : Division)
            tmp = obj.opt_div(EC)
            return Log.create(tmp) if tmp 
            tmp = obj.opt_prod(EC)
            return Log.create(tmp) if tmp 
            return Log.new(obj)
        end

        def self.create(obj : Power)
            return obj.right * Log.create(obj.left)
        end

        def self.create(obj)
            return Log.new(obj)
        end

        def +(obj : Log)
            return self * STWO if self == obj 
            return Log.create(value * obj.value)
        end

        def opt_sum(obj : Log)
            return self + obj if self == obj 
            nil 
        end

        def -(obj : Log)
            return SZERO if self == obj 
            return Log.create(value / obj.value)
        end

        def opt_sub(obj : Log)
            return self - obj if self == obj 
            nil 
        end

        def *(obj : Log)
            return self ** STWO if self == obj 
            return Product.new(self,obj)
        end

        def opt_prod(obj : Log)
            return self ** STWO if self == obj 
            nil 
        end

        def /(obj : Log)
            return SONE if self == obj 
            return Division.new(self,obj)
        end

        def opt_div(obj : Log)
            return SONE if self == obj 
            nil 
        end

        def diff(obj : Symbolic)
            tmp = value 
            return SONE / tmp * tmp.diff(obj)
        end
        
        def eval(dict : LcHash)
            val = value.eval(dict)
            if val > 0
                return Math.log(value.eval(dict))
            elsif val == 0
                return -Float64::INFINITY 
            end
            return Float64::NAN 
        end

        def to_s(io)
            io << "log("
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