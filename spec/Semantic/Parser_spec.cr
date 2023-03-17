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

require "set"
require "./ParserHelper"

# for reference only
class VM
  def lc_raise_syntax_error(*args)
  end
end
Exec = VM.new

def symtab(type)
  return SymTable.new(type)
end

def regex(string, options = Regex::Options::None)
  return RegexLiteral.new(StringLiteral.new([string] of String | Node, false), options)
end

def it_parses_single2(string, expected_nodes : Array(Node))
  it "Parses #{string.inspect}" do
    parser = Parser.new(__FILE__, string)
    parser.spec_mode
    nodes = parser.parse.body.nodes
    nodes.should eq(expected_nodes)
  end
end

def it_parses_single(string, expected_node)
  it "Parses #{string.inspect}" do
    parser = Parser.new(__FILE__, string)
    parser.spec_mode
    node = parser.parse.body.nodes.first
    node.should eq(expected_node)
  end
end

def it_parses_multiple(string : Array(String), expected_node)
  string.each { |str| it_parses_single(str, expected_node) }
end

def it_parses_multiple2(string : Array(String), expected_nodes : Array(Node))
  string.each_with_index { |str, i| it_parses_single(str, expected_nodes[i]) }
end

def it_parses_multiple3(string : Array(String), expected_nodes : Array(Node))
  string.each { |str| it_parses_single2(str, expected_nodes) }
end

def assert_syntax_error(string, msg)
  it "Raises syntax error on #{string}" do
    begin
      parser = Parser.new(__FILE__, string)
      parser.spec_mode
      parser.parse
    rescue error : Parser::SyntaxException
      unless error.message.not_nil!.includes? msg
        fail "Expected message #{msg.inspect} but got #{error.message.inspect}"
      end
    end
  end
end

