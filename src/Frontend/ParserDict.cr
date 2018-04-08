
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
