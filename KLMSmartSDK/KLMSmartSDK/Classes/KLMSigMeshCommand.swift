//
//  KLMSigMeshCommand.swift
//  KLM
//
//  Created by zhu yu on 2023/6/7.
//

import UIKit
import nRFMeshProvision
import CoreBluetooth

public typealias ScanDevice = (_ device: DiscoveredPeripheral) -> Void
public typealias CommandResult = (_ isSuccess: Bool, _ error: Error?) -> Void
public typealias ActiveSuccess = (_ node: Node) -> Void
typealias Timeout = (_ error: Error?) -> Void
public typealias ActiveFailure = (_ device: DiscoveredPeripheral, _ error: Error?) -> Void
public typealias DidConnectDevice = (_ device: DiscoveredPeripheral) -> Void
public typealias AllFinish = (_ isAll: Bool) -> Void

class KLMSigMeshCommand: NSObject {
    
    var commandResult: CommandResult?
    var scanDevice: ScanDevice?
    var timeout: TimeInterval = 10
    var timer: Timer?
    var activeSuccess: ActiveSuccess?
    var activeFailure: ActiveFailure?
    var didConnectDevice: DidConnectDevice?
    var messageHandle: MessageHandle?
    var allFinish: AllFinish?
}

extension KLMSigMeshCommand {
    
    func startTimer(_ timeOut: Timeout?) {
        self.timer?.invalidate()
        self.timer = nil
        self.timer = Timer.scheduledTimer(withTimeInterval: self.timeout, repeats: false, block: { [weak self] t in
            guard let self = self else { return }
            self.commandTimeoutWithCommand(timeOut)
        })
    }
    
    private func commandTimeoutWithCommand(_ timeOut: Timeout?) {
        commandResponseFinishWithCommand()
        ///main thread refresh UI
        DispatchQueue.main.async {
            if let timeOut = timeOut {
                timeOut(KLMError.timeout)
            }
        }
    }
    
    func commandResponseFinishWithCommand() {

        self.timer?.invalidate()
        self.timer = nil
    }
}

 public struct DiscoveredPeripheral {
    
    var device: UnprovisionedDevice
    var peripheral: CBPeripheral
    var rssi: Int
}

