
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

    class Power < BinaryOp
        
        def +(obj : Negative)
            return self - obj 
        end

        def +(obj : Power)
            return self * STWO if self == obj 
            return Sum.new(self,obj)
        end

        def +(obj)
            return self if obj == 1
            return Sum.new(self,obj)
        end

        def opt_sum(obj : Power)
            return self * STWO if self == obj 
            nil 
        end

        def opt_sum(obj : Snumber)
            return self if obj == 0
            nil 
        end

        def -(obj : Negative)
            return self + obj 
        end

        def -(obj : Power)
            return SZERO if self == obj 
            return Sub.new(self,obj)
        end

        def -(obj : Symbolic?)
            return self if obj == 0
            return Sub.new(self,obj)
        end

        def -
            return Negative.create(self)
        end

        def opt_sub(obj : Negative)
            return SZERO if self == obj 
            nil 
        end

        def opt_sub(obj : Snumber)
            return self if obj == 0
            nil 
        end

        def *(obj : Snumber)
            return SZERO if obj == 0
            return self if obj == 1
            return Product.new(obj,self)
        end

        def *(obj : Negative)
            return -(self * obj.value)
        end

        def *(obj : Division)
            return self / obj.right * obj.left
        end

        def *(obj : Power)
            if @left == obj.left 
                return @left ** (@right + obj.right)
            end
            return Product.new(self,obj)
        end

        def *(obj : Symbolic)
            return @left ** (@right + SONE) if @left == obj
            return Product.new(self,obj)
        end

        def opt_prod(obj : Power)
            return self * STWO if self == obj 
            nil 
        end

        def opt_prod(obj : Snumber)
            return SZERO if obj == 0
            return self if obj == 1
            nil 
        end

        def /(obj : Snumber)
            return self * PinfinityC if obj == 0
            return self if obj == 1
            return Division.new(self,obj)
        end

        def /(obj : Negative)
            return -(self / obj.value)
        end

        def /(obj : Product)
            return self / (obj.left  / obj.right).as(Symbolic) 
        end

        def /(obj : Division)
            return self / (obj.left * obj.right).as(Symbolic) 
        end

        def /(obj : Power)
            return @left ** (@right - obj.right) if @left == obj.left
            return Division.new(self,obj)
        end
        
        def /(obj : Symbolic?)
            return @left ** (@right - SONE) if @left == obj 
            return Division.new(self,obj)
        end

        def opt_div(obj : Snumber)
            return self.opt_prod PinfinityC if obj == 0
            return self if obj == 0
            nil 
        end

        def opt_div(obj : Negative)
            tmp = self.opt_div obj.value
            return -tmp if tmp 
            nil 
        end

        def opt_div(obj : Infinity)
            return SZERO
        end

        def opt_div(obj : Product)
            tmp = self.opt_div(obj.left).as(Symbolic?) 
            return tmp.opt_div(obj.right).as(Symbolic?) if tmp 
            nil 
        end

        def opt_div(obj : Division)
            tmp = self.opt_div(obj.left).as(Symbolic?) 
            return tmp.opt_prod(obj.right).as(Symbolic?) if tmp 
            nil 
        end

        def opt_div(obj : Power)
            return SONE if self == obj 
            return @left ** (@right + obj.right) if @left == obj.right 
            nil 
        end

        def **(obj : Negative)
            return SONE / (self ** obj.value).as(Symbolic)
        end

        def **(obj : PInfinity)
            return @left ** (@right * obj)
        end

        def **(obj : NInfinity)
            return SONE / self ** PinfinityC
        end

        def **(obj : Symbolic)
            return SONE if obj == 0
            return self if obj == 1
            return @left ** (@right * obj).as(Symbolic)
        end

        def opt_power(obj : Symbolic?)
            return SONE if obj == 0
            return self if obj == 1
            nil 
        end

        def diff(obj : Symbolic?)
            return SZERO unless self.depend? obj 
            d_lft = @left.diff(obj)
            d_rht = @right.diff(obj)
            if d_rht == 0
                return @left ** (@right - SONE) * @right * d_lft
            elsif d_lft == 0
                return self * d_rht * Log.create(@left)
            end
            return self * (d_rht * Log.create(@left) + @right * d_lft / @left)
        end

        def eval(dict : LcHash)
            return @left.eval(dict) ** @right.eval(dict)
        end

        def to_s(io)
            append(io,@left)
            io << '^'
            append(io,@right)
        end

        def to_s 
            return String.build do |io|
                to_s(io)
            end
        end

        def ==(obj : Power)
            return @left == obj.left && @right == obj.right
        end

        def ==(obj)
            false 
        end

    end
    
end