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

  class SymTable
    class Entry
      getter types 
      
      def initialize
        @types = Set(ID).new(1)
      end

      def <<(id_t : ID)
        @types << id_t
      end
    end

    def initialize
      @entries = {} of String => Entry 
    end 

    def []=(name,entry)
    end 

    def []?(name)
      @entries[name]?
    end
  end

end