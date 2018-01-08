
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
        TkType::SMALLER_EQ => NodeType::SE,
        TkType::AND     => NodeType::AND,
        TkType::OR      => NodeType::OR
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
        return BoolOpDictTr.has_key? tkType
    end
end