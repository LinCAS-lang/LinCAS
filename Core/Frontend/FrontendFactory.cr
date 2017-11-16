
struct LinCAS::FrontendFactory

    def makeReader(filename : String)
        reader = Reader.new(filename)
        reader.addListener(ReaderListener.new)
        return reader
    end
    
    def makeSource(filename : String)
        return Source.new(makeReader(filename))
    end

    def makeSource(reader : Reader)
        return Source.new(reader)
    end

    def makeScanner(filename : String)
        return makeScanner(makeSource(filename))
    end
    
    def makeScanner(source : Source)
        scanner = Scanner.new(source)
        scanner.addListener(ScannerListener.new)
        return scanner
    end

    def makeParser(filename : String)
        return makeParser(makeSource(filename))
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

end