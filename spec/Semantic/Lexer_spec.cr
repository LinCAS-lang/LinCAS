# Copyright (c) 2020 Massimiliano Dal Mas
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

def it_lexes(string, token_t)
  it "lexes #{string.inspect}" do 
    lexer = Lexer.new __FILE__, string
    lexer.disable_regex #if !regexp
    token = lexer.next_token
    token.type.should eq(token_t)
  end 
end

def it_lexes_no_regexp(string, token_t)
  it "lexes #{string.inspect}" do 
    lexer = Lexer.new __FILE__, string
    lexer.disable_regex
    token = lexer.next_token
    token.type.should eq(token_t)
  end 
end

def it_lexes(string, token_t, value : String | Symbol)
  it "lexes #{string.inspect}" do 
    lexer = Lexer.new __FILE__, string
    lexer.disable_regex #if !regexp
    token = lexer.next_token
    token.type.should eq(token_t)
  end 
end

def it_lexes(string, token_t, value, is_kw)
  it "lexes #{string.inspect}" do 
    lexer = Lexer.new __FILE__, string
    token = lexer.next_token
    token.type.should eq(token_t)
  end 
end

def it_lexes_keywords(kwds)
  kwds.each do |kw|
    it_lexes kw.to_s, :IDENT, kw, true
  end
end

def it_lexes_idents(idents)
  idents.each do |id|
    it_lexes id, :IDENT, id, false
  end 
end

def it_lexes_operators(operators)
  operators.each do |op|
    it_lexes_no_regexp op.to_s, op
  end 
end

def it_lexes_symbols(symbols)
  symbols.each do |sym|
    it_lexes sym, :SYMBOL, sym
  end 
end 

describe "Lexer" do
  it_lexes "", :EOF
  it_lexes " ", :SPACE 
  it_lexes "\t", :SPACE
  it_lexes "\n", :EOL
  it_lexes "\n\n\n", :EOL 
  it_lexes_keywords [:if, :elsif, :then, :else, :let, :select, :case, :while, :until,
                     :do, :for, :to, :downto, :class, :module, :public, :protected,
                     :private, :inherits, :const, :new, :self, :yield, :__FILE__,
                     :__DIR__, :try, :catch, :true, :false, :null, :return, :next]
  it_lexes_idents ["ident", "other", "letting", "constant", "ident?", "ident!", "_ident"]
  it_lexes_idents ["ident_1", "id234", "let?", "class?", "module!"]
  it_lexes_operators [:".", :"..", :"...", :"+", :"-", :"*", :"**", :"/", :"\\", :"+=",
                      :"-=", :"*=", :"**=", :"/=", :"\\=", :"^", :"^=", :">", :">=", :"<",
                      :"<=", :"==", :"===", :"=", :":=", :"%", :"%=", :"!", :"!=", :"&", :"&=",
                      :"&&", :"&&=", :"|", :"||", :"|=", :"||=", :":", :"::", :",", :"<<",
                      :">>", :"(", :")", :"[", :"]", :"{",:"}", :"[]", :"[]=", :"\"", :"'",
                      :"$", :"$!", :"=>", :"-@"]
  it_lexes ";", :SEMICOLON
  it_lexes "!@bar", :"!"
  it_lexes "+@bar", :"+"
  it_lexes "-@bar", :"-@"
  it_lexes "&@baz", :"&"
  it_lexes "|@baz", :"|"
  it_lexes "Var", :CAPITAL_VAR
  it_lexes "@var", :INSTANCE_VAR
  it_lexes "@@var", :CLASS_VAR
  it_lexes_symbols [":<=", ":!", ":==", ":+", ":-", ":*", ":**", ":/", ":\\", ":^", ":&", ":%", 
                    ":[]", ":[]=", ":>", ":>=", ":>>", ":<<", ":foo", ":foo!", ":foo?", ":foo="]
  it_lexes ":\"", :":\""
end