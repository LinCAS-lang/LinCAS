
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
  alias SymTab_t = SymTab | HybridSymT

  enum Allocator 
    UNDEF 
  end

  enum SType
    METACLASS
    CLASS 
    MODULE 
    PyMODULE
    PyCLASS
  end
  
  alias IvarTable = Hash(String, LcVal)

  class LcClass
    @flags     : ObjectFlags = ObjectFlags::NONE
    @methods   : LookUpTable
    @namespace : LookUpTable
    @ivar      : IvarTable
    @type      : SType
    @id        : UInt64 = 0.to_u64
    @name      : String
    @parent    : LcClass
    @allocator : Caller?  | Allocator = nil 
    @gc_ref    : Internal::PyGC::Ref? = nil

    @klass = uninitialized LcClass

    property flags, ivar, id, parent, allocator, gc_ref
    getter methods, namespace, type, name, 

    def initialize(@type, @name)
      @methods   = LookUpTable.new 
      @namespace = LookUpTable.new
      @ivar      = IvarTable.new
      @parent    = uninitialized LcClass
    end

    def initialize(@type, @name, @parent)
      @methods   = LookUpTable.new 
      @namespace = LookUpTable.new
      @ivar      = IvarTable.new
    end

    def initialize(@type, @name, @parent, @methods, @namespace)
      @ivar = IvarTable.new
    end
  end

  class LookUpTable
    @parent : LookUpTable? = nil 
    property parent, sym_tab
    getter   pyObj
  end
end