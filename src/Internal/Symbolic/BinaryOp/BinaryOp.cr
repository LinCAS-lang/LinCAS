
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

    abstract class BinaryOp < SBaseC

        property left : Symbolic,right : Symbolic 

        def initialize(@left : Symbolic, @right : Symbolic)
        end

        def ==(obj : BinaryOp)
            return false unless self.class == obj.class
            return ((self.left == obj.left) && (self.right == obj.right)) ||
                   ((self.right == obj.left) && (self.left == obj.right)) ||
                   ((self.left == obj.right) && (self.right == obj.left))
        end 

        def ==(obj)
            return false 
        end

        def depend?(obj)
            return (@left.depend? obj) || (@right.depend? obj)
        end

    end
    
end
