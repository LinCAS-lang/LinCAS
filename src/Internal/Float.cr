
module LinCAS::Internal
    

    struct LcFloat < LcNum
        @val : Floatnum
        def initialize(@val)
        end
        getter val
    end
    
    @[AlwaysInline]
    def self.num2float(num : Floatnum)
        return build_float(num)
    end

    @[AlwaysInline]
    def self.float2num(float : Value)
        return float.as(LcFloat).val 
    end

    def self.build_float(num : Floatnum)
        flo       = LcFloat.new(num)
        flo.klass = FloatClass
        flo.data  = FloatClass.data.clone
        flo.frozen = true
        return flo
    end

    FloatClass = internal.lc_build_class_only("Float")
    internal.lc_set_parent_class(FloatClass,NumClass)
end