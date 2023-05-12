
# Copyright (c) 2017-2022 Massimiliano Dal Mas
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

    macro module_initializer(mod)
      {{mod}}.klass     = lc_build_metaclass(mod, @@lc_module)
      {{mod}}.allocator = Allocator::UNDEF
    end

    @[AlwaysInline]
    def self.module_init(mod : LcClass)
      module_initializer(mod)
    end

    @[AlwaysInline]
    def self.pymodule_init(mod : LcClass)
      module_init(mod)
    end

    def module_included()
      
    end

    ##
    # This method is called only by the `module` initializer.
    # This is a special one as it does not set the parent
    # of the class (that will be sed in `Object`) and it does not
    # create a module, but the class `Module` instead
    def self.lc_build_module_class
      mod = LcClass.new(SType::CLASS, "Module")
      mod.klass = lc_build_metaclass(mod, nil)
      return mod
    end
    
    def self.lc_build_module(name : String)
      mod = LcClass.new(SType::MODULE, name)
      module_init(mod)
      return mod
    end

    def self.lc_module_allocate(klass : LcVal)
      klass = klass.as(LcClass)
      # :::
    end

    # def self.lc_build_module(name : String, path : Path)
    #   mod = LcModule.new(name,path)
    #   module_init(mod)
    #   return mod
    # end

    def self.lc_build_user_module(name : String, namespace : NameTable)
      mod = lc_build_module(name)
      mod.namespace.parent = namespace 
      namespace[name] = mod
      return mod
    end

    def self.lc_build_internal_module(name : String)
      return lc_build_user_module(name, @@lc_object.namespace)
    end

    def self.lc_build_unregistered_pymodule(name : String,obj : PyObject)
      gc_ref = PyGC.track(obj)
      namespace = NameTable.new(obj)
      methods   = MethodTable.new(obj)
      mod       = LcClass.new(SType::PyMODULE, name, nil, methods, namespace)
      pymodule_init(mod)
      mod.gc_ref = gc_ref
      return mod
    end

    def self.lc_build_pymodule(name : String,obj : PyObject, namespace : NameTable)
      tmp = lc_build_unregistered_pymodule(name,obj)
      tmp.namespace.parent = namespace
      namespace[name] = tmp
      tmp.flags |= ObjectFlags::REG_CLASS
      return tmp
    end

    @[AlwaysInline]
    def self.lc_make_shared_module(mod : LcClass)
      tmp = LcClass.new(mod.type, mod.name, nil, mod.methods, mod.namespace, mod.data)
      if mod.type == SType::PyMODULE
        pymodule_init(tmp)
      else
        module_init(tmp)
      end
      tmp.allocator = nil
      return tmp
    end

    def self.lc_include_module(receiver : LcClass, mod : LcClass)
      if receiver.methods.object_id == mod.methods.object_id
        lc_raise(lc_arg_err, "Cyclic include detected")
      else
        s_mod  = lc_make_shared_module(mod)
        parent = receiver.parent 
        if parent
          s_mod.parent = parent
        end
        receiver.parent = s_mod 
      end
    end

    
    def self.lc_mod_ancestors(klass :  LcVal)
      ary = new_array
      while klass 
        lc_ary_push(ary,klass)
        klass = lc_cast(klass, LcClass).parent
      end
      return ary 
    end

    def self.lc_module_rm_method(obj :  LcVal,name :  LcVal)
      sname = id2string(name)
      return lcfalse unless sname
      unless lc_obj_responds_to? obj, sname
        lc_raise(lc_nomet_err,"Can't find instance method '%s' for %s" % {sname,lc_typeof(obj)})
        return lcfalse 
      else 
        invalidate_cc_by_class(obj.klass, sname)
        lc_undef_method(obj.klass,sname)
        return lctrue  
      end
    end

    def self.lc_module_delete_method(obj :  LcVal,name :  LcVal)
      sname = id2string(name)
      return lcfalse unless sname
      klass = class_of(obj)
      if method = klass.methods.find(sname)
        method.flags |= MethodFlags::INVALIDATED
        klass.methods.delete(sname)
        return lctrue
      else 
        lc_raise(lc_nomet_err,"Instance method '%s' not defined in %s" % {sname,lc_typeof(klass)})
      end 
      return lcfalse 
    end

    @[AlwaysInline]
    def self.lincas_attr?(id : String)
      if id.ends_with? /\?|\!|=/
        lc_raise(lc_name_err, "Invalid attribute name #{id}")
      end
    end

    def self.lc_attr(klass : LcClass, id : String, read : Bool, write : Bool)
      if read
        lc_define_attr_method(klass, id, "@#{id}", 0, MethodFlags::ATTR_READER)
      end
      if write
        lc_define_attr_method(klass, "#{id}=", "@#{id}", 1, MethodFlags::ATTR_WRITER)
      end
    end

    def self.lc_module_property(klass : LcVal, argv : LcVal)
      if klass.is_a? LcClass
        argv  = lc_recast(argv, Ary)
        names = new_array_size argv.size * 2
        argv.each do |name|
          id = id2string(name)
          lincas_attr? id
          lc_attr(klass, id, read: true, write: true)
          lc_ary_push names, string2sym(id)
          lc_ary_push names, string2sym("#{id}=")
        end
        return names
      else
        lc_bug("Property method expected a class/module")
        Null # unreachable
      end
    end

    def self.lc_module_getter(klass : LcVal, argv : LcVal)
      if klass.is_a? LcClass
        argv  = lc_recast(argv, Ary)
        names = new_array_size argv.size
        argv.each do |name|
          id = id2string(name)
          lincas_attr? id
          lc_attr(klass, id, read: true, write: false)
          lc_ary_push names, string2sym(id)
        end
        return names
      else
        lc_bug("Property method expected a class/module")
        Null # unreachable
      end
    end

    def self.lc_module_setter(klass : LcVal, argv : LcVal)
      if klass.is_a? LcClass
        argv  = lc_recast(argv, Ary)
        names = new_array_size argv.size
        argv.each do |name|
          id = id2string(name)
          lincas_attr? id
          lc_attr(klass, id, read: false, write: true)
          lc_ary_push names, string2sym("#{id}=")
        end
        return names
      else
        lc_bug("Property method expected a class/module")
        Null # unreachable
      end
    end

    def self.init_module
      @@lc_module = lc_build_internal_class("Module", @@lc_object) { lc_build_module_class }

      define_method(@@lc_module,"to_s", lc_class_to_s,       0)
      define_method(@@lc_module,"name", lc_class_to_s,       0)
      define_method(@@lc_module,"inspect",lc_class_inspect,  0)
      define_method(@@lc_module,"defrost",lc_class_defrost,  0)
      define_method(@@lc_module,"instance_method",lc_instance_method,       1)
      define_method(@@lc_module,"ancestors", lc_mod_ancestors,              0)
      define_method(@@lc_module,"alias",lc_alias_method,                    2)
      define_method(@@lc_module,"remove_method",lc_module_rm_method,        1)
      define_method(@@lc_module,"delete_method",lc_module_delete_method,    1)
      define_method(@@lc_module,"property",lc_module_property,             -2)
      define_method(@@lc_module,"getter",lc_module_getter,                 -2)
      define_method(@@lc_module,"setter",lc_module_setter,                 -2)
    end

end