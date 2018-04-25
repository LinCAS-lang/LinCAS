
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

module LinCAS 

    struct Division < BinaryOp 
        
        def +(obj : Negative)
            return self - obj.value 
        end

        def +(obj : Division)
            return self * STWO if self == obj 
            return (@left * obj.right + @right * obj.left) / (@right * obj.right)
        end 

        def +(obj)
            return self if obj == 0
            return Sum.new(self,obj)
        end

        def opt_sum(obj : Snumber)
            return self if obj == 0
            nil
        end

        def opt_sum(obj : Division)
            return self * STWO if self == obj 
            nil 
        end

        def -(obj : Negative)
            return self + obj.value 
        end

        def -(obj : Division)
            return SZERO if self == obj 
            return (@left * obj.right - @right * obj.left) / (@right * obj.right)
        end

        def -(obj)
            return self if obj == 0
            return Sub.new(self,obj)
        end

        def -
            return Negative.new(self)
        end

        def opt_sub(obj : Snumber)
            return self if obj == 0
            nil 
        end

        def opt_sub(obj : Division)
            return SZERO if self == obj 
            nil 
        end

        def *(obj : Negative)
            return -(self * obj.value)
        end

        def *(obj : Division)
            return (@left * obj.left) / @right / obj.right
        end

        def *(obj : Product)
            return self ** STWO if self == obj 
            return self * obj.left * obj.right 
        end

        def *(obj)
            return SZERO if obj == 0
            return SONE if obj == 1
            return self * obj.left / obj.right 
        end

        def opt_prod(obj : Snumber)
            return self if obj == 1
            return SZERO if obj == 0
            nil
        end

        def opt_prod(obj : Division)
            return self ** STWO if self == obj 
            nil 
        end

        def opt_prod(obj : Infinity)
            return obj 
        end

        def opt_prod(obj)
            tmp = @left.opt_prod obj 
            return tmp / @right if tmp 
            tmp = obj.opt_div obj
            return @left / tmp if tmp 
            nil 
        end

        def /(obj : Snumber)
            return self if obj == 1
            return PinfinityC if obj == 0
            return @left * obj / @right 
        end

        def /(obj : Negative)
            return -(self / obj.right)
        end

        def /(obj : Infinity)
            return SZERO
        end

        def /(obj : Product)
            return @left / obj / @right
        end

        def /(obj : Division)
            return self * obj.right / obj.left 
        end

        def /(obj)
            lft = @left.opt_div obj 
            return lft / @right if lft 
            return @left / (@right * obj)
        end

        def opt_div(obj : Snumber)
            return self if obj == 1
            return PinfinityC if obj == 0 
            nil 
        end

        def opt_div(obj : Infinity)
            return SZERO
        end
        
        def opt_div(obj : Division)
            return SONE if obj == self 
            nil 
        end

        def opt_div(obj)
            tmp = @left.opt_div obj 
            return tmp / @right if tmp 
            nil 
        end

        def **(obj : Snumber)
            return self if obj == 1
            return SONE if obj == 0
            return Power.new(self,obj)
        end

        def **(obj : PInfinity)
            return obj 
        end

        def **(obj : NInfinity)
            return SZERO 
        end

        def **(obj)
            return Power.new(self,obj)
        end

        def opt_power(obj : Snumber)
            return SONE if obj == 0
            return self if obj == 1
            nil 
        end

        def opt_power(obj : PInfinity)
            return obj 
        end

        def opt_power(obj : NInfinity)
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
            io << '/'
            append(io,@right)
        end

        def to_s 
            return String.build do |io|
                to_s(io)
            end
        end

        private def append(io,elem)
            if elem.is_a? BinaryOp
                io << '('
                elem.to_s(io)
                io << ')'
            end 
        end


     
    end
    
end