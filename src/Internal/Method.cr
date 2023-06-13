
# Copyright (c) 2017-2023 Massimiliano Dal Mas
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

  macro set_default(m,owner,code,arity)
    {{m}}.flags   = MethodFlags::INTERNAL
    {{m}}.owner  = {{owner}}
    {{m}}.code   = {{code}}
    {{m}}.arity  = {{arity}}
  end 

  macro is_pyembedded(strucure)
    ({{strucure}}.type == SType::PyMODULE) || 
       ({{strucure}}.type == SType::PyCLASS)
  end

  def self.new_pymethod(name : String, code : PyObject, owner : LcClass? = nil)
    return LcMethod.new(name, code, owner, FuncVisib::PUBLIC)
  end

  def self.new_pystatic_method(name : String,pyobj : PyObject, owner : LcClass? = nil)
    return new_pymethod(name,pyobj,owner,temp)
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

  ##
  # It defines an internal method (call to crystal)
  @[AlwaysInline]
  def self.lc_define_imethod(klass : LcClass, name : String, proc : LcProc, arity : Intnum, visib = FuncVisib::PUBLIC)
    m = LcMethod.new(name, proc, arity, klass, visib)
    lc_add_method(klass, name, m)
  end

  ##
  # it defines a user method (call to ISeq)
  def self.lc_define_umethod(klass : LcClass, name : String, code : ISeq, visib = FuncVisib::PUBLIC)
    m = LcMethod.new(name, code, klass, visib)
    lc_add_method(klass, name, m)
  end

  ##
  # it defines a python method (call to python)
  def self.lc_define_pymethod(klass : LcClass, name : String, code : Python::PyObject, visib = FuncVisib::PUBLIC)
    m = LcMethod.new(name, code, klass, visib)
    lc_add_method(klass, name, m)
  end

  ##
  # it defines an attribute method (getter / setter)
  def self.lc_define_attr_method(klass : LcClass, name : String, code : String, arity : IntnumR, flags : MethodFlags, visib = FuncVisib::PUBLIC)
    m = LcMethod.new(
      name,
      code,
      arity,
      klass,
      visib,
      flags
    )
    lc_add_method(klass, name, m)
  end

  ##
  # Defines an internal singleton method  in the given class. 
  def self.lc_define_singleton_imethod(klass : LcClass, name : String, proc : LcProc, arity : Intnum, visib = FuncVisib::PUBLIC)
    lc_define_imethod(metaclass_of(klass), name, proc, arity, visib)
  end

  ##
  # Defines a user singleton method  in the given class. 
  def self.lc_define_singleton_imethod(klass : LcClass, name : String, code : ISeq, visib = FuncVisib::PUBLIC)
    lc_define_umethod(metaclass_of(klass), name, code, visib)
  end

  def self.lc_undef_method(receiver : LcClass,name : String)
    m = LcMethod.new(name)
    lc_add_method(receiver, name, m)
  end

  def self.lc_class_define_method(klass : LcClass, name : String, proc : LcProc, arity : Intnum)
    lc_define_imethod(klass, name, proc, arity)
    lc_define_singleton_imethod(klass, name, proc, arity)
  end

  macro wrap(name,argc)
    LcProc.new do |args|
      next {{name.id}}(*args.as(T{{argc.id}}))
    end
  end

  macro define_method(klass, name, f_name, argc)
    lc_define_imethod(
      {{klass}},
      {{name}},
      LcProc.new do |args|
        {% if argc >= 0 %}
          {{ tmp = argc + 1}}
          {{f_name}}(*args.as(T{{tmp}}))
        {% else %}
          {{f_name}}(*args.as(T2))
        {% end %}
      end,
      {{argc}}
    )
  end

  macro define_protected_method(klass, name, f_name, argc)
    lc_define_imethod(
      {{klass}},
      {{name}},
      LcProc.new do |args|
        {% if argc >= 0 %}
          {{ tmp = argc + 1}}
          {{f_name}}(*args.as(T{{tmp}}))
        {% else %}
          {{f_name}}(*args.as(T2))
        {% end %}
      end,
      {{argc}},
      FuncVisib::PROTECTED
    )
  end

  macro define_singleton_method(klass,name,f_name,argc)
    lc_define_singleton_imethod(
      {{klass}},
      {{name}},
      LcProc.new do |args|
        {% if argc >= 0 %}
          {% tmp = argc + 1%}
          {{f_name}}(*args.as(T{{tmp}}))
        {% else %}
          {{f_name}}(*args.as(T2))
        {% end %}
      end,
      {{argc}}
    )
  end

  def self.seek_method(receiver : LcClass, name : String, explicit : Bool, ignore_visib = false)
    klass = receiver
    i = 0
    # when reason = 0 -> undefined
    # when reason = 1 -> protected method called
    # when reason = 2 -> private method called
    m_missing_reason = 0
    while klass && (i += 1)
      method = klass.methods.find(name)
      if method
        if method.is_a? PyObject # TO Fix
          if method.null?
            pyerr_clear
            method = nil
            m_missing_reason = 0 
          elsif type_of(receiver).metaclass? && is_pycallable(method) && !is_pytype(method) &&
            (is_pyclass_method(method) || !is_pyimethod(method))
            method = new_pystatic_method(name, method, receiver)
          else
            pyobj_decref(method)
            m_missing_reason = 0
          end
        else
          case method.visib
          when FuncVisib::PROTECTED
            method = ignore_visib ? method : (!explicit ? method : nil)
            m_missing_reason = 1
          when FuncVisib::PRIVATE 
            method = ignore_visib ? method : ((!explicit && i == 1) ? method : nil)
            m_missing_reason = 2
          when FuncVisib::UNDEFINED 
            method = nil 
            m_missing_reason = 0
          end 
        end
        break
      end
      klass = klass.parent
    end
    serial = method ? method.serial : Serial.new(0)
    return VM::CallCache.new(method, m_missing_reason, serial)
  end

  def self.invalidate_cc_by_class(klass, name)
    method = seek_method(klass, name, explicit: false, ignore_visib: true).method
    if method && method.cached?
      if lincas_class_compare(klass, method.owner)
        method.flags |= MethodFlags::INVALIDATED
      else
        method.clear_cache
      end
    end
  end

  def self.lc_obj_responds_to?(obj :  LcVal, name : String)
    return !!internal.seek_method(obj.klass, name, explicit: true).method # Method call is of explicit type
  end

  def self.lc_obj_has_internal_m?(obj :  LcVal,name : String)
    cc = internal.seek_method(obj.klass, name, explicit: false, ignore_visib: true)
    return -1 unless cc.method
    return 0 if cc.method.not_nil!.flags.internal? 
    return 1
  end


  ##################

  LC_METHOD_CALLER = ->(_self_ : PyObject,argv : PyObject) {
    {% begin %}
    {% if flag?(:x86_64) %}
      addr = pyuint64_to_uint64(_self_)
    {% else %}
      addr = pyuint32_to_uint32(_self_)
    {% end %}
    method = Pointer(Void).new(addr).as(Method)
    args   = pytuple2ary(argv)
    if args
      val = Exec.call_method(method,args)
      obj = obj2py(val)
      if obj
        pyobj_incref(obj)
        return obj  
      end
    end
    return_pynone
    {% end %}
  }


  class Method < LcBase
    def initialize(@receiver : LcVal, @method : LcMethod)
      @pym_def  = Pointer(Python::PyMethodDef).null
    end
    getter method, receiver
    property pym_def
  end

  class UnboundMethod < LcBase
    def initialize(@method : LcMethod)
    end
    getter method
  end

  macro method_get_receiver(method)
    lc_cast({{method}},Method).receiver 
  end

  macro method_pym_def(m)
    {{m}}.as(Method).pym_def
  end

  macro set_method_pym_def(m,d)
    {{m}}.as(Method).pym_def = {{d}}
  end

  @[AlwaysInline]
  private def self.build_method(receiver : LcVal, method : LcMethod)
    return lincas_obj_alloc(Method, @@lc_method, receiver, method)
  end

  @[AlwaysInline]
  private def self.build_unbound_method(method : LcMethod)
    return lincas_obj_alloc(UnboundMethod, @@lc_unbound_method, method)
  end

  @[AlwaysInline]
  def self.lc_method_call(method :  LcVal, argv :  LcVal)
    argv = argv.as Ary
    return Exec.call_method(lc_cast(method,Method), argv)
  end

  def self.lc_method_to_proc(method :  LcVal)

  end

  @[AlwaysInline]
  def self.lc_method_receiver(method :  LcVal)
    return method_get_receiver(method)
  end

  @[AlwaysInline]
  def self.lc_method_name(m : LcVal)
    m = m.as(Method).method
    return build_string(m.name)
  end

  @[AlwaysInline]
  def self.lc_method_owner(m : LcVal)
    m = m.as(Method).method
    return m.owner || Null
  end

  def self.method_to_py(method :  LcVal)
    {% begin %}
    addr = method.as(Void*).address
    {% if flag?(:x86_64) %}
      pyint = uint64_to_py(addr)
    {% else %}
      pyint = uint32_to_py(addr)
    {% end %}
    m = define_pymethod(method,LC_METHOD_CALLER,pyint,METH_VARARGS)
    pyobj_decref(pyint)
    return m
    {% end %}
  end

  def self.init_method
    @@lc_method = lc_build_internal_class("Method")
    lc_undef_allocator(@@lc_method)

    define_method(@@lc_method,"call",lc_method_call,         -1)
    define_method(@@lc_method,"receiver",lc_method_receiver,    0)
    define_method(@@lc_method,"name",lc_method_name,        0)
    define_method(@@lc_method,"owner",lc_method_owner,               0)

  end

  def self.init_unbound_method
    @@lc_unbound_method = lc_build_internal_class("UnboundMethod")
    lc_undef_allocator(@@lc_unbound_method)
  end


end
