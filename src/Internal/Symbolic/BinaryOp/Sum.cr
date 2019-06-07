
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
# limitations under the License.ITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

module LinCAS::Internal
    
    class Sum < BinaryOp

        nan_ops
        
        def +(obj : Negative) : Symbolic
            return self - obj.value.as(Symbolic) 
        end

        def +(obj : Sum) : Symbolic
            return (self + obj.left).as(Symbolic) + obj.right
        end

        def +(obj : Sub) : Symbolic
            return self + obj.left - obj.right
        end

        def +(obj) : Symbolic
            return self if obj == 0
            lft = @left.opt_sum(obj).as(Symbolic?)
            return lft + @right if lft
            rht = @right.opt_sum(obj).as(Symbolic?)
            return @left + rht if rht 
            return Sum.new(self,obj)
        end

        def opt_sum(obj : Symbolic) : Symbolic?
            lft = @left.opt_sum(obj).as(Symbolic?)
            return left + @right if lft
            rht = @right.opt_sum(obj).as(Symbolic?)
            return @left + rht if rht 
            nil 
        end

        def -(obj : Negative) : Symbolic
            return self + obj.value
        end

        def -(obj : Sum) : Symbolic
            return self - obj.left - obj.right 
        end

        def -(obj : Sub) : Symbolic
            return self - obj.left + obj.right 
        end

        def -(obj : Symbolic) : Symbolic
            return self if obj == 0
            lft = @left.opt_sub(obj)
            return left + @right if lft
            rht = @right.opt_sub(obj)
            return @left + rht if rht 
            return Sub.new(self,obj)
        end

        def - : Symbolic
            return Negative.new(self)
        end

        def opt_sub(obj : Symbolic) : Symbolic?
            lft = @left.opt_sub(obj).as(Symbolic?)
            return left + @right if lft
            rht = @right.opt_sub(obj).as(Symbolic?)
            return @left + rht if rht 
            nil 
        end

        def *(obj : Negative) : Symbolic
            return -(self * obj.value)
        end

        def *(obj : Infinity) : Symbolic
            lft = @left.opt_prod(obj)
            return lft + @right if lft 
            rht = @right.opt_prod(obj)
            return @left + rht if rht 
            return Product.new(self,obj)
        end

        def *(obj : Symbolic) : Symbolic
            return self if obj == 1
            return SZERO if obj == 0
            return Power.new(self,STWO) if self == obj
            return Product.new(self,obj)
        end

        def opt_prod(obj : Symbolic) : Symbolic?
            return self if obj == 1
            lft = @left.opt_prod(obj)
            return lft + @right if lft 
            rht = @right.opt_prod(obj)
            return @left + rht if rht 
            return self ** STWO if self == obj
            nil
        end

        def /(obj : Negative) : Symbolic
            return -(self / obj.value)
        end

        def /(obj : Infinity) : Symbolic
            return SZERO
        end

        def /(obj : Sum) : Symbolic
            return SONE if self == obj
            return Division.new(self,obj)
        end

        def /(obj) : Symbolic
            return self if obj == 1
            lft = @left.opt_div(obj).as(Symbolic?)
            rht = @right.opt_div(obj).as(Symbolic?)
            return lft + rht if lft && rht 
            return Product.new(self,PinfinityC) if obj == 0
            return Division.new(self,obj)
        end

        def opt_div(obj : Symbolic) : Symbolic?
            return self if obj == 1
            lft = @left.opt_div(obj).as(Symbolic?)
            rht = @right.opt_div(obj).as(Symbolic?)
            return lft + rht if lft && rht  
            nil
        end

        def **(obj : PInfinity) : Symbolic
            return obj 
        end

        def **(obj : NInfinity) : Symbolic
            return SZERO
        end

        def **(obj : Symbolic) : Symbolic
            return SONE if obj == 0
            return self if obj == 1
            return Power.new(self,obj)
        end

        def diff(obj : Symbolic) : Symbolic
            return SZERO unless self.depend? obj
            lft = @left.diff(obj)
            rht = @right.diff(obj)
            return lft + rht 
        end

        def eval(dict : LcHash)
            lft = @left.eval(dict)
            rht = @right.eval(dict)
            return lft + rht 
        end

        def to_s(io)
            @left.to_s(io)
            io << " + "
            @right.to_s(io)
        end

        def to_s 
            return String.build do |io|
                to_s(io)
            end
        end

        protected def append(io,elem)
            unless ({Sum,Sub,Power}.includes? elem.class) || !(elem.is_a? BinaryOp)
                io << '('
                elem.to_s(io)
                io << ')'
            else
                elem.to_s(io)
            end 
        end

    end

end
