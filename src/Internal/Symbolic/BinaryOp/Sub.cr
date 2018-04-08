
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

    struct Sub < BinaryOp

        def +(obj : Variable | Snumber | Constant | Function)
            lft = @left + obj 
            return Sub.new(lft,@right).reduce if lft 
            rht = @right + obj
            return Sub.new(@left,rht).reduce if rht
            return nil unless self.top 
            return Sub.new(self,obj).reduce 
        end

        def +(obj : Negative)
            return self - obj.value 
        end

        def +(obj : Sum)
            return self + obj.left + obj.right
        end

        def +(obj : Sub)
            return self + obj.left - obj.right 
        end

        def +(obj)
            return nil unless self.top 
            return Sum.new(self,obj).reduce 
        end

        def -(obj : Variable | Snumber | Constant | Function)
            lft = @left - obj 
            return Sub.new(lft,@right).reduce if lft 
            rht = @right - obj 
            return Sub.new(@left,rht).reduce if rht 
            return nil unless self.top 
            return Sub.new(self,obj).reduce 
        end

        def -(obj : Negative)
            return self + obj.value
        end

        def -(obj : Sum)
            return self - obj.left - obj.right 
        end

        def -(obj : Sub)
            return self - obj.left + obj.right 
        end

        def -(obj)
            return nil unless self.top 
            return Sub.new(self,obj)
        end

        def -
            return @right - @left
        end

        def *(obj)
            return nil unless self.top 
            return Product.new(self,obj).reduce 
        end

        def /(obj)
            return nil unless self.top 
            return Division.new(self,obj)
        end

        def **(obj)
            return nil unless self.top 
            return Power.new(self,obj)
        end

        def reduce
            super
            if @left == 0
                return @right 
            elsif @right == 0 
                return @left 
            elsif @left == InfinityC && @right == NInfinityC
                return InfinityC 
            elsif @left == NinfinityC && @right == InfinityC
                return NinfinityC
            elsif @left.is_a? Infinity && @right.is_a? Infinity 
                Exec.lc_raise(LcMathError,"(∞-∞)")
                return @left 
            elsif @left == @right
                return num2sym(0)
            elsif @left.is_a? Snumber && @right.is_a? Snumber
                return num2sym(sym2num(@left) - sym2num(@right))
            elsif @right.is_a? Negative
                return @left - neg2val(@right)
            elsif @left.is_a? Negative
                return Negative.new(neg2val(@left + @right)).reduce
            end
            return self
        end

        def diff(obj)
            return num2sym(0) unless self.depends? obj 
            lft = @left.diff(obj)
            rht = @right.diff(obj)
            return lft - rht 
        end

        def eval(dict)
            lft = @left.eval(dict)
            rht = @right.eval(dict)
            return lft - rht 
        end
    end
    
end
