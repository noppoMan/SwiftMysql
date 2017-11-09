import Foundation

func okPacketOrFieldLength(for bytes: [Byte]) throws -> (Int, OKPacket?) {
    if let okPacket = try OKPacket(bytes: bytes) {
        return (0, okPacket)
    } else {
        let (_num, n) = lenEncInt(bytes)
        if let num = _num, (n - bytes.count) == 0 {
            return (Int(num), nil)
        } else {
            return (0, nil)
        }
    }
}

// TODO should devide into ReadablePacketStream and WritablePacketStream
class PacketStream {
    
    private let stream: DuplexStream
    
    init(stream: DuplexStream) {
        self.stream = stream
    }
    
    func readPacket() throws -> (Bytes, Int) {
        let length = Int(try stream.read(upTo: 3).uInt24()) // [n, n, n] payload length
        let sequenceId = try stream.read(upTo: 1)[0] // [n] sequence ids
        var bytes = Bytes()
        while bytes.count < length {
            bytes.append(contentsOf: try stream.read(upTo: length))
        }
        return (bytes, Int(sequenceId))
    }
    
    func readHeaderPacket() throws -> (Int, OKPacket?) {
        let (bytes, _) = try readPacket()
        return try okPacketOrFieldLength(for: bytes)
    }
    
    func readUntilEOF() throws {
        while true {
            let (bytes, _) = try readPacket()
            if bytes[0] == 0xfe {
                break
            }
        }
    }
    
    func writeHeader(_ len: UInt32, pn: UInt8) throws {
        try stream.write([UInt8].UInt24Array(len) + [pn])
    }
    
    func writePacket(_ bytes: [UInt8], packnr: Int) throws {
        try writeHeader(UInt32(bytes.count), pn: UInt8(packnr + 1))
        try stream.write(bytes)
    }
    
    func write(_ cmd: Commands, query: String) throws {
        try writePacket([cmd.rawValue] + query.utf8, packnr: -1)
    }
    
    func write(_ cmd: Commands) throws {
        try writePacket([cmd.rawValue], packnr: -1)
    }
    
    /************** Proxys **************/
    
    var isClosed: Bool {
        return stream.isClosed
    }
    
    func open() throws {
        try stream.open(deadline: 0)
    }
    
    func close() {
        stream.close()
    }
}
