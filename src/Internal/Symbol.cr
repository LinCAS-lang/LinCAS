
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
        sym    = lincas_obj_alloc LcSymbol, @@lc_symbol, string, data: @@lc_symbol.data.clone 
        sym.id = sym.object_id
        return lc_obj_freeze(sym)
    end

    def self.build_symbol(string : String)
        sym = SYM_REGISTER[string]?
        return sym if sym 
        return string_to_symbol(string)
    end

    @[AlwaysInline]
    def self.string2sym(string : String)
        string = prepare_string_for_sym(string)
        return build_symbol(string)
    end

    @[AlwaysInline]
    def self.sym2string(sym :  LcVal)
        origin = get_sym_origin(sym)
        return extract_sym_name(origin)
    end

    @[AlwaysInline]
    private def self.register_sym(string : String, sym :  LcVal)
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
    private def self.id2string(id :  LcVal)
        if id.is_a? LcString 
            return string2cr(id)
        elsif id.is_a? LcSymbol
            return sym2string(id)
        end
        lc_raise(LcTypeError,"Expecting String or Symbol (#{lc_typeof(id)} given)")
        nil
    end

    def self.lc_sym_inspect(sym :  LcVal)
        return build_string(get_sym_origin(sym))
    end

    def self.lc_sym_to_s(sym :  LcVal)
        return build_string_recycle(sym2string(sym))
    end

    @[AlwaysInline]
    private def self.sym_hash(sym : LcSymbol)
        hash = get_sym_hash(sym)
        return  hash.hash
    end

    def self.lc_sym_hash(sym :  LcVal)
        return num2int(sym_hash(lc_cast(sym,LcSymbol)).to_i64)
    end

    def self.lc_sym_eq(sym :  LcVal, other :  LcVal)
        return lcfalse unless other.is_a? LcSymbol 
        return val2bool(sym.id == other.id)
    end

    def self.lc_sym_capitalize(sym :  LcVal)
        origin = get_sym_origin(sym)
        origin = extract_sym_name(origin).capitalize
        return string2sym(origin)
    end

    def self.lc_sym_downcase(sym :  LcVal)
        origin = get_sym_origin(sym).downcase 
        return build_symbol(origin)
    end

    def self.lc_sym_size(sym :  LcVal)
        origin = get_sym_origin(sym)
        len    = extract_sym_name(origin).size 
        return num2int(len )
    end

    def self.lc_sym_swapcase(sym :  LcVal)
        origin = get_sym_origin(sym).swapcase # Unexisting method
        return build_symbol(origin)
    end

    def self.init_symbol
        @@lc_symbol = lc_build_internal_class("Symbol")
        lc_undef_allocator(@@lc_symbol)


        add_method(@@lc_symbol,"inspect",lc_sym_inspect,          0)
        add_method(@@lc_symbol,"to_s",lc_sym_to_s,                0)
        add_method(@@lc_symbol,"hash",lc_sym_hash,                0)
        add_method(@@lc_symbol,"==",lc_sym_eq,                    1)
        add_method(@@lc_symbol,"capitalize",lc_sym_capitalize,    0)
        add_method(@@lc_symbol,"lowcase",lc_sym_downcase,         0)
        add_method(@@lc_symbol,"size",lc_sym_size,                0)
        alias_method_str(@@lc_symbol,"size","length")
        #lc_add_internal(@@lc_symbol,"swapcase",sym_swapcase,        0)
    end


end