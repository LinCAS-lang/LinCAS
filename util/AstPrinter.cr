
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