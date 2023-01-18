# Copyright (c) 2020-2023 Massimiliano Dal Mas
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
  module VmArgs 

    def vm_check_arity(given, expected)
    end

    def vm_collect_args(argc, ci : CallInfo)
      return case argc
      when 0 
        {topn(0)}
      when 1
        {topn(1), topn(0)}
      when 2
        {topn(2), topn(1), topn(0)}
      when 3
        {topn(3), topn(2), topn(1), topn(0)}
      else
        depth = ci.argc
        {topn(depth + 1), @stack.shared_copy(@sp - depth, depth).as(LcVal)}
      end
    end
  end
end