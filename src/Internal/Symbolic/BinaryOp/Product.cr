
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

        def +(obj : Variable | Snumber | Constant | Function)
            if @left == obj 
                tmp = Sum.new(@right,num2sym(1))
                return Product.new(@left,tmp).reduce
            elsif @right == obj 
                tmp = Sum.new(@left,num2sym(1))
                return Product.new(@right,tmp).reduce
            end
            return nil unless self.top
            return Sum.new(self,obj)
        end

        def +(obj : Product)
            if self == obj 
                return Product.new(num2sym(2),self).reduce
            end
            return nil unless self.top 
            return self * obj.left * obj.right 
        end

        def +(obj : Negative)
            return self - obj.value 
        end

        def +(obj)
            return nil unless self.top 
            return Sum.new(self,obj).reduce 
        end

        def -(obj : Variable | Snumber | Constant | Function)
            if @left == obj 
                tmp = Sub.new(@right,num2sym(1))
                return Product.new(@left,tmp).reduce
            elsif @right == obj 
                tmp = Sub.new(@left,num2sym(1))
                return Product.new(@right,tmp).reduce
            end
            return nil unless self.top
            return Sub.new(self,obj)
        end

        def -(obj : Product)
            if self == obj 
                return num2sym(0)
            end
            return nil unless self.top 
            return Sub.new(self,obj).reduce
        end

        def -(obj : Negative)
            return self + obj.value 
        end

        def -(obj)
            return nil unless self.top 
            return Bub.new(self,obj).reduce
        end

        def -
            return Negative.new(self)
        end

        def *(obj : Variable | Snumber | Constant | Function)
            if @left == obj 
                tmp = Power.new(@left,num2sym(2))
                return Product.new(tmp,@right).reduce
            elsif @right == obj 
                tmp = Power.new(@right,num2sym(2))
                return Product.new(tmp,@left).reduce
            end
            return nil unless self.top 
            return Product.new(ob,self).reduce 
        end

        def *(obj : Product)
            if self == obj 
                return Product.new(num2sym(2),self)
            end
            return nil unless self.top 
            return self * obj.left * obj.right 
        end

        def *(obj : Division)
            if self =~ obj.right
                return self / obj.right * obj.left 
            end
            return nil unless self.top
            return self * obj.left / obj.right
        end

        def *(obj : Power)
            if self == obj.left 
                return Power.new(self,obj.right + num2sym(1)).reduce 
            end
            return nil unless self.top
            return Product.new(self,obj)
        end

        def *(obj : Negative)
            if self == obj.value 
                return Negative.new(self * obj.value,self.top)
            end
            return nil unless self.top 
            return Negative.new(self * obj.value)
        end

        def *(obj)
            return nil unless self.top
            return Product.new(self,obj).reduce
        end

        def /(obj : Variable | Snumber | Constant | Function)
            if @left == obj 
                tmp = @right
                tmp.top = self.top 
                return tmp 
            elsif @right == obj
                tmp = @left
                tmp.top = self.top 
                return tmp 
            end
            return nil unless self.top
            return Division.new(self,obj)
        end

        def /(obj : Product)
            if self =~ obj 
                if @left == obj.left
                    return Division.new(@right,obj.right,self.top).reduce
                elsif @right == obj.right
                    return Division.new(@left,obj.left,self.top).reduce
                elsif @left == obj.right
                    return Division.new(@right,obj.left,self.top).reduce
                elsif @right == obj.left 
                    return Division.new(@left,obj.right,self.top).reduce
                end
            end
            return nil unless self.top 
            return Division.new(self,obj)
        end

        def /(obj : Negative)
            if self == obj.value 
                tmp     =  - num2sym(1)
                tmp.top = self.top 
                return tmp
            end
            return nil unless self.top 
            return Division.new(self,obj.value).reduce
        end

        def /(obj)
            return num2sym(1) if self == obj 
            return nil unless self.top 
            return Division.new(self,obj).reduce
        end

        def **(obj)
            return nil unless self.top 
            return Power.new(self,obj).reduce
        end

        def reduce
            super 
            if @left == 0 && @right.is_a? Infinity
                Exec.lc_raise(LcMathError,"(0*∞)")
                return @left 
            elsif @right == 0 && @left.is_a? Infinity
                Exec.lc_raise(LcMathError,"(0*∞)")
                return @left
            elsif @left == 0 || @right == 0
                return num2sym(0)
            elsif @left == NinfinityC || @right == NinfinityC
                return NinfinityC 
            elsif @left == InfinityC || @right == InfinityC
                return InfinityC
            elsif @left == @right
                return Power.new(@left,num2sym(2),self.top).reduce 
            elsif @left.is_a? Negative
                tmp = neg2val(@left)
                tmp.top = true
                return Negative.new(tmp * @right,self.top).reduce
            elsif @right.is_a? Negative
                tmp = neg2val(@right)
                tmp.top = true
                return Negative.new(tmp * @left,self.top).reduce
            elsif @left == 1
                return @right
            elsif @right == 1
                return @left
            end 
            return self
        end

    end

end
