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

class String
  def call 
    return Call.new(Noop.new, self)
  end 

  def int 
    NumberLiteral.new(self, :INT)
  end 

  def float 
    NumberLiteral.new(self, :FLOAT)
  end 

  def complex 
    NumberLiteral.new(self, :COMPLEX)
  end

  def variable 
    Variable.new(self, ID::UNKNOWN, self[0].ascii_uppercase?)
  end

  def symbol 
    SymbolLiteral.new(self.lstrip(":"))
  end
end

struct Bool
  def bool 
    self ? TrueLiteral.new : FalseLiteral.new 
  end 
end

struct Int 
  def int 
    integer = self.abs.to_s.int 
    self < 0 ? Call.new(integer, "-@") : integer
  end 
end

struct Float 
  def float 
    self.to_s.float 
  end 
end