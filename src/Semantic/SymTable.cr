# Copyright (c) 2020 Massimiliano Dal Mas
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

require "set"

module LinCAS
  enum ID
    LOCAL_V
    CONST
    METHOD
    UNKNOWN
  end

  enum SymType
    PROGRAM
    CLASS
    METHOD
    BLOCK
  end

  ##
  # Symbol table. It's structure can be:
  # [a1, a2, a3,...]
  # <- local vars ->
  # 
  # [p1, p2, p3, p4, ..., a1, a2, a3, ...]
  # <- method params -->| <- local vars ->
  class SymTable < Array(String)
    getter type
    property previous 

    def initialize(@type : SymType, @previous : SymTable? = nil)
      super()
    end

    def <<(name : String)
      super(name) unless self.includes? name
      self
    end
    
  end
end
