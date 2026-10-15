import CoreTransferable
import Foundation
import UniformTypeIdentifiers

extension UTType {
    static let countdownCard = UTType(exportedAs: "com.countdowntogether.countdown", conformingTo: .json)
}

struct CountdownFile: Transferable {
    var payload: SyncPayload

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .countdownCard) { file in
            let data = try SyncCoding.encoder.encode(file.payload)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(file.payload.countdown.inviteCode).countdown")
            try data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        } importing: { received in
            let data = try Data(contentsOf: received.file)
            let payload = try SyncCoding.decoder.decode(SyncPayload.self, from: data)
            return CountdownFile(payload: payload)
        }
    }
}
