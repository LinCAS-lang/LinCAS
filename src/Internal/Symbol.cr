
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

    SYM_REGISTER = {} of String => LcSymbol
    Q_SYM_BEG    = ":\""

    class LcSymbol < BaseC
        def initialize(@origin : String)
        end
        @hash_   : UInt64 = 0.to_u64
        getter origin
        property hash_
    end

    macro set_sym_hash(sym,hash)
        lc_cast({{sym}},LcSymbol).hash_ = {{hash}}
    end

    macro get_sym_hash(sym)
        lc_cast({{sym}},LcSymbol).hash_
    end

    macro get_sym_origin(sym)
        lc_cast({{sym}},LcSymbol).origin
    end

    def self.symbol_new(string : String)
        sym = LcSymbol.new(string)
        sym.klass = SymClass 
        sym.data  = SymClass.data.clone 
        sym.id = sym.object_id
        lc_obj_freeze(sym)
        return sym.as(Value)
    end

    def self.build_symbol(string : String)
        sym = SYM_REGISTER[string]?
        return sym if sym 
        return string_to_symbol(string)
    end

    @[AlwaysInline]
    def self.string2sym(string : String)
        string = prepare_string_for_symbol(string)
        return build_string(string)
    end

    @[AlwaysInline]
    def self.sym2string(sym : Value)
        origin = get_sym_origin(sym)
        return extract_sym_name(origin)
    end

    @[AlwaysInline]
    private def self.register_sym(string : String, sym : Value)
        SYM_REGISTER[string] = lc_cast(sym,LcSymbol)
    end

    @[AlwaysInline]
    private def self.extract_sym_name(sym : String)
        if sym.starts_with? Q_SYM_BEG
            return sym[2...(sym.size - 1)]
        else
            return sym[1...sym.size]
        end
    end

    @[AlwaysInline]
    private def self.id2string(id : Value)
        if id.is_a? LcString 
            return string2cr(id)
        elsif id.is_a? LcSymbol
            return sym2string(id)
        end
        lc_raise(LcTypeError,"Expecting String or Symbol (#{lc_typeof(id)} given)")
        nil
    end

    def self.lc_sym_inspect(sym : Value)
        return build_string(get_sym_origin(sym))
    end
    
    sym_inspect = LcProc.new do |args|
        next lc_sym_inspect(*lc_cast(args,T1))
    end

    def self.lc_sym_to_s(sym : Value)
        return build_string_recycle(sym2string(sym))
    end

    sym_to_s = LcProc.new do |args|
        next lc_sym_to_s(*lc_cast(args,T1))
    end

    @[AlwaysInline]
    private def self.sym_hash(sym : LcSymbol)
        hash = get_sym_hash(sym)
        return  hash.hash
    end

    def self.lc_sym_hash(sym : Value)
        return num2int(sym_hash(lc_cast(sym,LcSymbol)).to_i64)
    end
    
    sym_hash_ = LcProc.new do |args|
        next lc_sym_hash(*lc_cast(args,T1))
    end

    SymClass = lc_build_internal_class("Symbol")
    lc_undef_allocator(SymClass)


    lc_add_internal(SymClass,"inspect",sym_inspect,          0)
    lc_add_internal(SymClass,"to_s",sym_to_s,                0)
    lc_add_internal(SymClass,"hash",sym_hash_,               0)



end