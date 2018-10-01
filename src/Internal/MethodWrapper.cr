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
    alias Value = Internal::Value
    alias T1 = Tuple(Value)
    alias T2 = Tuple(Value,Value)
    alias T3 = Tuple(Value,Value,Value)
    alias T4 = Tuple(Value,Value,Value,Value)
    alias An = Array(Value)
    alias Va = T1 | T2 | T3 | T4 | An 

    alias PV = Proc(Va,Value?)

    struct LcProc
        @proc : PV
        def initialize(&block : Va -> Value?)
            @proc = block 
        end

        def call(args : An)
            return @proc.call(args)
        end

        def call(*args : Value)
            return @proc.call(args)
        end

    end

end