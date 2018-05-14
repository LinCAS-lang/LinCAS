
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

    def self.lc_build_module_only(name : String)
        return Id_Tab.addModule(name,true)
    end
    
    def self.lc_build_module(name : String)
        return Id_Tab.addModule(name)
    end

<<<<<<< HEAD
    def self.lc_include_module(receiver : Structure, mod : ModuleEntry)
        if receiver.included.includes? mod.path
=======
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
>>>>>>> lc-vm
            # lc_warn()
        else
            internal.lc_copy_methods_as_instance_in(mod,receiver)
            internal.lc_copy_consts_in(mod,receiver)
        end
    end

    def self.lc_module_add_internal(mod : ModuleEntry, name : String, method : LcProc, arity : Int32)
        internal.lc_add_internal(mod,name,method,arity)
        internal.lc_add_static(mod,name,method,arity)
    end

<<<<<<< HEAD
    LcModule = internal.lc_build_module_only("Module")
=======
    Lc_Module = internal.lc_build_internal_class("cModule")
>>>>>>> lc-vm

end