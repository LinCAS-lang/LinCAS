
# Copyright (c) 2017 Massimiliano Dal Mas
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

class SymTabPrinter

    Width = 80

    def initialize
        @indent   = ""
        @toIndent = "    "
        @line     = ""
        @length   = 0
    end

    def printSTab(symtab)
        printEntry(symtab)
        printL
    end 

    protected def printEntry(entry)
        if entry.is_a? ClassEntry
            printClass(entry)
        elsif entry.is_a? ModuleEntry
            printModule(entry)
        elsif entry.is_a? ConstEntry
            printConst(entry)
        elsif entry.is_a? SymTab
            printSymTab(entry)
        end
    end

    protected def printClass(entry)
        header = "#{@indent}<Class: #{entry.name}"
        append(header + ">\n")
        indent = @indent
        @indent += @toIndent
        parent = entry.as(ClassEntry).parent
        append("#{@indent}<PARENT: #{parent.as(ClassEntry).name}/>") if parent
        printL
        printIncluded(entry.included)
        printMethods(entry.methods)
        printSymTab(entry.symTab)
        @indent = indent
        append(header + "/>\n")
        printL
    end

    protected def printModule(entry)
        header = "#{@indent}<Module: #{entry.name}"
        append(header + ">\n")
        printL
        indent = @indent
        @indent += @toIndent
        printIncluded(entry.included)
        printMethods(entry.methods)
        printSymTab(entry.symTab)
        @indent = indent
        append(header + "/>\n")
        printL
    end

    protected def printConst(entry)
        append("#{@indent}<CONST: #{entry.name}/>")
        printL
    end

    protected def printMethods(symtab)
        symtab.each_key do |method|
            printMethod(symtab[method])
        end
    end

    protected def printMethod(method)
        method = method.as(MethodEntry)
        append("#{@indent}<METHOD: '#{method.name}'>\n")
        indent = @indent
        @indent += @toIndent
        append("#{@indent}<INTERNAL:   #{method.internal}/>")
        printL
        append("#{@indent}<STATIC:     #{method.static}/>\n")
        append("#{@indent}<SINGLETON:  #{method.singleton}/>")
        printL
        append("#{@indent}<VISIBILITY: #{method.visib}/>\n")
        @indent = indent
        append("#{indent}<#{method.name}/>")
        printL
    end

    protected def printIncluded(array)
        array.each do |entry|
            append("#{@indent}<INCLUDED: #{entry.name}/>")
        end
    end

    protected def printSymTab(symtab)
        symtab.each_key do |key|
            printEntry(symtab[key])
        end
    end

    private def append(text : String) : ::Nil
        textSize = text ? text.size : 0
        lBreak = false

        if @length + textSize > Width
            printL
            @line  += @indent
            @length = @indent.size
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