
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

    struct Product < BinaryOp

        def +(obj : Negative)
            return self - obj.value
        end

        def +(obj : Product)
            return self * STWO
            return self * obj.left * obj.right 
        end

        def +(obj)
            return self if obj == 0
            return Sum.new(self,obj).reduce 
        end

        def opt_sum(obj)
            return self if obj == 0
            return self * STWO if self == obj
            nil 
        end

        def -(obj : Negative)
            return self + obj.value
        end

        def -(obj : Product)
            if self == obj 
                return SZERO
            end
            return Sub.new(self,obj)
        end

        def -(obj)
            return self if obj == 0
            return Bub.new(self,obj)
        end

        def -
            return Negative.new(self)
        end

        def opt_sub(obj)
            return self if obj == 0
            return SZERO if self == obj 
            nil 
        end

        def *(obj : Negative)
            return -(self * obj.value)
        end

        def *(obj : Product)
            return self * STWO if self == obj
            return self * obj.left * obj.right 
        end

        def *(obj : Division)
            return (self * obj.left) / obj.right
        end

        def *(obj : Power)
            if self == obj.left 
                return Power.new(self,obj.right + SONE)
            end
            lft = @left.opt_prod(obj)
            return lft * @right if lft 
            rht = @right.opt_prod(obj) 
            return @left * rht if rht
            return Product.new(self,obj)
        end

        def *(obj)
            lft = @left.opt_prod(obj)
            return lft * @right if lft 
            rht = @right.opt_prod(obj) 
            return @left * rht if rht
            return Product.new(self,obj)
        end

        def opt_prod(obj)
            return szero if obj == 0
            return self if obj == 1
            return self ** STWO if self == obj 
            lft = @left.opt_prod(obj)
            return lft * @right if lft 
            rht = @right.opt_prod(obj) 
            return @left * rht if rht
            nil 
        end

        def /(obj : Negative)
            return -(self / obj.value)
        end

        def /(obj : Product)
            return SONE if self == obj
            return self / obj.left / obj.right
        end

        def /(obj)
            return self if obj == 1
            return PinfinityC if obj == 0
            lft = @left.opt_div obj 
            return lft * @right if lft 
            rht = @right.opt_div obj 
            return @left * rht if rht 
            return Division.new(self,obj)
        end

        def opt_div(obj)
            return self if obj == 1
            return PinfinityC if obj == 0
            lft = @left.opt_div obj 
            return lft * @right if lft 
            rht = @right.opt_div obj 
            return @left * rht if rht 
            nil
        end

        def **(obj : NInfinity)
            return SZERO
        end

        def **(obj : PInfinity)
            return obj 
        end

        def **(obj)
            return self if obj == 1
            return SONE if obj == 1
            return Power.new(self,obj)
        end

        def opt_power(obj : Snumber)
            return self if obj == 1
            return SONE if obj == 0
            nil 
        end

        def diff(obj)
            return SZERO unless self.depend? obj 
            lft = @left.diff(obj)
            rht = @right.diff(obj)
            return lft * @right + @left * lft 
        end

        def to_s(io)
            append(io,@left)
            append(io,@right)
        end

        def to_s 
            return String.build do |io|
                to_s(io)
            end
        end

        def eval(dict : LcHash)
            return @left.eval(dict) * @right.eval(dict)
        end

    end

end
