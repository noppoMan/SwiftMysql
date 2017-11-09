class MysqlPacketWriter {
    let stream: AsyncDuplexStream // Should be an AsyncWritableStream
    
    init(stream: AsyncDuplexStream) {
        self.stream = stream
    }
    
    func writeHeader(_ len: UInt32, pn: UInt8, completion: (() -> Void)? = nil) {
        stream.write([UInt8].UInt24Array(len) + [pn], completion: completion)
    }
    
    func writePacket(_ bytes: [UInt8], packnr: Int, completion: (() -> Void)? = nil) {
        writeHeader(UInt32(bytes.count), pn: UInt8(packnr + 1))
        stream.write(bytes) {
            completion?()
        }
    }
    
    func write(_ cmd: Commands, query: String, completion: (() -> Void)? = nil) {
        writePacket([cmd.rawValue] + query.utf8, packnr: -1, completion: completion)
    }
    
    func write(_ cmd: Commands, completion: (() -> Void)? = nil) {
        writePacket([cmd.rawValue], packnr: -1, completion: completion)
    }
}
