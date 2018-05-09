
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
require "colorize"
module LinCAS::Internal 

    class Division < BinaryOp 

        nan_ops
        
        def +(obj : Negative) : Symbolic
            return self - obj.value 
        end

        def +(obj : Division) : Symbolic
            return self * STWO if self == obj 
            return (@left * obj.right + @right * obj.left) / (@right * obj.right)
        end 

        def +(obj : Symbolic) : Symbolic
            return self if obj == 0
            return Sum.new(self,obj)
        end

        def opt_sum(obj : Snumber) : Symbolic?
            return self if obj == 0
            nil
        end

        def opt_sum(obj : Division) : Symbolic?
            return self * STWO if self == obj 
            nil 
        end

        def -(obj : Negative) : Symbolic
            return self + obj.value 
        end

        def -(obj : Division) : Symbolic
            return SZERO if self == obj 
            return ((@left * obj.right).as(Symbolic) - (@right * obj.left).as(Symbolic)).as(Symbolic) / 
            (@right * obj.right).as(Symbolic)
        end

        def -(obj : Symbolic) : Symbolic
            return self if obj == 0
            return Sub.new(self,obj)
        end

        def - : Symbolic
            return Negative.new(self)
        end

        def opt_sub(obj : Snumber) : Symbolic?
            return self if obj == 0
            nil 
        end

        def opt_sub(obj : Division) : Symbolic?
            return SZERO if self == obj 
            nil 
        end

        def *(obj : Negative) : Symbolic
            return -(self * obj.value)
        end

        def *(obj : Division) : Symbolic
            return ((@left * obj.left).as(Symbolic) / @right).as(Symbolic) / obj.right
        end

        def *(obj : Product) : Symbolic
            return self ** STWO if self == obj 
            return (self * obj.left) * obj.right 
        end

        def *(obj) : Symbolic
            return SZERO if obj == 0
            return self if obj == 1
            return obj / @right if @left == 1
            return Product.new(self,obj)
        end

        def opt_prod(obj : Snumber) : Symbolic?
            return self if obj == 1
            return SZERO if obj == 0
            nil
        end

        def opt_prod(obj : Division) : Symbolic?
            return self ** STWO if self == obj 
            nil 
        end

        def opt_prod(obj : Infinity) : Symbolic?
            return obj 
        end

        def opt_prod(obj) : Symbolic?
            tmp = @left.opt_prod(obj).as(Symbolic?) 
            return tmp / @right if tmp 
            tmp = obj.opt_div(obj).as(Symbolic?)
            return @left / tmp if tmp 
            nil 
        end

        def /(obj : Snumber) : Symbolic
            return self if obj == 1
            return PinfinityC if obj == 0
            return @left * obj / @right 
        end

        def /(obj : Negative) : Symbolic
            return -(self / obj.value)
        end

        def /(obj : Infinity) : Symbolic
            return SZERO
        end

        def /(obj : Product) : Symbolic
            return (@left / obj).as(Symbolic) / @right
        end

        def /(obj : Division) : Symbolic
            return self * obj.right / obj.left 
        end

        def /(obj) : Symbolic
            lft = @left.opt_div(obj)
            return lft / @right if lft 
            if !(tmp = @right.opt_prod(obj))
                return Division.new(@left,@right * obj)
            else
                return @left / (@right * obj)
            end
        end

        def opt_div(obj : Snumber) : Symbolic?
            return self.as(Symbolic) if obj == 1
            return PinfinityC if obj == 0 
            nil 
        end

        def opt_div(obj : Infinity) : Symbolic
            return SZERO
        end
        
        def opt_div(obj : Division) : Symbolic?
            return SONE if obj == self 
            nil 
        end

        def opt_div(obj : Symbolic) : Symbolic?
            tmp = @left.opt_div(obj)
            return tmp / @right if tmp 
            nil 
        end

        def **(obj : Snumber) : Symbolic
            return self if obj == 1
            return SONE if obj == 0
            return Power.new(self,obj)
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

        def opt_power(obj : Snumber) : Symbolic?
            return SONE if obj == 0
            return self if obj == 1
            nil 
        end

        def opt_power(obj : PInfinity) : Symbolic?
            return obj 
        end

        def opt_power(obj : NInfinity) : Symbolic?
            return SZERO
        end

        def ==(obj : Division)
            return @left == obj.left && @right == obj.right
        end

        def ==(obj)
            false 
        end

        def diff(obj)
            lft = @left.diff(obj)
            rht = @right.diff(obj)
            return (lft * @right - @left *rht) / @right ** STWO
        end

        def eval(dict : LcHash)
            return @left.eval(dict) / @right.eval(dict).to_f
        end

        def to_s(io)
            append(io,@left)
            io << " / "
            append(io,@right)
        end

        def to_s 
            return String.build do |io|
                to_s(io)
            end
        end

     
    end
    
end