
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

    macro parent_of(klass)
       {{klass}}.as(LcClass).parent
    end

    macro class_of(obj)
        {{obj}}.klass 
    end

    macro path_of(obj)
        {{obj}}.as(LcClass).path 
    end

    macro type_of(obj)
        {{obj}}.as(LcClass).type
    end

    macro class_name(klass)
        {{klass}}.as(LcClass).name 
    end

    macro check_pystructs(scp,str)
        if {{str}}.is_a? LcClass && 
            ({{str}}.type.pyclass? || {{str}}.type.pymodule?) &&
                                            ({{str}}.flags & ObjectFlags::REG_CLASS == 0)
            {{str}}.namespace.parent = {{scp}}.symTab
            {{scp}}.namespace.[{{str}}.name] = {{str}}
            {{str}}.flags |= ObjectFlags::REG_CLASS
        end
    end

    macro check_pystructs2(klass,str)
        if {{str}}.is_a? LcClass && 
            ({{str}}.type.pyclass? || {{str}}.type.pymodule?) &&
                                            ({{str}}.flags & ObjectFlags::REG_CLASS == 0)
            {{str}}.namespace.parent = {{namespace}}
            {{klass}}[({{str}}.name] = {{str}}
            {{str}}.flags |= ObjectFlags::REG_CLASS
        end
    end
    
    @[AlwaysInline]
    def self.lc_build_class(name : String)
      klass      = LcClass.new(SType::CLASS, name)
      return klass
    end

    def self.lc_build_metaclass
      klass = LcClass.new(SType::METACLASS, "Class", @@lc_module)
      klass.klass = @@lc_class
      return klass
    end

    @[AlwaysInline]
    def self.lc_build_class(name : String,parent : LcClass)
      klass       = LcClass.new(SType::CLASS, name, parent)
      klass.klass = @@lc_class
      return klass
    end

    @[AlwaysInline]
    def self.lc_build_internal_class(name : String,parent : LcClass = @@lc_object)
      klass = lc_build_class(name, parent)
      # klass.namespace.parent = @@main_class.namespace
      # @@main_class.namespace[name] = klass
      lc_set_parent_class(klass,parent)
      return klass
    end

    def self.lc_build_class_class
      klass     = LcClass.new(SType::CLASS, "Class", @@lc_module)
      metaclass = LcClass.new(SType::METACLASS, "Class", @@lc_module)
      klass.klass = metaclass
      return klass
    end

    def self.lc_build_unregistered_pyclass(name : String,obj : PyObject,parent : LcClass)
      gc_ref    = PyGC.track(obj)
      namespace = NameTable.new(obj)
      methods   = MethodTable.new(obj)
      klass     = LcClass.new(SType::PyCLASS, name, parent, methods, namespace)
      klass.gc_ref = gc_ref
      klass.klass  = @@lc_class
      return klass
    end

    def self.lc_build_pyclass(name : String,obj : PyObject)
      klass               = lc_build_unregistered_pyclass(name,obj,@@lc_pyobject)
      klass.namespace.parent = @@main_class.namespace
      @@main_class.namespace[name] = klass
      klass.flags |= ObjectFlags::REG_CLASS
      return klass
    end

    # def self.lc_build_internal_class_in(name : String,nest : LcClass,parent : LcClass? = nil)
    #   klass               = lc_build_class(name)
    #   klass.symTab.parent = nest.symTab
    #   klass.klass         = @@lc_class
    #   nest.symTab.addEntry(name,klass)
    #   lc_set_parent_class(klass,parent)
    #   return klass
    # end

    @[AlwaysInline]
    def self.lc_set_parent_class(klass : LcClass,parent : LcClass)
      klass.parent = parent
    end

    @[AlwaysInline]
    def self.lc_add_method(receiver : LcClass, name : String, method : LcMethod)
      receiver.methods[name] = method
    end

    # @[AlwaysInline]
    # def self.lc_add_undef_method(receiver : LcClass,name : String,method : LcMethod)
    #     receiver.methods.addEntry(name,method)
    # end

    def self.lc_add_internal(receiver : LcClass,name : String,proc : LcProc,arity : Intnum)
      m = define_method(name,receiver,proc,arity)
      receiver.methods[name] = m
    end

    # def self.lc_add_internal_protected(receiver : LcClass,name : String,proc : LcProc,arity : Intnum)
    #   m = define_protected_method(name,receiver,proc,arity)
    #   receiver.methods[name] = m
    # end

    def self.lc_remove_internal(receiver : LcClass,name : String)
      m = undef_method(name,receiver)
      receiver.methods[name] = m
    end

    def self.lc_add_static(receiver : LcClass, name : String, proc : LcProc,arity : Intnum)
      m = define_static(name,receiver,proc,arity)
      class_of(receiver).methods[name] = m
    end

    def self.lc_remove_static(receiver : LcClass,name : String)
      m = undef_static(name,receiver)
      class_of(receiver).methods[name] = m
    end

    def self.lc_class_add_method(receiver : LcClass,name : String,proc : LcProc,arity : Intnum)
      lc_add_internal(receiver,name,proc,arity)
      lc_add_static(receiver,name,proc,arity)
    end

    def self.lc_define_const(str : LcClass, name : String, const :  LcVal)
      str.namespace[name] = const
    end

    @[AlwaysInline]
    def self.lc_set_allocator(klass : LcClass,allocator : LcProc)
      klass.allocator = allocator 
    end

    @[AlwaysInline]
    def self.lc_undef_allocator(klass : LcClass)
      klass.allocator = Allocator::UNDEF 
    end

    def self.seek_const_in_scope(scp : NameTable,name : String) :  LcVal?
      while scp 
        const = scp.find(name, const: true)
        if const
          check_pystructs2(scp,const)
          return const 
        end
        scp = scp.parent
      end 
      return nil
    end 

    def self.lc_seek_const(str : LcClass, name : String)
      const = seek_const_in_scope(str.namespace,name)
      return const if const
      parent = parent_of(str)
      while parent
        const = parent.namespace.find(name, const: true)
        if const
          check_pystructs(parent,const)
          return const
        end
        parent = parent_of(parent)
      end
      return nil
    end

    def self.lc_find_allocator(klass : LcClass)
      alloc = klass.allocator 
      return alloc if alloc
      klass = parent_of(klass)
      while klass
        alloc = klass.allocator 
        return alloc if alloc
        klass = parent_of(klass)
      end 
      return nil 
    end

    @[AlwaysInline]
    private def self.fetch_pystruct(name : String)
      name = "_#{name}"
      tmp = @@main_class.namespace.find(name)
      if !tmp || !(tmp.is_a? LcClass)
        lc_bug("Previously declared Python Class/Module not found") 
      end
      return tmp.as(LcClass)
    end

    #########

    @[AlwaysInline]
    def self.lc_class_compare(klass1 :  LcVal, klass2 :  LcVal)
      return val2bool(klass2.is_a?(LcClass) && 
              ((class_name(klass1) == class_name(klass2)) || 
              (klass1.object_id == klass2.object_id)))
    end

    def self.lc_is_a(obj :  LcVal, lcType :  LcVal)
      if !(lcType.is_a? LcClass)
        lc_raise(LcArgumentError,"Argument must be a class or a module")
        return lcfalse
      end
      objClass = class_of(obj)
      while objClass
          return lctrue if lc_class_compare(objClass,lcType) == lctrue
          objClass = parent_of(objClass)
      end
      return lcfalse
    end

    def self.lc_class_real(klass : LcVal)
      # TODO: class check tp avoid cast crash
      klass = lc_cast(klass, LcClass)
      while klass.type.metaclass?
        klass = class_of(klass)
      end 
      return klass
    end

    #@[AlwaysInline]
    #def self.lc_class_class(obj :  LcVal)
    #  klass = class_of(obj)
    #  while klass.type.metaclass?
    #end


    def self.lc_class_eq(klass :  LcVal, other :  LcVal)
      return val2bool(klass.class == other.class &&
                      type_of(klass) == type_of(other) &&
                      lc_class_compare(klass,other))
    end

    def self.lc_class_ne(klass :  LcVal, other)
      return lc_bool_invert(lc_class_eq(klass,other))
    end

    def self.lc_class_defrost(klass :  LcVal)
      klass.flags &= ~ObjectFlags::FROZEN 
      return klass 
    end 

    # TODO
    def self.class_path(klass)
      return klass.name
    end

    def self.lc_class_inspect(klass : LcVal)
      tmp = String.build do |io|
          io << '"'
          klass = klass.as(LcClass)
          io << class_path(klass)
          io << '"'
      end
      return internal.build_string(tmp)
    end

    def self.lc_class_to_s(klass : LcVal)
        klass = klass.as(LcClass)
        name = class_path(klass)
        return build_string(name)
    end

    # def self.lc_class_rm_static_method(klass :  LcVal, name :  LcVal)
    #   sname = id2string(name)
    #   return lcfalse unless sname
    #   unless lc_obj_responds_to? klass,sname
    #     lc_raise(LcNoMethodError, "Can't find static method '%s' for %s" % {sname,lc_typeof(klass)})
    #     return lcfalse 
    #   else 
    #     lc_remove_static(klass.as(LcClass),sname)
    #     return lctrue 
    #   end 
    # end

    # def self.lc_class_rm_instance_method(klass :  LcVal,name :  LcVal)
    #   sname = id2string(name)
    #   return lcfalse unless sname
    #   unless lc_obj_responds_to? klass,sname,false
    #     lc_raise(LcNoMethodError,"Can't find instance method '%s' for %s" % {sname,lc_typeof(klass)})
    #     return lcfalse 
    #   else 
    #     lc_remove_internal(klass.as(LcClass),sname)
    #     return lctrue  
    #   end
    # end
    
    # TODO: move to Object
    def self.lc_class_rm_method(obj :  LcVal,name :  LcVal)
      sname = id2string(name)
      return lcfalse unless sname
      unless lc_obj_responds_to? klass,sname,false
        lc_raise(LcNoMethodError,"Can't find instance method '%s' for %s" % {sname,lc_typeof(klass)})
        return lcfalse 
      else 
        lc_remove_internal(klass.as(LcClass),sname)
        return lctrue  
      end
    end

    # def self.lc_class_delete_instance_method(klass :  LcVal,name :  LcVal)
    #     sname = id2string(name)
    #     return lcfalse unless sname
    #     klass = klass.as(LcClass)
    #     if klass.methods.lookUp(sname)
    #         klass.methods.removeEntry(sname)
    #         return lctrue
    #     else 
    #         lc_raise(LcNoMethodError,"Instance method '%s' not defined in %s" % {sname,lc_typeof(klass)})
    #     end 
    #     return lcfalse 
    # end

    # def self.lc_class_delete_static_method(klass :  LcVal, name :  LcVal)
    #     sname = id2string(name)
    #     return lcfalse unless sname
    #     klass = klass.as(LcClass)
    #     if klass.statics.lookUp(sname)
    #         klass.statics.removeEntry(sname)
    #         return lctrue
    #     else
    #         lc_raise(LcNoMethodError,"Static method '%s' not defined in %s" % {sname,lc_typeof(klass)})
    #     end 
    #     return lcfalse 
    # end 

    def self.lc_class_delete_method(obj :  LcVal,name :  LcVal)
      isname = id2string(name)
      return lcfalse unless sname
      klass = class_of(obj)
      if klass.methods.find(sname)
        klass.methods.delete(sname)
        return lctrue
      else 
        lc_raise(LcNoMethodError,"Instance method '%s' not defined in %s" % {sname,lc_typeof(klass)})
      end 
      return lcfalse 
    end

    def self.lc_class_ancestors(klass :  LcVal)
      ary = build_ary_new
      while klass 
        lc_ary_push(ary,klass)
        klass = parent_of(klass)
      end
      return ary 
    end

    def self.lc_class_parent(klass :  LcVal)
      s_klass = parent_of(klass)
      return s_klass if s_klass
      return Null 
    end

    def self.alias_method_str(klass : LcClass, m_name : String, new_name : String)
      method = seek_method(klass,m_name,true)
      if method.is_a? LcMethod
        lc_add_method(klass,new_name,method)
      elsif method == 2
        lc_raise(LcNoMethodError,"Cannot alias protected methods")
        return false
      else
        lc_raise(LcNoMethodError,convert(:no_method) % klass.name)
        return false
      end
      return true
    end

    def self.lc_alias_method(klass :  LcVal, name :  LcVal, new_name :  LcVal)
      name = id2string(name)
      return lcfalse unless name 
      new_name = id2string(new_name)
      return lcfalse unless new_name
      if klass.is_a? LcClass
        return val2bool(alias_method_str(klass,name,new_name))
      else
        return val2bool(alias_method_str(class_of(klass),name,new_name))
      end
    end

    def self.lc_get_static_method(str : LcClass,name : String)
      method = seek_static_method(str,name)
      return nil unless method.is_a? LcMethod
      if method.type == LcMethodT::PYTHON
        method.needs_gc = false 
      end
      return method
    end

    def self.lc_get_instance_method(str : LcClass,name : String)
      method = seek_method(str,name)
      return nil unless method.is_a? LcMethod 
      if method.type == LcMethodT::PYTHON
        method.needs_gc = false 
      end
      return method
    end

    def self.lc_get_method(obj :  LcVal,name :  LcVal)
      name = id2string(name)
      return Null unless name 
      if obj.is_a? LcClass
        method = lc_get_static_method(obj,name)
      else
        method = lc_get_instance_method(class_of(obj),name)
      end
      unless method 
        lc_raise(LcNoMethodError,"Undefined method `#{name}' for #{lc_typeof(obj)}")
        return Null 
      end
      return build_method(obj,method)
    end

    def self.lc_instance_method(klass :  LcVal, name :  LcVal)
      name   = id2string(name)
      return Null unless name
      method = lc_get_instance_method(lc_cast(klass,LcClass),name)
      unless method
        lc_raise(LcNoMethodError,"Undefined method `#{name}' for #{lc_typeof(klass)}")
        return Null 
      end
      return build_unbound_method(method)
    end


    def self.init_class
        # @@main_class     = lc_build_class("BaseClass")
        @@lc_class        = lc_build_class_class
        @@lc_module.klass = @@lc_class
        add_static_method(@@lc_class,"==",   lc_class_eq,         1)
        add_static_method(@@lc_class,"!=",   lc_class_ne,         1)
        add_static_method(@@lc_class,"to_s", lc_class_to_s,       0)
        add_static_method(@@lc_class,"name", lc_class_to_s,       0)
        add_static_method(@@lc_class,"inspect",lc_class_inspect,  0)
        add_static_method(@@lc_class,"defrost",lc_class_defrost,  0)
        add_static_method(@@lc_class,"parent",lc_class_parent,    0)

        # add_static_method(@@lc_class,"remove_instance_method",lc_class_rm_instance_method,     1)
        # add_static_method(@@lc_class,"remove_static_method",lc_class_rm_static_method,         1)
        # add_static_method(@@lc_class,"delete_static_method",lc_class_delete_static_method,     1)
        # add_static_method(@@lc_class,"delete_instance_method",lc_class_delete_instance_method, 1)
        add_static_method(@@lc_class,"instance_method",lc_instance_method,                 1)
        add_static_method(@@lc_class,"ancestors", lc_class_ancestors,                      0)

        lc_class_add_method(@@lc_class,"is_a?", wrap(lc_is_a,2),                           1)
        lc_class_add_method(@@lc_class,"class",wrap(lc_class_class,1),                     0)
        lc_class_add_method(@@lc_class,"remove_method",wrap(lc_class_rm_method,2),         1)
        lc_class_add_method(@@lc_class,"delete_method",wrap(lc_class_delete_method,2),     1)
        lc_class_add_method(@@lc_class,"alias",wrap(lc_alias_method,3),                    2)
        lc_class_add_method(@@lc_class,"method",wrap(lc_get_method, 2),                    1)
    end

end
