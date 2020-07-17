
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

    macro module_initializer(mod,type)
      {{mod}}.type      = {{type}}
      {{mod}}.klass     = @@lc_module
      {{mod}}.parent    = @@lc_object
      {{mod}}.allocator = Allocator::UNDEF
    end

    def self.module_init(mod : LcModule)
      module_initializer(mod,SType::MODULE)
    end

    def self.pymodule_init(mod : LcModule)
      module_initializer(mod,SType::PyMODULE)
    end

    def self.pymodule_init(mod : LcModule)
      module_initializer(mod,SType::PyMODULE)
    end
    
    def self.lc_build_module(name : String)
      mod = LcModule.new(name)
      module_init(mod)
      return mod
    end

    def self.lc_build_module(name : String, path : Path)
      mod = LcModule.new(name,path)
      module_init(mod)
      return mod
    end

    def self.lc_build_internal_module(name : String)
      mod               = lc_build_module(name)
      mod.symTab.parent = @@main_class.symTab
      @@main_class.symTab.addEntry(name,mod)
      return mod
    end

    def self.lc_build_unregistered_pymodule(name : String,obj : PyObject)
      gc_ref = PyGC.track(obj)
      stab  = HybridSymT.new(obj)
      smtab = HybridSymT.new(obj)
      mtab  = HybridSymT.new(obj)
      tmp   = LcModule.new(name,stab,Data.new,mtab,smtab)
      pymodule_init(tmp)
      tmp.gc_ref = gc_ref
      return tmp
    end

    def self.lc_build_pymodule(name : String,obj : PyObject)
      tmp = lc_build_unregistered_pymodule(name,obj)
      tmp.symTab.parent = @@main_class.symTab
      @@main_class.symTab.addEntry(name,tmp)
      tmp.flags |= ObjectFlags::REG_CLASS
      return tmp
    end

    def self.lc_build_internal_module_in(name : String,nest : LcClass)
      mod = lc_build_module(name)
      mod.symTab.parent = nest.symTab
      nest.symTab.addEntry(name,mod)
      return mod
    end

    @[AlwaysInline]
    def self.lc_make_shared_module(mod : LcModule)
      symTab = lc_make_shared_sym_tab(mod.symTab)
      tmp    = LcModule.new(mod.name,symTab,mod.data,mod.methods,mod.statics,mod.path)
      if mod.type == SType::PyMODULE
        pymodule_init(tmp)
      else
        module_init(tmp)
      end
      tmp.allocator = nil
      return tmp
    end

    def self.lc_include_module(receiver : LcClass, mod : LcModule)
      if mod.included.includes? receiver.id
        lc_warn("Module already included")
      else
        mod.included << receiver.id
        s_mod                  = lc_make_shared_module(mod)
        parent                 = receiver.parent 
        if parent
            s_mod.symTab.parent    = parent.symTab
            s_mod.parent           = parent
        end
        receiver.symTab.parent = s_mod.symTab
        receiver.parent        = s_mod 
      end
    end

    def self.lc_module_add_internal(mod : LcModule, name : String, method : LcProc, arity : Int32)
      internal.lc_add_internal(mod,name,method,arity)
      internal.lc_add_static(mod,name,method,arity)
    end

    def self.init_module
      @@lc_module = internal.lc_build_internal_class("Module")
    end

end