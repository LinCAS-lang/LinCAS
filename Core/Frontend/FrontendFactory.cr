
struct LinCAS::FrontendFactory

    def makeReader(filename : String)
        reader = Reader.new(filename)
        reader.addListener(ReaderListener.new)
        return reader
    end
    
    @[AlwaysInline]
    def makeSource(filename : String)
        Source.new(makeReader(filename))
    end

    @[AlwaysInline]
    def makeSource(reader : Reader)
        Source.new(reader)
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

end