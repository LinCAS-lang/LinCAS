
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

struct LinCAS::FrontendFactory

    def makeReader(filename : String)
        reader = Reader.new(filename)
        reader.addListener(ReaderListener.new)
        return reader
    end

    def makeReader(string : String,filename : String,line : IntnumR)
        return VirtualFile.new(string,filename,line)
    end
    
    @[AlwaysInline]
    def makeSource(filename : String)
        Source.new(makeReader(filename))
    end

    @[AlwaysInline]
    def makeSource(reader : Reader)
        Source.new(reader)
    end

    def makeSource(reader : VirtualFile)
        Source.new(reader)
    end

    def makeSource(string : String,filename : String,line : IntnumR)
        return makeSource(makeReader(string,filename,line))
    end

    @[AlwaysInline]
    def makeScanner(filename : String)
        makeScanner(makeSource(filename))
    end
    
    def makeScanner(source : Source)
        scanner = Scanner.new(source)
        scanner.addListener(ScannerListener.new)
        return scanner
    end

    def makeScanner(string : String,filename : String,line : IntnumR)
        scanner = makeScanner(makeSource(string,filename,line))
        scanner.addListener(ScannerListener.new)
        return scanner
    end

    @[AlwaysInline]
    def makeParser(filename : String)
        makeParser(makeSource(filename))
    end

    def makeParser(source : Source)
        parser = Parser.new(makeScanner(source))
        parser.addListener(ParserListener.new)
        return parser
    end

    def makeParser(scanner : Scanner)
        parser = Parser.new(scanner)
        parser.addListener(ParserListener.new)
        return parser
    end

<<<<<<< HEAD
end
=======
    def makeParser(string : String,filename : String,line : IntnumR)
        parser = Parser.new(makeScanner(string,filename,line))
        parser.addListener(ParserListener.new)
        return parser
    end

end
>>>>>>> lc-vm
