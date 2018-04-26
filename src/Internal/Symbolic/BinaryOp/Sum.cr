
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
    
    struct Sum < BinaryOp
        
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
            return self if obj == 0
            lft = @left.opt_sum(obj)
            return left + @rigth if lft
            rht = @right.opt_sum(obj)
            return @left + rht if rht 
            return Sum.new(self,obj)
        end

        def opt_sum(obj)
            lft = @left.opt_sum(obj)
            return left + @rigth if lft
            rht = @right.opt_sum(obj)
            return @left + rht if rht 
            nil 
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
            return self if obj == 0
            lft = @left.opt_sub(obj)
            return left + @rigth if lft
            rht = @right.opt_sub(obj)
            return @left + rht if rht 
            return Sub.new(self,obj)
        end

        def -
            return Negative.new(self)
        end

        def opt_sub(obj)
            lft = @left.opt_sub(obj)
            return left + @rigth if lft
            rht = @right.opt_sub(obj)
            return @left + rht if rht 
            nil 
        end

        def *(obj : Negative)
            return -(self * obj.value)
        end

        def *(obj : Infinity)
            lft = @left.opt_prod(obj)
            return lft + @right if lft 
            rht = @right.opt_prod(obj)
            return @left + rht if rht 
            return Product.new(self,obj)
        end

        def *(obj)
            return self if obj == 1
            return SZERO if obj == 0
            return Power.new(self,STWO) if self == obj
            return Product.new(self,obj)
        end

        def opt_prod(obj)
            return self if obj == 1
            lft = @left.opt_prod(obj)
            return lft + @right if lft 
            rht = @right.opt_prod(obj)
            return @left + rht if rht 
            return self ** STWO if self == obj
            nil
        end

        def /(obj : Negative)
            return -(self / obj.value)
        end

        def /(obj : Infinity)
            return SZERO
        end

        def /(obj : Sum)
            return SONE if self == obj
            return Division.new(self,obj)
        end

        def /(obj)
            return self if obj == 1
            lft = @left.opt_div(obj)
            rht = @right.opt_div(obj)
            return lft + rht if lft && rht 
            return Product.new(self,PinfinityC) if obj == 0
            return Division.new(self,obj)
        end

        def opt_div(obj)
            return self if obj == 1
            lft = @left.opt_div(obj)
            rht = @right.opt_div(obj)
            return lft + rht if lft && rht  
            nil
        end

        def **(obj : PInfinity)
            return obj 
        end

        def **(obj : NInfinity)
            return SZERO
        end

        def **(obj)
            return SONE if obj == 0
            return self if obj == 1
            return Power.new(self,obj)
        end

        def diff(obj)
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

    end

end
