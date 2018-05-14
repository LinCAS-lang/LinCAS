
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

    def makeParser(string : String,filename : String,line : IntnumR)
        parser = Parser.new(makeScanner(string,filename,line))
        parser.addListener(ParserListener.new)
        return parser
    end

end
