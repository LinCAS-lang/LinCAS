
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

    def self.module_init(mod : LcModule)
        mod.type      = SType::MODULE
        mod.klass     = Lc_Module
        mod.parent    = Obj
        mod.allocator = Allocator::UNDEF
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
        mod.symTab.parent = MainClass.symTab
        MainClass.symTab.addEntry(name,mod)
        return mod
    end

    def self.lc_build_internal_module_in(name : String,nest : Structure)
        mod = lc_build_module(name)
        mod.symTab.parent = nest.symTab
        nest.symTab.addEntry(name,mod)
        return mod
    end

    @[AlwaysInline]
    def self.lc_make_shared_module(mod : LcModule)
        symTab = lc_make_shared_sym_tab(mod.symTab)
        tmp    = LcModule.new(mod.name,symTab,mod.data,mod.methods,mod.statics,mod.path)
        module_init(tmp)
        return tmp
    end

    def self.lc_include_module(receiver : Structure, mod : LcModule)
        if mod.included.includes? receiver.id
            # lc_warn()
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

    Lc_Module = internal.lc_build_internal_class("cModule")

end