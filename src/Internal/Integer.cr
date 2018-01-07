
module LinCAS::Internal

    struct LcInt < LcNum
        @val : Intnum
        def initialize(@val)
        end
        getter val
    end

    @[AlwaysInline]
    def self.num2int(num : Intnum)
        return build_int(num)
    end

    @[AlwaysInline]
    def self.int2num(int : Value)
        return int.as(LcInt).val
    end 

    def self.build_int(value : Intnum)
        int       = LcInt.new(value)
        int.klass = IntClass
        int.data  = IntClass.data.clone
        int.frozen = true
        return int
    end 

    def self.lc_int_sum(n1 : Value, n2)
        #n1 = n1.as(LcInt)
        return internal.build_int(n1.as(LcInt).val + n2.as(LcInt).val)
    end

    IntClass = internal.lc_build_class_only("Integer")
    internal.lc_set_parent_class(IntClass,NumClass)

    internal.lc_add_internal(IntClass,"+",:lc_int_sum,1)
    
    
end