
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

class AstPrinter

    Width = 80

    def initialize(initialIndent = 0)
        @length      = 0
        @indentation = (" " * initialIndent).as(String)
        @indent      = "    "
        @line        = ""
    end

    def printAst(ast : Node)
        puts "********** ICODE **********" 
        nodes = ast.getBranches
        nodes.map do |node|
            printNode(node) unless node.type == NodeType::PROGRAM
            printAst(node) if node.type == NodeType::PROGRAM
        end
        printL
    end

    private def printNode(node)
        append(@indentation)
        append("<" + node.to_s)
        
        printAttrs(node)
        
        branches = node.getBranches
        if branches.size > 0
        
            append ">"
            printL
            printBranches(branches)
            append(@indentation)
            append("</" + node.to_s + ">")
          
        else
        
            append(" ")
            append("/>")
          
        end
        printL
    end
      
    private def printAttrs(node) : ::Nil
        oldIndent = @indentation
        @indentation += @indent
        node.getAttrs.keys.each { |_attr| printAttr(_attr,node.getAttr(_attr))}
        @indentation = oldIndent
    end

    private def printAttr(key,value) : ::Nil
        if value.is_a? Node
            append(">")
            printL
            oldIndent = @indentation
            #@indentation += @indent
            append("#{@indentation}<ATTR: #{key}>")
            printL
            @indentation += @indent
            printNode(value)
            @indentation = oldIndent# + @indent
            append("#{@indentation}</ATTR: #{key}>")
            #@indentation = oldIndent
            printL
        else
            other = "#{key.to_s}= \"#{value}\""
            append(" ")
            append(other)
        end
    end

    private def printBranches(branches) : ::Nil
        oldIndent = @indentation
        @indentation += @indent

        branches.each do |branch|
            printNode(branch)
        end
        @indentation = oldIndent
    end

    private def append(text : String) : ::Nil
        textSize = text ? text.size : 0
        lBreak = false

        if @length + textSize > Width
            printL
            @line  += @indentation
            @length = @indentation.size
            lBreak  = true
        end

        if !(lBreak && (text == " "))
            @line   += text ? text : ""
            @length += textSize
        end
    end

    private def printL : ::Nil
        if @length > 0
            puts @line
            @line   = ""
            @length = 0
        end
    end

end