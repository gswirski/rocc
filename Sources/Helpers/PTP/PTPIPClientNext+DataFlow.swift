//
//  PTPIPClient+DataFlow.swift
//  Rocc
//
//  Created by Simon Mitchell on 03/11/2019.
//  Copyright © 2019 Simon Mitchell. All rights reserved.
//

import Foundation
import os.log

extension PTPIPClientNext {
    
    /// Asynchronously waits for data to be received for the given transaction ID
    /// - Parameter transactionId: The transaction ID to await data for
    /// - Parameter callback: A closure to be called once the data was fully received
    func awaitDataFor(transactionId: DWord, callback: @escaping DataResponse) {
        dataCallbacks[transactionId] = callback
    }

    func handleStartDataPacket(_ packet: StartDataPacket) {
        if var containerForData = dataContainers[packet.transactionId] {
            containerForData.appendData(from: packet)
            dataContainers[packet.transactionId] = containerForData
        } else {
            dataContainers[packet.transactionId] = PTPIPClient.DataContainer(startPacket: packet)
        }
    }

    func handleDataPacket(_ packet: DataPacket) {
        guard var containerForData = dataContainers[packet.transactionId] else {
            os_log("Received unexpected data packet for transactionId: %{public}@", log: ptpClientLog, type: .error, "\(packet.transactionId)")
            Logger.log(message: "Received unexpected data packet for transactionId: \(packet.transactionId)", category: "PTPIPClient", level: .error)
            return
        }
        containerForData.appendData(from: packet)
        dataContainers[packet.transactionId] = containerForData
    }
    
    func handleEndDataPacket(_ packet: EndDataPacket) {
        guard var containerForData = dataContainers[packet.transactionId] else {
            os_log("Received unexpected end data packet for transactionId: %{public}@", log: ptpClientLog, type: .error, "\(packet.transactionId)")
            Logger.log(message: "Received unexpected end data packet for transactionId: \(packet.transactionId)", category: "PTPIPClient", level: .error)
            return
        }
        containerForData.appendData(from: packet)
        dataContainers[packet.transactionId] = containerForData
    }
}


