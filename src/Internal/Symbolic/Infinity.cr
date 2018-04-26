
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

    abstract struct Infinity SBaseS

        def +(obj : Variable)
            return Sum.new(self,obj)
        end

        def +(obj : Negative)
            return self - obj.value 
        end

        def +(obj : Infinity)
            return self 
        end

        def +(obj : NInfinity)
            return NanC
        end

        def +(obj : Function)
            return Sum.new(self,obj)
        end

        def +(obj : BinaryOp)
            return obj + self 
        end

        def +(obj)
            return self 
        end

        def opt_sum(obj : PInfinity)
            return self
        end

        def opt_sum(obj : Snumber)
            return self 
        end

        def -(obj : Snumber)
            return self 
        end

        def -(obj : Variable)
            return Sub.new(self,obj)
        end

        def -(obj : Negative)
            return self + obj.value
        end

        def -(obj : NInfinity)
            return self 
        end

        def -(obj : Infinity)
            return NanC
        end

        def -(obj : Constant)
            return self 
        end

        def -(obj : Function)
            return Sub.new(self,obj)
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
            return NinfinityC
        end

        def opt_sub(obj : Snumber)
            return self 
        end

        def opt_sub(obj : NInfinity)
            return self 
        end

        def *(obj : Snumber)
            return NanC
        end

        def *(obj : Variable)
            return Product.new(self,obj)
        end

        def *(obj : Negative)
            return -(self * obj.value)
        end

        def *(obj : Infinity)
            return obj 
        end

        def *(obj : Function)
            return Product.new(self,obj)
        end

        def *(obj : BinaryOp)
            return obj * self
        end

        def *(obj)
            return self
        end

        def opt_prod(obj : Infinity)
            return obj 
        end

        def /(obj : Snumber)
            return self 
        end

        def /(obj : Infinity)
            return NanC
        end

        def /(obj : Constant)
            return self 
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

        def **(obj : Snumber)
            if obj == 0
                return SONE
            end
            return self 
        end

        def **(obj : PInfinity)
            return self 
        end

        def **(obj : NInfinity)
            return SZERO
        end

        def **(obj : Constant)
            return self
        end

        def **(obj)
            return Power.new(self,obj)
        end

        def eval(dict)
            return Float64::INFINITY 
        end

        def diff(obj)
            return SZERO
        end

        def to_s(io)
            io << '∞'
        end

        def to_s 
            return "∞"
        end

    end

    struct PInfinity < Infinity
    end

    struct NInfinity < Infinity

        def +(obj : PInfinity)
            return  NanC
        end

        def +(obj : NInfinity)
            return self 
        end

        def opt_sum(obj : NInfinity)
            return self 
        end

        def -(obj : NInfinity)
            return NanC
        end

        def -(obj : Infinity)
            return self 
        end

        def - 
            return InfinityC
        end

        def opt_sub(obj : NInfinity)
            nil 
        end

        def opt_sub(obj : PInfinity)
            return self 
        end

        def *(obj : Ninfinity)
            return PinfinityC
        end

        def *(obj : Infinity)
            return self 
        end

        def eval(dict)
            return -Float64::INFINITY 
        end

        def to_s(io)
            io << "-∞"
        end

        def to_s 
            return "-∞"
        end

    end

    PinfinityC  = PInfinity.new.as(Symbolic) 
    NinfinityC  = NInfinity.new.as(Symbolic)

end
