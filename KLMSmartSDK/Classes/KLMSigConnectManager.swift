//
//  KLMSigConnectManager.swift
//  KLM
//
//  Created by zhu yu on 2023/6/7.
//

import UIKit
import nRFMeshProvision

class KLMSigConnectManager: NSObject {
    
    static let shared = KLMSigConnectManager()
    private override init(){}
    
    var command: KLMSigMeshCommand?
    var gattBearer: PBGattBearer?
    
    ///start connect
    func startConnect(discoveredPeripheral: DiscoveredPeripheral, commandResult: @escaping CommandResult) {

        let command = KLMSigMeshCommand()
        command.commandResult = commandResult
        command.timeout = 15
        self.command = command
        command.startTimer { [weak self] error in
            guard let self = self else { return }
            ///timeout stop connect
            stopConnectDevice()
            DispatchQueue.main.async {
                commandResult(false, error)
            }
        }
        
        let bb = PBGattBearer(target: discoveredPeripheral.peripheral)
        bb.delegate = self
        bb.open()
        gattBearer = bb
        KLMSigScanManager.shared.stopScanning()
    }
    
    ///stop connect
    func stopConnectDevice() {
        gattBearer?.delegate = nil
        gattBearer?.close()
        
    }
}

extension KLMSigConnectManager: BearerDelegate {

    func bearerDidOpen(_ bearer: Bearer) {
        
        ///代理置为nil
        bearer.delegate = nil
        
        ///连接未配网成功
        if let bb:PBGattBearer = bearer as? PBGattBearer {
            
            command?.commandResponseFinishWithCommand()
            if let resultCallback = command?.commandResult {
                DispatchQueue.main.async {
                    resultCallback(true, nil)
                }
            }
        }
    }

    func bearer(_ bearer: Bearer, didClose error: Error?) {
        
    }
}