describe Parser do
  it "Parses an empty program" do
    parser = Parser.new(__FILE__, "")
    prog = parser.parse
    prog.class.should eq(Program)
    prog.filename.should eq(__FILE__)
    prog.body.class.should eq(Body)
  end
  
  it_parses_single "123", "123".int
  it_parses_single "1.3", "1.3".float
  it_parses_single "12i", "12i".complex
  it_parses_single "true", true.bool
  it_parses_single "false", false.bool
  it_parses_single "foo", "foo".variable
  it_parses_single "Foo", "Foo".variable
  it_parses_single "self", Self.new

  [":foo", ":foo!", ":foo?", ":かたな", ":+", ":-", ":*", ":/", ":==", ":<", ":<=", ":>",
   ":>=", ":!", ":&", ":|", ":^", ":**", ":>>", ":<<", ":%", ":[]", ":[]=",
   # ":~", ":!=", ":=~", ":!~", ":<=>", ":==="
  ].each do |symbol|
    it_parses_single symbol, symbol.symbol
  end
  
  it_parses_multiple ["'foo'", "\"foo\""], StringLiteral.new(["foo"] of Node | String, false)
  it_parses_single "\"foo\\\n bar\"", StringLiteral.new(["foobar"] of Node | String, false)
  it_parses_single "'foo\\\n bar'", StringLiteral.new(["foo\\\\n bar"] of Node | String, false)
  it_parses_single "\"foo\#{baz}bar\"", StringLiteral.new(["foo","baz".variable,"bar"] of Node | String, true)
  it_parses_single "\"foo\#{ \"baz\" }bar\"", StringLiteral.new(["foobazbar"] of Node | String, false)
  it_parses_single "'foo\#{ \"baz\" }bar'", StringLiteral.new(["foo\#{ \"baz\" }bar"] of Node | String, false)
  it_parses_single "\"\#{ 1 }\"", StringLiteral.new([1.int] of Node | String, true)
  it_parses_single "\"\#{ }\"", StringLiteral.new([""] of Node | String, false)
  it_parses_single "\"\"", StringLiteral.new([""] of Node | String, false)
  it_parses_single "call \"foo\#{bar do {}}baz\"", Call.new(nil, "call", [StringLiteral.new(["foo", Call.new(nil, "bar", block: Block.new, has_parenthesis: false), "baz"] of Node | String, true)] of Node, has_parenthesis: false)

  it_parses_single "//", regex("")
  it_parses_single "/ /", regex(" ")
  it_parses_single "/=/", regex("=")
  it_parses_single "/ foo /", regex(" foo ")
  it_parses_single "/foo/", regex("foo")
  it_parses_single "/foo/i", regex("foo", Regex::Options::IGNORE_CASE)
  it_parses_single "/foo/m", regex("foo", Regex::Options::MULTILINE)
  it_parses_single "/foo/x", regex("foo", Regex::Options::EXTENDED)
  it_parses_single "/foo/imximx", regex("foo", Regex::Options::IGNORE_CASE | Regex::Options::MULTILINE | Regex::Options::EXTENDED)
  it_parses_single "/fo\\so/", regex("fo\\so")
  it_parses_single "/fo\\/so/", regex("fo/so")
  it_parses_single "/fo\#{\"bar\"}o/", regex("fobaro")
  it_parses_single "/fo\#{ 1 }o/", RegexLiteral.new(StringLiteral.new(["fo", 1.int, "o"] of Node | String, true), Regex::Options::None)
  it_parses_single "a := //", Assign.new("a".variable, regex(""))
  it_parses_single2 "/ /; / /", [regex(" "), regex(" ")]
  it_parses_single "if / / then / / elsif / / then / / else / /", If.new(regex(" "), Body.new << regex(" "), Body.new << If.new(regex(" "), Body.new << regex(" "), Body.new << regex(" ")))
  it_parses_single "[/ /, / /]", ArrayLiteral.new([regex(" "), regex(" ")] of Node)
  it_parses_single "/ / / / /", Call.new(regex(" "), "/", [regex(" ")] of Node)

  it_parses_multiple ["1 + 2", "1 +\n2", "1 +2"], Call.new(1.int, "+", [2.int] of Node)
  it_parses_multiple ["1 -2", "1 - 2", "1 - \n2"], Call.new(1.int, "-", [2.int] of Node)
  it_parses_multiple2 ["1 +2.0", "1 -2.0"], [Call.new(1.int, "+", [2.0.float] of Node), Call.new(1.int, "-", [2.0.float] of Node)]
  it_parses_multiple3 ["1\n+2", "1;+2"], [1.int, Call.new(2.int, "+@")]
  it_parses_multiple3 ["1\n-2", "1;-2"], [1.int, Call.new(2.int, "-@")]
  it_parses_multiple ["1 * 2", "1 *\n2"], Call.new(1.int, "*", [2.int] of Node)
  it_parses_single "1 * -2", Call.new(1.int, "*", [-2.int] of Node)
  it_parses_single "1 * 2 + 3 * 4", Call.new(Call.new(1.int, "*", [2.int] of Node), "+", [Call.new(3.int, "*", [4.int] of Node)] of Node)
  it_parses_multiple2 ["1.* 2", "1 .* 2"], [Call.new(1.int, "*", [2.int] of Node), Call.new(1.int, ".*", [2.int] of Node)]
  it_parses_multiple ["1..*(2)", "1..* 2"], Call.new(1.int, ".*", [2.int] of Node)
  it_parses_multiple ["1 / 2", "1/2"], Call.new(1.int, "/", [2.int] of Node)
  it_parses_single "1 / -2", Call.new(1.int, "/", [-2.int] of Node)
  it_parses_single "1 / 2 + 3 / 4", Call.new(Call.new(1.int, "/", [2.int] of Node), "+", [Call.new(3.int, "/", [4.int] of Node)] of Node)
  it_parses_multiple ["1 \\ 2", "1\\2"], Call.new(1.int, "\\", [2.int] of Node)
  it_parses_single "1 / -2", Call.new(1.int, "/", [-2.int] of Node)
  it_parses_single "1 \\ 2 + 3 \\ 4", Call.new(Call.new(1.int, "\\", [2.int] of Node), "+", [Call.new(3.int, "\\", [4.int] of Node)] of Node)
  it_parses_single "1 ** 2", Call.new(1.int, "**", [2.int] of Node)
  it_parses_single "1 ** 2 ** 3", Call.new(1.int, "**", [Call.new(2.int, "**", [3.int] of Node)] of Node)
  it_parses_single "1 * 2 ** 3", Call.new(1.int, "*", [Call.new(2.int, "**", [3.int] of Node)] of Node)
  it_parses_single "1 + 2 ** 2 / 3", Call.new(1.int, "+", [Call.new(Call.new(2.int, "**", [2.int] of Node), "/", [3.int] of Node)] of Node)

  it_parses_single "a << 2", Call.new("a".variable, "<<", [2.int] of Node)
  it_parses_single "a >> 2", Call.new("a".variable, ">>", [2.int] of Node)

  it_parses_multiple ["!true", "! true"], Call.new(true.bool, "!")
  it_parses_single "!!a", Call.new(Call.new("a".variable, "!"), "!")
  it_parses_single "- 1", Call.new(1.int, "-@")
  it_parses_single "+ 1", Call.new(1.int, "+@")
  it_parses_single "!x", Call.new("x".variable, "!")
  it_parses_single "1 && 2", And.new(1.int, 2.int)
  it_parses_single "1 || 2", Or.new(1.int, 2.int)
  it_parses_single "a || b && c", Or.new("a".variable, And.new("b".variable, "c".variable))
  it_parses_single "a && b || c", Or.new(And.new("a".variable, "b".variable), "c".variable)
  it_parses_single "a + b || c", Or.new(Call.new("a".variable, "+", ["b".variable] of Node), "c".variable)
  it_parses_single "a || !b", Or.new("a".variable, Call.new("b".variable, "!"))

  it_parses_multiple ["class A {}", "class A; {}", "class A \n {}", "class A\n{\n\n}"],
    ClassNode.new(Namespace.new(["A"]), Noop.new, Body.new, symtab(SymType::CLASS))
  it_parses_single "class A::B {}", ClassNode.new(Namespace.new(["A", "B"]), Noop.new, Body.new, symtab(SymType::CLASS))
  it_parses_single "class ::A::B {}", ClassNode.new(Namespace.new(["A", "B"], true), Noop.new, Body.new, symtab(SymType::CLASS))
  it_parses_single "class A inherits B {}", ClassNode.new(Namespace.new(["A"]), Namespace.new(["B"]), Body.new, symtab(SymType::CLASS))
  it_parses_single "class A inherits B::C {}", ClassNode.new(Namespace.new(["A"]), Namespace.new(["B", "C"]), Body.new, symtab(SymType::CLASS))
  it_parses_multiple ["module A {}", "module A; {}", "module A\n{}", "module A\n{\n\n}"], ModuleNode.new(Namespace.new(["A"]), Body.new, symtab(SymType::CLASS))
  it_parses_multiple ["class A {}.any_method", "class A {}.any_method()", "class A {}.any_method(\n)"], Call.new(ClassNode.new(Namespace.new(["A"]), Noop.new, Body.new, symtab(SymType::CLASS)), "any_method")

  it_parses_single "true if false", If.new(FalseLiteral.new, Body.new << TrueLiteral.new)
  it_parses_single "a while b", While.new("b".variable, Body.new << "a".variable)
  it_parses_single "a until b", Until.new("b".variable, Body.new << "a".variable)

  it_parses_multiple ["foo(1,2)", "foo 1, 2"], Call.new(nil, "foo", [1.int, 2.int] of Node)
  it_parses_single "foo bar", Call.new(nil, "foo", ["bar".variable] of Node)
  it_parses_multiple ["foo[1,2]", "foo.[](1,2)", "foo.[] 1, 2", "foo[1,\n2]", "foo.[](1,\n2)", "foo.[] 1,\n2"],
    Call.new("foo".variable, "[]", [1.int, 2.int] of Node)
  it_parses_multiple ["foo[1] := 2", "foo.[]= 1, 2", "foo.[]=(1, 2)"], Call.new("foo".variable, "[]=", [1.int, 2.int] of Node)
  it_parses_single "foo[]", Call.new("foo".variable, "[]")
  it_parses_multiple ["foo[1,2][3]", "foo.[](1,2)[3]", "foo.[](1,2).[](3)"], Call.new(Call.new("foo".variable, "[]", [1.int, 2.int] of Node), "[]", [3.int] of Node)
  it_parses_multiple ["foo {}", "foo do {}"], Call.new(nil, "foo", block: Block.new(nil, Body.new, symtab(SymType::BLOCK)))
  it_parses_multiple ["foo(1, a: 10, &block)", "foo 1, a: 10, &block"], Call.new(nil, "foo", [1.int] of Node, [NamedArg.new("a", 10.int)], "block".variable)
  it_parses_multiple ["foo a: 10, b: 9", "foo(a: 10, b: 9)"], Call.new(nil, "foo", named_args: [NamedArg.new("a", 10.int), NamedArg.new("b", 9.int)])
  it_parses_single "foo -2", Call.new("foo".variable, "-", [2.int] of Node)
  it_parses_single "foo +2", Call.new("foo".variable, "+", [2.int] of Node)
  it_parses_single "foo +b", Call.new("foo".variable, "+", ["b".variable] of Node)
  it_parses_single "foo -b", Call.new("foo".variable, "-", ["b".variable] of Node)
  it_parses_single "foo !b", Call.new(nil, "foo", [Call.new("b".variable, "!")] of Node)
  it_parses_single "foo a do {}", Call.new(nil, "foo", ["a".variable] of Node, block: Block.new(nil, Body.new, symtab(SymType::BLOCK)))
  it_parses_single "foo a {} do {}", Call.new(nil, "foo", [Call.new(nil, "a", block: Block.new(nil, Body.new, symtab(SymType::BLOCK)))] of Node, block: Block.new(nil, Body.new, symtab(SymType::BLOCK)))
  it_parses_single "foo bar baz", Call.new(nil, "foo", [Call.new(nil, "bar", ["baz".variable] of Node)] of Node)
  it_parses_single "foo\n.bar\n.baz", Call.new(Call.new("foo".variable, "bar"), "baz")
  it_parses_single "foo?", Call.new(nil, "foo?", has_parenthesis: false)
  it_parses_single "foo!", Call.new(nil, "foo!", has_parenthesis: false)

  it_parses_multiple ["foo(&:to_s)", "foo &:to_s"], Call.new(nil, "foo", block: Block.new(Params.new([Arg.new("__temp1", nil)]), Body.new << Call.new("__temp1".variable, "to_s"), symtab(SymType::BLOCK) << "__temp1"))
  it_parses_multiple ["foo(&block)", "foo &block"], Call.new(nil, "foo", block_param: "block".variable)
  it_parses_multiple ["foo(1, *splat, **dblsplat, a: 10, &block)", "foo 1, *splat, **dblsplat, a: 10, &block"], Call.new(nil, "foo", [1.int, Splat.new("splat".variable), DoubleSplat.new("dblsplat".variable)] of Node, [NamedArg.new("a", 10.int)], "block".variable)
  assert_syntax_error "foo **splat, 12", "Argument not allowed after double splat"
  assert_syntax_error "foo **splat, *other", "Splat not allowed after double splat"

  it_parses_single "a := 12", Assign.new("a".variable, 12.int)
  it_parses_single "a := b := 1", Assign.new("a".variable, Assign.new("b".variable, 1.int))
  it_parses_single "a += b", OpAssign.new("a".variable, "+", "b".variable)
  it_parses_single "a -= b", OpAssign.new("a".variable, "-", "b".variable)
  it_parses_single "a *= b", OpAssign.new("a".variable, "*", "b".variable)
  it_parses_single "a .*= b", OpAssign.new("a".variable, ".*", "b".variable)
  it_parses_single "a /= b", OpAssign.new("a".variable, "/", "b".variable)
  it_parses_single "a \\= b", OpAssign.new("a".variable, "\\", "b".variable)
  it_parses_single "a **= b", OpAssign.new("a".variable, "**", "b".variable)
  it_parses_single "a ^= b", OpAssign.new("a".variable, "^", "b".variable)
  it_parses_single "a |= b", OpAssign.new("a".variable, "|", "b".variable)
  it_parses_single "a &= b", OpAssign.new("a".variable, "&", "b".variable)
  it_parses_single "a ||= b", OpAssign.new("a".variable, "||", "b".variable)
  it_parses_single "a &&= b", OpAssign.new("a".variable, "&&", "b".variable)
  it_parses_single "a := b |= c", Assign.new("a".variable, OpAssign.new("b".variable, "|", "c".variable))
  it_parses_single "a := b += c := 10", Assign.new("a".variable, OpAssign.new("b".variable, "+", Assign.new("c".variable, 10.int)))

  it_parses_single "const A := 10", ConstDef.new("A", 10.int)
  it_parses_single "const A := b + 2", ConstDef.new("A", Call.new("b".variable, "+", [2.int] of Node))

  it_parses_multiple ["if a then 1 else 2", "if a then\n 1 else\n 2", "if a\n 1\n else\n 2"], If.new("a".variable, 1.int, 2.int)
  it_parses_multiple ["if a then { 1 } else { 2 }",
                      "if a then {\n 1 } else {\n 2 }",
                      "if a\n {\n 1 }\n else {\n 2 }",
                      "if a then \n\n{\n\n 1 \n}\n\n else \n\n{\n 2 \n}"], If.new("a".variable, Body.new << 1.int, Body.new << 2.int)
  it_parses_multiple ["if a then 2", "if a then\n 2", "if a\n2", "if a\n2\n\n"], If.new("a".variable, 2.int)
  it_parses_multiple ["if true {1\n2\n3}", "if true {1;2;3}"], If.new(true.bool, Body.new << 1.int << 2.int << 3.int)
  it_parses_single "if foo 1 then {}", If.new(Call.new(nil, "foo", [1.int] of Node), Body.new)
  it_parses_single "if foo 1, 2 then {}", If.new(Call.new(nil, "foo", [1.int, 2.int] of Node), Body.new)
  it_parses_multiple ["if a then b elsif c then d", "if a\n b\n elsif c\n d"], If.new("a".variable, "b".variable, If.new("c".variable, "d".variable))

  it_parses_multiple ["while a\n 1", "do while a\n 1"], While.new("a".variable, 1.int)
  it_parses_multiple ["while a \n{ 1 }", "do while a \n{ 1 }"], While.new("a".variable, Body.new << 1.int)
  it_parses_single "while i += 1\n 10", While.new(OpAssign.new("i".variable, "+", 1.int), 10.int)
  it_parses_single "while i += 1 { 10 }", While.new(OpAssign.new("i".variable, "+", 1.int), Body.new << 10.int)

  it_parses_multiple ["do { a } until b", "do\n{\na\n}\nuntil\nb"], Until.new("b".variable, "a".variable)

  it_parses_single "let func() {}", FunctionNode.new(FuncVisib::PUBLIC, nil, "func", Params.new([] of Arg), Body.new, symtab(SymType::METHOD))
  it_parses_single "let func() { 1 }", FunctionNode.new(FuncVisib::PUBLIC, nil, "func", Params.new([] of Arg), Body.new << "1".int, symtab(SymType::METHOD))
  it_parses_multiple ["public let func {}", "public\nlet func {}", "public\nlet\nfunc\n{}", "let func {}", "let func\n {}", "let func\n{\n}"], FunctionNode.new(FuncVisib::PUBLIC, nil, "func", nil, Body.new, symtab(SymType::METHOD))
  it_parses_multiple ["protected let func {}", "protected\nlet func\n {}", "protected\nlet\nfunc\n{\n}"], FunctionNode.new(FuncVisib::PROTECTED, nil, "func", nil, Body.new, symtab(SymType::METHOD))
  it_parses_multiple ["private let func {}", "private\nlet func\n {}", "private\nlet\nfunc\n{\n}"], FunctionNode.new(FuncVisib::PRIVATE, nil, "func", nil, Body.new, symtab(SymType::METHOD))
  it_parses_multiple ["let func a, b {}",
                      "let func a, \nb {}", 
                      "let func a, b \n {}",
                      "let func a,\nb \n {}", 
                      "let func a, b\n{\n}", 
                      "let func(a, b) {}",
                      "let func(a, b)\n{}",
                      "let func(a, \nb) {}",
                      "let func(\na, \nb) {}",
                      "let func(\na, \nb\n) {}"], FunctionNode.new(FuncVisib::PUBLIC, nil, "func", Params.new(["a".arg, "b".arg]), Body.new, symtab(SymType::METHOD) << "a" << "b")
  it_parses_multiple ["let func a, b:=1 {}",
                      "let func(a, b:=1) {}",
                      "let func a, \nb:=\n1 {}",
                      "let func(a, \nb:=\n1) {}"], FunctionNode.new(FuncVisib::PUBLIC, nil, "func", Params.new(["a".arg, "b".arg("1".int)], 1), Body.new, symtab(SymType::METHOD) << "a" << "b")
  it_parses_multiple ["let func a, b:=1, *splat {}",
                      "let func(a, b:=1, *splat) {}",
                      "let func(a, \nb:=\n1, \n*splat) {}"], FunctionNode.new(FuncVisib::PUBLIC, nil, "func", Params.new(["a".arg, "b".arg("1".int), "splat".arg], 1, 2), Body.new, symtab(SymType::METHOD) << "a" << "b" << "splat")
  it_parses_multiple ["let func a, b:=1, *splat, k: 2 {}",
                      "let func a, b:=1, *splat, k: \n2 {}",
                      "let func(a, b:=1, *splat, k: 2) {}",
                      "let func(a, b:=1, *splat, k: \n2) {}"], FunctionNode.new(FuncVisib::PUBLIC, nil, "func", Params.new(["a".arg, "b".arg("1".int), "splat".arg, "k".arg("2".int)], 1, 2, 1), Body.new, symtab(SymType::METHOD) << "a" << "b" << "splat" << "k")
  it_parses_multiple ["let func a, b:=1, *splat, k: 2, **dblsplat {}",
                      "let func a, b:=1, *splat, k: 2, \n **dblsplat {}",
                      "let func(a, b:=1, *splat, k: 2, **dblsplat) {}",
                      "let func(a, b:=1, *splat, k: 2, \n **dblsplat) {}"], FunctionNode.new(FuncVisib::PUBLIC, nil, "func", Params.new(["a".arg, "b".arg("1".int), "splat".arg, "k".arg("2".int), "dblsplat".arg], 1, 2, 1, 4), Body.new, symtab(SymType::METHOD) << "a" << "b" << "splat" << "k" << "dblsplat")
  it_parses_multiple ["let func a, b:=1, *splat, k: 2, **dblsplat, &block {}",
                      "let func a, b:=1, *splat, k: 2, **dblsplat, \n &block {}",
                      "let func(a, b:=1, *splat, k: 2, **dblsplat, &block) {}",
                      "let func(a, b:=1, *splat, k: 2, **dblsplat, \n&block) {}"], FunctionNode.new(FuncVisib::PUBLIC, nil, "func", Params.new(["a".arg, "b".arg("1".int), "splat".arg, "k".arg("2".int), "dblsplat".arg, "block".arg], 1, 2, 1, 4, true), Body.new, symtab(SymType::METHOD) << "a" << "b" << "splat" << "k" << "dblsplat" << "block")
  it_parses_multiple ["let func a := 1 {}", "let func(a:=1) {}"], FunctionNode.new(FuncVisib::PUBLIC, nil, "func", Params.new(["a".arg("1".int)], 1), Body.new, symtab(SymType::METHOD) << "a")
  it_parses_multiple ["let func k: 1 {}","let func(k: 1) {}"], FunctionNode.new(FuncVisib::PUBLIC, nil, "func", Params.new(["k".arg("1".int)], kwargc: 1), Body.new, symtab(SymType::METHOD) << "k")
  it_parses_multiple ["let func *splat {}","let func(*splat) {}"], FunctionNode.new(FuncVisib::PUBLIC, nil, "func", Params.new(["splat".arg], splat_index: 0), Body.new, symtab(SymType::METHOD) << "splat")
  it_parses_multiple ["let func **splat {}","let func(**splat) {}"], FunctionNode.new(FuncVisib::PUBLIC, nil, "func", Params.new(["splat".arg], double_splat_index: 0), Body.new, symtab(SymType::METHOD) << "splat")
  it_parses_multiple ["let func &block {}","let func(&block) {}"], FunctionNode.new(FuncVisib::PUBLIC, nil, "func", Params.new(["block".arg], blockarg: true), Body.new, symtab(SymType::METHOD) << "block")
  it_parses_multiple ["let func a, &block {}","let func(a, &block) {}"], FunctionNode.new(FuncVisib::PUBLIC, nil, "func", Params.new(["a".arg, "block".arg], blockarg: true), Body.new, symtab(SymType::METHOD) << "a" << "block")

  it_parses_multiple ["let self.func {}", "let\nself.func\n {}"], FunctionNode.new(FuncVisib::PUBLIC, "self".variable, "func", nil, Body.new, symtab(SymType::METHOD))
  it_parses_single "let x.func {}", FunctionNode.new(FuncVisib::PUBLIC, "x".variable, "func", nil, Body.new, symtab(SymType::METHOD))
  it_parses_single "let self.func= {}", FunctionNode.new(FuncVisib::PUBLIC, "self".variable, "func=", nil, Body.new, symtab(SymType::METHOD))
  it_parses_single "let self.func=() {}", FunctionNode.new(FuncVisib::PUBLIC, "self".variable, "func=", Params.new([] of Arg), Body.new, symtab(SymType::METHOD))
  it_parses_single "let self.func? {}", FunctionNode.new(FuncVisib::PUBLIC, "self".variable, "func?", nil, Body.new, symtab(SymType::METHOD))
  it_parses_single "let self.func?() {}", FunctionNode.new(FuncVisib::PUBLIC, "self".variable, "func?", Params.new([] of Arg), Body.new, symtab(SymType::METHOD))

  it_parses_single "let A::B.func?() {}", FunctionNode.new(FuncVisib::PUBLIC, Namespace.new(["A", "B"]), "func?", Params.new([] of Arg), Body.new, symtab(SymType::METHOD))
  it_parses_single "let func? {}", FunctionNode.new(FuncVisib::PUBLIC, nil, "func?", nil, Body.new, symtab(SymType::METHOD))
  it_parses_single "let func! {}", FunctionNode.new(FuncVisib::PUBLIC, nil, "func!", nil, Body.new, symtab(SymType::METHOD))
  {"+@", "-@", "+", "-", "*", ".*", "**", "/", "\\", "|", "||", "&", "&&", "^", ">", ">=", "<", "<=", "=", "==", "===", "<<", ">>", "%", "!", "[]", "[]="
  }.each do |name|
    it_parses_multiple ["let #{name} {}", "let #{name}\n{}"], FunctionNode.new(FuncVisib::PUBLIC, nil, name, nil, Body.new, symtab(SymType::METHOD))
    it_parses_single "let #{name}() {}", FunctionNode.new(FuncVisib::PUBLIC, nil, name, Params.new([] of Arg), Body.new, symtab(SymType::METHOD))
    it_parses_single "let self.#{name} {}", FunctionNode.new(FuncVisib::PUBLIC, "self".variable , name, nil, Body.new, symtab(SymType::METHOD))
    assert_syntax_error "let #{name}.wrong {}", "Unexpected token '.'"
  end 
  
  it_parses_multiple ["let foo{\nyield\n}", "let foo{\nyield()\n}"], FunctionNode.new(FuncVisib::PUBLIC, nil, "foo", nil, Body.new << Yield.new, symtab(SymType::METHOD))
  it_parses_multiple ["let foo{\nyield 1, b: 2\n}", "let foo{\nyield(1, b: 2)\n}"], FunctionNode.new(FuncVisib::PUBLIC, nil, "foo", nil, Body.new << Yield.new([1.int], [NamedArg.new("b", 2.int)]), symtab(SymType::METHOD))


  assert_syntax_error "let func *splat, *splat2 {}", "Splat or double splat already defined"
  assert_syntax_error "let func **splat, *splat2 {}", "Splat or double splat already defined"
  assert_syntax_error "let func **splat, **splat2 {}", "Double splat already defined"
  assert_syntax_error "let func *splat, a {}", "Unexpected local variable a"
  assert_syntax_error "let func a := 0, b {}", "Unexpected local variable b"
  assert_syntax_error "let func a: 0, b {}", "Unexpected local variable b"
  assert_syntax_error "let func **splat, b: 1 {}", "Unexpected token ':'"
  assert_syntax_error "let func **splat, b := 1 {}", "Unexpected token ':='"
  assert_syntax_error "let func=.wrong {}", "Unexpected token '.'"
  assert_syntax_error "yield", "Invalid yield"
  assert_syntax_error "let foo {yield &block}", "Block argument should not be given"
  assert_syntax_error "let foo {yield &:to_s}", "Block argument should not be given"

  it_parses_single "[]", ArrayLiteral.new([] of Node)
  it_parses_single "[1, 2, 3]", ArrayLiteral.new([1.int, 2.int, 3.int] of Node)
  it_parses_single "[1, :b]", ArrayLiteral.new([1.int, ":b".symbol] of Node)
  it_parses_single "A::B::C", Namespace.new(["A", "B", "C"])
  it_parses_single "::A::B::C", Namespace.new(["A", "B", "C"], true)
  it_parses_single "::A", Namespace.new(["A"], true)

  it_parses_multiple ["try {} catch {}", "try {\n} catch {\n}", "try\n{\n}\ncatch\n{\n}"], Try.new(Body.new, [CatchExp.new(nil, nil, Body.new)], symtab(SymType::BLOCK) << "!@e")
  it_parses_multiple ["try v0 catch\n v1", "try { v0 } catch {v1}", "try\nv0\ncatch\nv1"], Try.new(Body.new << "v0".variable, [CatchExp.new(nil, nil, Body.new << "v1".variable)], symtab(SymType::BLOCK) << "!@e")
  it_parses_single "try {} catch => e \n {}", Try.new(Body.new, [CatchExp.new(nil, "e", Body.new)], symtab(SymType::BLOCK) << "!@e" << "e")
  it_parses_single "try {} catch SyntaxError => e \n {}", Try.new(Body.new, [CatchExp.new("SyntaxError".variable, "e", Body.new)], symtab(SymType::BLOCK) << "!@e" << "e")
  it_parses_single "try {} catch SyntaxError => e \n {}\n catch {}", Try.new(Body.new, [CatchExp.new("SyntaxError".variable, "e", Body.new), CatchExp.new(nil, nil , Body.new)], symtab(SymType::BLOCK) << "!@e" << "e")
  
  assert_syntax_error "try {} catch {} catch SyntaxError => e \n {}", "Specific exception handling must be specified before catch-all statement"
  assert_syntax_error "try {} catch {} catch => e \n {}", "Catch all statement already specified"

  it_parses_single "new Array()", NewObject.new(Namespace.new(["Array"]), nil, nil, nil, nil)
  it_parses_single "new Array(1, 2)", NewObject.new(Namespace.new(["Array"]), [1.int, 2.int] of Node, nil, nil, nil)
  it_parses_single "new Array(1, a: 2)", NewObject.new(Namespace.new(["Array"]), [1.int] of Node, [NamedArg.new("a", 2.int)], nil, nil)
  it_parses_single "new Array &block", NewObject.new(Namespace.new(["Array"]), nil, nil, "block".variable, nil)
  it_parses_single "new Array {}", NewObject.new(Namespace.new(["Array"]), nil, nil, nil, Block.new(nil, Body.new, symtab(SymType::BLOCK)))
end
