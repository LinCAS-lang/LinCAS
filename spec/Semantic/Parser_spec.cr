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

def it_parses_single2(string, expected_nodes : Array(Node))
  it "Parses #{string.inspect}" do
    parser = Parser.new(__FILE__, string)
    nodes   = parser.parse.body.nodes
    nodes.should eq(expected_nodes)
  end
end

def it_parses_single(string, expected_node)
  it "Parses #{string.inspect}" do
    parser = Parser.new(__FILE__, string)
    node   = parser.parse.body.nodes.first
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

describe Parser do 
  it "Parses an empty program" do 
    parser = Parser.new(__FILE__, "")
    prog   = parser.parse 
    prog.class.should eq(Program)
    prog.filename.should eq(__FILE__)
    prog.body.class.should eq(Body)
  end 

  it_parses_single "123", "123".int
  it_parses_single "1.3","1.3".float
  it_parses_single "12i", "12i".complex
  it_parses_single "true", true.bool 
  it_parses_single "false", false.bool
  it_parses_single "foo", "foo".variable
  it_parses_single "Foo", "Foo".variable
  it_parses_single "self", Self.new 

  [":foo", ":foo!", ":foo?", ":かたな", ":+", ":-", ":*", ":/", ":==", ":<", ":<=", ":>",
    ":>=", ":!",  ":&", ":|", ":^",  ":**", ":>>", ":<<", ":%", ":[]", ":[]=",
    # ":~", ":!=", ":=~", ":!~", ":<=>", ":==="
  ].each do |symbol|
    it_parses_single symbol, symbol.symbol
  end

  it_parses_multiple ["1 + 2", "1 +\n2", "1 +2"],  Call.new(1.int, "+", [2.int] of Node)
  it_parses_multiple ["1 -2", "1 - 2", "1 - \n2"], Call.new(1.int, "-", [2.int] of Node)
  it_parses_multiple2 ["1 +2.0", "1 -2.0"], [Call.new(1.int, "+", [2.0.float] of Node), Call.new(1.int, "-", [2.0.float] of Node)]
  it_parses_multiple3 ["1\n+2", "1;+2"], [1.int, Call.new(2.int, "+@")] 
  it_parses_multiple3 ["1\n-2", "1;-2"], [1.int, Call.new(2.int, "-@")] 
  it_parses_multiple ["1 * 2", "1 *\n2"], Call.new(1.int, "*", [2.int] of Node)
  it_parses_single "1 * -2", Call.new(1.int, "*", [-2.int] of Node)
  it_parses_single "1 * 2 + 3 * 4", Call.new(Call.new(1.int, "*", [2.int] of Node), "+", [Call.new(3.int, "*", [4.int] of Node)] of Node)
  it_parses_multiple2 ["1.* 2", "1 .* 2"], [Call.new(1.int, "*", [2.int] of Node), Call.new(1.int, ".*", [2.int] of Node)]
  it_parses_multiple ["1..*(2)", "1..* 2"], Call.new(1.int, ".*", [2.int] of Node)
  it_parses_multiple ["1 / 2", "1/2"],  Call.new(1.int, "/", [2.int] of Node)
  it_parses_single "1 / -2", Call.new(1.int, "/", [-2.int] of Node)
  it_parses_single "1 / 2 + 3 / 4", Call.new(Call.new(1.int, "/", [2.int] of Node), "+", [Call.new(3.int, "/", [4.int] of Node)] of Node)
  it_parses_multiple ["1 \\ 2", "1\\2"],  Call.new(1.int, "\\", [2.int] of Node)
  it_parses_single "1 / -2", Call.new(1.int, "/", [-2.int] of Node)
  it_parses_single "1 \\ 2 + 3 \\ 4", Call.new(Call.new(1.int, "\\", [2.int] of Node), "+", [Call.new(3.int, "\\", [4.int] of Node)] of Node)
  it_parses_single "1 ** 2", Call.new(1.int, "**", [2.int] of Node)
  it_parses_single "1 ** 2 ** 3", Call.new(1.int, "**", [Call.new(2.int, "**", [3.int] of Node)] of Node)
  it_parses_single "1 * 2 ** 3", Call.new(1.int, "*", [Call.new(2.int, "**", [3.int] of Node)] of Node)
  it_parses_single "1 + 2 ** 2 / 3", Call.new(1.int, "+", [Call.new(Call.new(2.int, "**", [2.int] of Node), "/", [3.int] of Node)] of Node)
  
  it_parses_multiple ["!true", "! true"], Call.new(true.bool, "!")
  it_parses_single "- 1", Call.new(1.int, "-@")
  it_parses_single "+ 1", Call.new(1.int, "+@")
  it_parses_single "!x", Call.new("x".variable, "!")
  it_parses_single "1 && 2", And.new(1.int, 2.int)
  it_parses_single "1 || 2", Or.new(1.int, 2.int)
  it_parses_single "a || b && c", Or.new("a".variable, And.new("b".variable, "c".variable))
  it_parses_single "a && b || c", Or.new(And.new("a".variable, "b".variable), "c".variable,)
  it_parses_single "a + b || c", Or.new(Call.new("a".variable, "+", ["b".variable] of Node), "c".variable)
  it_parses_single "a || !b", Or.new("a".variable, Call.new("b".variable, "!"))

  
  it_parses_multiple ["class A {}", "class A; {}", "class A \n {}", "class A\n{\n\n}"],
                       ClassNode.new(Namespace.new(["A"]), Noop.new, Body.new, SymTable.new)
  it_parses_single "class A::B {}", ClassNode.new(Namespace.new(["A", "B"]), Noop.new, Body.new, SymTable.new)
  it_parses_single "class ::A::B {}", ClassNode.new(Namespace.new(["A", "B"], true), Noop.new, Body.new, SymTable.new)
  it_parses_single "class A inherits B {}", ClassNode.new(Namespace.new(["A"]), Namespace.new(["B"]), Body.new, SymTable.new)
  it_parses_single "class A inherits B::C {}", ClassNode.new(Namespace.new(["A"]), Namespace.new(["B", "C"]), Body.new, SymTable.new)
  it_parses_multiple ["module A {}", "module A; {}", "module A\n{}", "module A\n{\n\n}" ], ModuleNode.new(Namespace.new(["A"]), Body.new, SymTable.new)
  it_parses_multiple ["class A {}.any_method", "class A {}.any_method()", "class A {}.any_method(\n)"], Call.new(ClassNode.new(Namespace.new(["A"]), Noop.new, Body.new, SymTable.new), "any_method")
  it_parses_single "true if false", If.new(FalseLiteral.new, Body.new << TrueLiteral.new)

  it_parses_multiple ["foo(1,2)", "foo 1, 2"], Call.new(nil, "foo", [1.int, 2.int] of Node)
  it_parses_single "foo bar", Call.new(nil, "foo", ["bar".variable] of Node)
  it_parses_multiple ["foo[1,2]","foo.[](1,2)", "foo.[] 1, 2", "foo[1,\n2]", "foo.[](1,\n2)", "foo.[] 1,\n2"], 
                         Call.new("foo".variable, "[]", [1.int, 2.int] of Node)
  it_parses_single "foo[]", Call.new("foo".variable, "[]")
  it_parses_multiple ["foo[1,2][3]", "foo.[](1,2)[3]", "foo.[](1,2).[](3)"], Call.new(Call.new("foo".variable, "[]", [1.int, 2.int] of Node), "[]", [3.int] of Node)
  it_parses_multiple ["foo {}", "foo do {}"], Call.new(nil, "foo", block: Block.new(nil, -1, Body.new, SymTable.new))
  it_parses_multiple ["foo(1, a: 10, &block)", "foo 1, a: 10, &block"], Call.new(nil, "foo", [1.int] of Node, [NamedArg.new("a", 10.int)], "block".variable)
  it_parses_multiple ["foo a: 10, b: 9", "foo(a: 10, b: 9)"], Call.new(nil, "foo", named_args: [NamedArg.new("a", 10.int), NamedArg.new("b", 9.int)])
  it_parses_single "foo -2", Call.new("foo".variable, "-", [2.int] of Node)
  it_parses_single "foo +2", Call.new("foo".variable, "+", [2.int] of Node)
  it_parses_single "foo +b", Call.new("foo".variable, "+", ["b".variable] of Node)
  it_parses_single "foo -b", Call.new("foo".variable, "-", ["b".variable] of Node)
  it_parses_single "foo !b", Call.new(nil, "foo", [Call.new("b".variable, "!")] of Node)
  it_parses_single "foo a do {}", Call.new(nil, "foo", ["a".variable] of Node, block: Block.new(nil, -1, Body.new, SymTable.new))
  it_parses_single "foo a {} do {}",  Call.new(nil, "foo", [Call.new(nil, "a", block: Block.new(nil, -1, Body.new, SymTable.new))] of Node, block: Block.new(nil, -1, Body.new, SymTable.new))
  it_parses_single "foo bar baz", Call.new(nil, "foo", [Call.new(nil, "bar", ["baz".variable] of Node)] of Node)
  it_parses_single "foo\n.bar\n.baz", Call.new(Call.new("foo".variable, "bar"), "baz")
  
  it_parses_multiple ["foo(&:to_s)","foo &:to_s"], Call.new(nil, "foo", block_param: Block.new(["__temp1".variable] of Node, -1, Body.new << Call.new("__temp1".variable, "to_s"), SymTable.new))
  it_parses_multiple ["foo(&block)", "foo &block"], Call.new(nil, "foo",  block_param: "block".variable)

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
  it_parses_single "a := b|= c", Assign.new("a".variable, OpAssign.new("b".variable, "|", "b".variable))
  it_parses_single "const A := 10", ConstDef.new("A", 10.int)
  it_parses_single "const A := b + 2", ConstDef.new("A", Call.new("b".variable, "+", [2.int] of Node))

end