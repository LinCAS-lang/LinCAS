
# Copyright (c) 2017-2018 Massimiliano Dal Mas
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

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

    @[AlwaysInline]
    def self.lc_make_shared_module(mod : LcModule)
        symTab = lc_make_shared_sym_tab(mod.symTab)
        tmp    = LcModule.new(mod.name,symTab,mod.data,mod.methods,mod.statics,mod.path)
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
    internal.lc_set_parent_class(Lc_Module,Obj)

end