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

describe Parser do 
  #it "Parses an empty program" do 
  #  parser = Parser.new(__FILE__, "")
  #  prog   = parser.parse 
  #  prog.class.should eq(Program)
  #  prog.filename.should eq(__FILE__)
  #  prog.body.class.should eq(Body)
  #end

  it_parses_multiple ["class A {}", "class A; {}", "class A \n {}", "class A\n{\n\n}"],
                       ClassNode.new(Namespace.new(["A"]), Noop.new, Body.new, SymTable.new)
  it_parses_single "class A::B {}", ClassNode.new(Namespace.new(["A", "B"]), Noop.new, Body.new, SymTable.new)
  it_parses_single "class ::A::B {}", ClassNode.new(Namespace.new(["A", "B"], true), Noop.new, Body.new, SymTable.new)
  it_parses_single "class A inherits B {}", ClassNode.new(Namespace.new(["A"]), Namespace.new(["B"]), Body.new, SymTable.new)
  it_parses_single "class A inherits B::C {}", ClassNode.new(Namespace.new(["A"]), Namespace.new(["B", "C"]), Body.new, SymTable.new)
  it_parses_multiple ["module A {}", "module A; {}", "module A\n{}", "module A\n{\n\n}" ], ModuleNode.new(Namespace.new(["A"]), Body.new, SymTable.new)
end