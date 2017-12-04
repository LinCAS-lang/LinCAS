
module LinCAS

    private OpOpDictTranslate = {
        TkType::PLUS    => NodeType::SUM,
        TkType::MINUS   => NodeType::SUB,
        TkType::STAR    => NodeType::MUL,
        TkType::SLASH   => NodeType::FDIV,
        TkType::BSLASH  => NodeType::IDIV,
        TkType::MOD     => NodeType::MOD,
        TkType::GREATER => NodeType::GR,
        TkType::SMALLER => NodeType::SM,
        TkType::EQ_EQ   => NodeType::EQ,
        TkType::NOT_EQ  => NodeType::NE,
        TkType::GREATER_EQ => NodeType::GE,
        TkType::SMALLER_EQ => NodeType::SE
    }

    private BoolOpDictTr = {
        TkType::AND => NodeType::AND,
        TkType::OR  => NodeType::OR
    }

    @[AlwaysInline]
    protected def convertOp(tkType : TkType) : NodeType?
        OpOpDictTranslate[tkType]?
    end

    @[AlwaysInline]
    protected def opInclude?(tkType : TkType)
        OpOpDictTranslate.has_key? tkType
    end

    @[AlwaysInline]
    protected def convertBoolOp(tkType : TkType) : NodeType?
        BoolOpDictTr[tkType]?
    end

    @[AlwaysInline]
    protected def boolOpInclude?(tkType : TkType)
        BoolOpDictTr.has_key? tkType
    end
end