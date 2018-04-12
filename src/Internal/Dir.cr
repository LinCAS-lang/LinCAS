
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

    private def self.dir_current 
        c_dir = libc.getcwd(nil,0)
        if c_dir
            strlen = libc.strlen(c_dir)
            ptr    = CHAR_PTR.malloc(strlen + 1)
            ptr.copy_from(c_dir,strlen)
            libc.free(c_dir)
        else
            ptr = CHAR_PTR.null 
        end
        return ptr
    end

end