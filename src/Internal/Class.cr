
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

    macro type_of(obj)
      {{obj}}.as(LcClass).type
    end

    macro class_name(klass)
      {{klass}}.as(LcClass).name 
    end

    macro check_pystructs(scp,str)
      if {{str}}.is_a? LcClass && 
        ({{str}}.type.py_class? || {{str}}.type.py_module?) &&
                                        ({{str}}.flags & ObjectFlags::REG_CLASS == 0)
        {{str}}.namespace.parent = {{scp}}.namespace
        {{scp}}.namespace.[{{str}}.name] = {{str}}
        {{str}}.flags |= ObjectFlags::REG_CLASS
      end
    end

    macro check_pystructs2(scp,str)
      if {{str}}.is_a? LcClass && 
        ({{str}}.type.py_class? || {{str}}.type.py_module?) &&
                                        ({{str}}.flags & ObjectFlags::REG_CLASS == 0)
        {{str}}.namespace.parent = {{scp}}
        {{scp}}[{{str}}.name] = {{str}}
        {{str}}.flags |= ObjectFlags::REG_CLASS
      end
    end

    def self.metaclass_of(klass : LcClass)
      m_class = klass.klass 
      if !type_of(m_class).metaclass?
        return lc_attach_metaclass(klass).klass
      end 
      return m_class
    end

    def self.class_of(obj : LcVal)
      klass = obj.klass
      while klass && type_of(klass).metaclass?
        klass = klass.parent
      end
      return klass.not_nil!
    end 
    
    # @[AlwaysInline]
    # def self.lc_build_class(name : String)
    #   klass      = LcClass.new(SType::CLASS, name)
    #   return klass
    # end

    @[AlwaysInline]
    def self.lc_build_metaclass(klass : LcClass, parent : LcClass?)
      return LcClass.new(SType::METACLASS, "#<Class:#{class_path(klass)}>", parent)
    end

    ##
    # This method attaches a metaclass to a class `k`.
    # The class of the metaclass is `Class`, and its
    # superclass is the class of superclass of `k`
    def self.lc_attach_metaclass(klass : LcClass)
      # This is a temporary solution. There must be
      # a check that ensures consistency between metaclasses
      if parent = klass.parent # klass.parent is not nil
        parent = parent.klass
      else
        parent = @@lc_class 
      end
      metaclass       = lc_build_metaclass(klass, parent)
      metaclass.klass = @@lc_class
      klass.klass     = metaclass
      return klass
    end

    @[AlwaysInline]
    def self.lc_build_class(name : String, namespace : NameTable, parent : LcClass)
      klass = LcClass.new(SType::CLASS, name, parent)
      klass.namespace.parent = namespace
      namespace[name] = klass
      return lc_attach_metaclass(klass)
    end

    ##
    # Used only to create the instance of `Class`
    # in its initialiser
    def self.lc_build_class_class
      klass     = LcClass.new(SType::CLASS, "Class", nil)
      metaclass = LcClass.new(SType::METACLASS, "#<Class:Class>", nil)
      metaclass.klass = klass
      klass.klass = metaclass
      return klass
    end

    @[AlwaysInline]
    def self.lc_build_user_class(name : String, namespace : NameTable, parent : LcClass = @@lc_object)
      klass = lc_build_class(name, namespace, parent)
      lc_set_parent_class(klass,parent)
      return klass
    end

    def self.lc_build_internal_class(name, parent : LcClass = @@lc_object)
      return lc_build_user_class(name, @@lc_object.namespace, parent)
    end

    def self.lc_build_unregistered_pyclass(name : String,obj : PyObject, parent : LcClass)
      gc_ref    = PyGC.track(obj)
      namespace = NameTable.new(obj)
      methods   = MethodTable.new(obj)
      klass     = LcClass.new(SType::PyCLASS, name, parent, methods, namespace)
      klass.gc_ref = gc_ref
      lc_attach_metaclass(klass)
      return klass
    end

    ##
    # It creates a python class embedding it with the definition of
    # a LinCAS class
    def self.lc_build_pyclass(name : String,obj : PyObject, namespace : NameTable)
      klass = lc_build_unregistered_pyclass(name,obj,@@lc_pyobject)
      klass.namespace.parent = namespace
      namespace[name]        = klass
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

    ##
    # It adds a method to an object.
    # Usage example:
    #   lc_add_method(obj.klass, "my_method", method)
    @[AlwaysInline]
    def self.lc_add_method(klass : LcClass, name : String, method : LcMethod)
      klass.methods[name] = method
    end

    @[AlwaysInline]
    def self.lc_add_method_with_owner(klass : LcClass, name : String, method : LcMethod)
      method.owner = klass
      lc_add_method(klass, name, method)
    end

    # @[AlwaysInline]
    # def self.lc_add_undef_method(receiver : LcClass,name : String,method : LcMethod)
    #     receiver.methods.addEntry(name,method)
    # end

    def self.lc_add_internal(receiver : LcClass, name : String, proc : LcProc, arity : Intnum)
      m = define_method(name, receiver, proc, arity)
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

    ##
    # Defines an internal static method  in the given class. No check is performed
    # to see if the method is defined
    def self.lc_add_static(receiver : LcClass, name : String, proc : LcProc,arity : Intnum)
      m = define_static(name,receiver,proc,arity)
      metaclass_of(receiver).methods[name] = m
    end

    ##
    # Removes an internal static method in the given class. No check is performed
    # to see if the method is defined
    # def self.lc_remove_static(receiver : LcClass,name : String)
    #   m = undef_static(name,receiver)
    #   metaclass_of(receiver).methods[name] = m
    # end

    
    def self.lc_class_add_method(receiver : LcClass,name : String,proc : LcProc,arity : Intnum)
      lc_add_internal(receiver,name,proc,arity)
      lc_add_static(receiver,name,proc,arity)
    end

    def self.lc_define_const(klass : LcClass, name : String, const :  LcVal)
      klass.namespace[name] = const
    end

    @[AlwaysInline]
    def self.lc_set_allocator(klass : LcClass,allocator : LcProc)
      klass.allocator = allocator 
    end

    @[AlwaysInline]
    def self.lc_undef_allocator(klass : LcClass)
      klass.allocator = Allocator::UNDEF 
    end

    ##
    # Not to be used directly
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

    def self.lc_seek_const(str : LcClass, name : String, exclude = false, recurse = true)
      return str if str.name == name
      parent = str
      while parent
        break if exclude && parent == @@lc_object && str != @@lc_object
        const = parent.namespace.find(name, const: true)
        if const
          check_pystructs(parent,const)
          return const
        end
        break unless recurse
        parent = parent.parent
      end
      return !exclude ? seek_const_in_scope(str.namespace,name) : nil
    end

    def self.lc_find_allocator(klass : LcClass)
      alloc = klass.allocator 
      return alloc if alloc
      klass = klass.parent
      while klass
        alloc = klass.allocator 
        return alloc if alloc
        klass = klass.parent
      end 
      return nil 
    end

    @[AlwaysInline]
    private def self.fetch_pystruct(name : String)
      name = "_#{name}"
      tmp = @@lc_object.namespace.find(name)
      if !tmp || !(tmp.is_a? LcClass)
        lc_bug("Previously declared Python Class/Module not found") 
      end
      return tmp.as(LcClass)
    end

    ######################################
    #  ____ _____ ____    _     _ _      #
    # / ___|_   _|  _ \  | |   (_) |__   #
    # \___ \ | | | | | | | |   | | '_ \  #
    #  ___) || | | |_| | | |___| | |_) | #
    # |____/ |_| |____/  |_____|_|_.__/  #
    ######################################

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
          objClass = objClass.parent
      end
      return lcfalse
    end

    def self.lc_class_real(klass : LcVal)
      return class_of(klass)
    end

    #@[AlwaysInline]
    #def self.lc_class_class(obj :  LcVal)
    #  klass = class_of(obj)
    #  while klass.type.metaclass?
    #end

    def self.lc_class_defrost(klass :  LcVal)
      klass.flags &= ~ObjectFlags::FROZEN 
      return klass 
    end 

    # TO BE TESTED
    def self.class_path(klass : LcClass)
      path     = [klass.name] of String
      id_table = klass.namespace.parent
      while id_table 
        super_id_table = id_table.parent 
        if super_id_table
          super_id_table.each do |k, v|
            if v.is_a?(LcClass) && v.namespace.object_id == id_table.object_id
              path << v.name
              break
            end
          end
        else 
          break # We reached the top level scope
        end
        id_table = super_id_table
      end 
      return path.reverse!.join("::")
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
        klass = lc_cast(klass,LcClass)
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

    def self.lc_class_parent(klass :  LcVal)
      s_klass = lc_cast(klass, LcClass).parent
      return s_klass if s_klass
      return Null 
    end

    def self.alias_method_str(klass : LcClass, m_name : String, new_name : String)
      cc = seek_method(klass,m_name,false)
      if method = cc.method
        lc_add_method(klass,new_name,method)
      elsif cc.m_missing_status == 1
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

    def self.lc_get_method(obj :  LcVal,name :  LcVal)
      name = id2string(name)
      return Null unless name 
      cc = seek_method(obj.klass,name, explicit: false, ignore_visib: true)
      unless cc.method 
        lc_raise(LcNoMethodError,"Undefined method `#{name}' for #{lc_typeof(obj)}")
        return Null 
      end
      return build_method(obj,cc.method.not_nil!)
    end

    def self.lc_instance_method(klass :  LcVal, name :  LcVal)
      name   = id2string(name)
      return Null unless name
      cc = seek_method(klass.klass, name, explicit: false, ignore_visib: true)
      unless cc.method
        lc_raise(LcNoMethodError,"Undefined method `#{name}' for #{lc_typeof(klass)}")
        return Null 
      end
      return build_unbound_method(cc.method.not_nil!)
    end


    def self.init_class
        @@lc_class  = lc_build_class_class

        add_method(@@lc_class,"parent",lc_class_parent,    0)

        # add_static_method(@@lc_class,"remove_instance_method",lc_class_rm_instance_method,     1)
        # add_static_method(@@lc_class,"remove_static_method",lc_class_rm_static_method,         1)
        # add_static_method(@@lc_class,"delete_static_method",lc_class_delete_static_method,     1)
        # add_static_method(@@lc_class,"delete_instance_method",lc_class_delete_instance_method, 1)
    end

end
