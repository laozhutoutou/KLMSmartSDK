//
//  KLMSigScanManager.swift
//  KLM
//
//  Created by zhu yu on 2023/6/7.
//

import Foundation
import CoreBluetooth
import nRFMeshProvision

class KLMSigScanManager: NSObject {
    
    static let shared = KLMSigScanManager()
    private override init(){}
    
    var command: KLMSigMeshCommand?
    
    private lazy var centralManager: CBCentralManager = {
        let centralManager = CBCentralManager()
        centralManager.delegate = self
        return centralManager
    }()
    
    ///start Scanning
    func startScan(scanDevice: @escaping ScanDevice, commandResult: @escaping CommandResult) {
        
        let command = KLMSigMeshCommand()
        command.scanDevice = scanDevice
        command.commandResult = commandResult
        command.timeout = 20
        self.command = command
        command.startTimer { [weak self] error in
            guard let self = self else { return }
            ///stop scanning
            stopScanning()
            //return
            DispatchQueue.main.async {
                commandResult(false, error)
            }
        }
        startScanning()
    }
    
    private func startScanning() {
        centralManager.scanForPeripherals(withServices: [MeshProvisioningService.uuid],
                                          options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
    }
    
    func stopScanning() {
        centralManager.stopScan()
        command?.commandResponseFinishWithCommand()
        command = nil
    }
    
    ///stop Timer
    private func stopScanTimer() {
        command?.commandResponseFinishWithCommand()
    }
}

extension KLMSigScanManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScanning()
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let unprovisionedDevice = UnprovisionedDevice(advertisementData: advertisementData) {

            if unprovisionedDevice.uuid.uuidString.count >= 2 {
                //DD 
                let id = unprovisionedDevice.uuid.uuid.0
                if id == 0xDD {
                    var name = unprovisionedDevice.name
                    unprovisionedDevice.name = name
                    ///stopTimer
                    stopScanTimer()
                    let discoveredPeripheral: DiscoveredPeripheral = DiscoveredPeripheral(device: unprovisionedDevice, peripheral: peripheral, rssi: RSSI.intValue)
                    if let scanBlock = command?.scanDevice {
                        DispatchQueue.main.async {
                            scanBlock(discoveredPeripheral)
                        }
                    }
                }
            }
        }
    }
}
