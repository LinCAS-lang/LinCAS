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
    alias T1 = Tuple( LcVal)
    alias T2 = Tuple( LcVal, LcVal)
    alias T3 = Tuple( LcVal, LcVal, LcVal)
    alias T4 = Tuple( LcVal, LcVal, LcVal, LcVal)
    alias Va = T1 | T2 | T3 | T4

    alias PV = Proc(Va, LcVal)

    struct LcProc
        @proc : PV
        def initialize(&block : Va ->  LcVal)
            @proc = block 
        end

        def call(*args :  LcVal)
            return @proc.call(args)
        end

    end

end