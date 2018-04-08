
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

    abstract struct BinaryOp < SBaseS

        macro reduce_loop(val,tmp)
            while {{val}} != {{tmp}}
                {{tmp}} = {{val}}
                {{val}} = {{val}}.reduce
            end
        end

        property left,right 

        def initialize(left : Sym, right : Sym)
            super()
            left.top  = false 
            right.top = false
            @left     = left  
            @right    = right
        end

        def initialize(left,right,top)
            super(top)
            initialize(left,right)
        end

        def reduce
            tmp   = @left 
            @left = @left.reduce 
            reduce_loop(@left,tmp)
            tmp    = @right 
            @right = @right.reduce 
            reduce_loop(@right,tmp)
        end

        def ==(obj : BinaryOp)
            return false unless self.class = obj.class
            return (self.left == obj.left) && (self.right == obj.right)
        end 

        @[AlwaysInline]
        def ==(obj)
            return false 
        end

        def depend?(obj)
            return (@left.depend? obj) || (@right.depend? obj)
        end

    end
    
end
