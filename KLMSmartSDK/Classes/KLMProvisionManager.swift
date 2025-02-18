//
//  KLMProvisionManager.swift
//  KLM
//
//  Created by zhu yu on 2021/7/19.
//

import UIKit
import nRFMeshProvision

protocol KLMProvisionManagerDelegate: AnyObject {
    
    func provisionManager(_ manager: KLMProvisionManager, didFailChange error: Error?)
    
    func provisionManagerNodeAddSuccess(_ manager: KLMProvisionManager)
}

class KLMProvisionManager: NSObject {
    
    private var provisioningManager: ProvisioningManager!
    var bearer: ProvisioningBearer!
    /// 配网设备
    var discoveredPeripheral: DiscoveredPeripheral!
    weak var delegate:  KLMProvisionManagerDelegate?
    private var unicastAddress: UInt16?
    
    //单例
    init(discoveredPeripheral: DiscoveredPeripheral, bearer: ProvisioningBearer, unicastAddress: UInt16? = nil) {
        super.init()
        self.discoveredPeripheral = discoveredPeripheral
        self.unicastAddress = unicastAddress
        self.bearer = bearer
        self.bearer.delegate = self
    }
}

extension KLMProvisionManager {
    
    func identify() {
        
        let manager = KLMSmartBleMesh.shared.meshNetworkManager!
        self.provisioningManager = try! manager.provision(unprovisionedDevice: self.discoveredPeripheral.device, over: self.bearer)
        self.provisioningManager.delegate = self
        self.provisioningManager.logger = manager.logger
        do {
            try self.provisioningManager.identify(andAttractFor: 5)
        } catch {

            self.delegate?.provisionManager(self, didFailChange: error)
        }
    }
}

extension KLMProvisionManager: ProvisioningDelegate {
    func authenticationActionRequired(_ action: AuthAction) {
        
    }
    
    func inputComplete() {
        
    }
    
    func provisioningState(of unprovisionedDevice: UnprovisionedDevice, didChangeTo state: ProvisioningState) {
        
        switch state {
        case .capabilitiesReceived(_)://identify完成
                        
            //provision
            if provisioningManager.networkKey == nil {
                let network = KLMSmartBleMesh.shared.meshNetworkManager.meshNetwork!
                let networkKey = try! network.add(networkKey: Data.random128BitKey(), name: "Primary Network Key")
                provisioningManager.networkKey = networkKey
            }
            
            if let unicastAddress = unicastAddress {
                self.provisioningManager.unicastAddress = unicastAddress
            }
            do {
                try self.provisioningManager.provision(usingAlgorithm:       .fipsP256EllipticCurve,
                                                       publicKey:            .noOobPublicKey,
                                                       authenticationMethod: .noOob)
            } catch {
                
                if let error = error as? ProvisioningError {

                    self.delegate?.provisionManager(self, didFailChange: error)
                }
            }
            
        case .complete://provison完成
                        
            //关闭和未配网设备的连接--这个时候开始连接1828设备
            self.bearer.close()
        
        case let .fail(error):
            
            self.bearer.close()
            self.delegate?.provisionManager(self, didFailChange: error)
            
        default:
            break
        }
    }
}

extension KLMProvisionManager: GattBearerDelegate {

    func bearer(_ bearer: Bearer, didClose error: Error?) {
        guard case .complete = provisioningManager.state else {
            return
        }
        if KLMSmartBleMesh.shared.meshNetworkManager.save() {
            self.delegate?.provisionManagerNodeAddSuccess(self)
        }
    }

    func bearerDidOpen(_ bearer: Bearer) {

    }
}
