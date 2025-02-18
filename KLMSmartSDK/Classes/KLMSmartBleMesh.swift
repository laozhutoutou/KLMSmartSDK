//
//  KLMSmartBleMesh.swift
//  KLMSmartSDK
//
//  Created by zhu yu on 2024/5/13.
//

import Foundation
import nRFMeshProvision

public class KLMSmartBleMesh: NSObject {
    
    var meshNetworkManager: MeshNetworkManager!
    var connection: NetworkConnection!
    
    public static let shared = KLMSmartBleMesh()
    private override init(){
        super.init()
        setUpNordic()
    }
    
    private func setUpNordic() {
        
        meshNetworkManager = MeshNetworkManager()
        meshNetworkManager.acknowledgmentTimerInterval = 0.150
        meshNetworkManager.transmissionTimerInterval = 0.600
        meshNetworkManager.incompleteMessageTimeout = 10.0
        meshNetworkManager.retransmissionLimit = 2
        meshNetworkManager.acknowledgmentMessageInterval = 4.2
//        meshNetworkManager.logger = self
    }
    
    public func createSIGMesh(meshName: String) -> Data {
        
        let provisioner = Provisioner(name: UIDevice.current.name,
                                      allocatedUnicastRange: [AddressRange(0x0001...0x199A)],
                                      allocatedGroupRange:   [AddressRange(0xC000...0xCC9A)],
                                      allocatedSceneRange:   [SceneRange(0x0001...0x3333)])
        let network = MeshNetworkManager().createNewMeshNetwork(withName: meshName, by: provisioner)
        let newKey: Data! = Data.random128BitKey()
        do {
            try network.add(applicationKey: newKey, withIndex: 0, name: "new key")
        } catch  {
            print(error)
        }
        ///配置数据转化成data
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try! encoder.encode(network)
        return data
    }
    
    public func removeMesh() {
        createNewMeshNetwork()
    }
    
    public func `import`(from data: Data) {
        let manager = KLMSmartBleMesh.shared.meshNetworkManager!
        do {
            _ = try manager.import(from: data)
            saveAndReload()
        } catch {
            print(error)
        }
    }
    
//    public func export() -> Data {
//        let manager = KLMSmartBleMesh.shared.meshNetworkManager!
//        if manager.save() {}
//        return manager.export(.full)
//    }
    
    public func editProvisionerUnicastAddress(newAddress: Address) {
        let manager = KLMSmartBleMesh.shared.meshNetworkManager!
        let meshNetwork = manager.meshNetwork!
        let provisioner: Provisioner = (meshNetwork.provisioners.first)!
        // If the address is changing, remove the old addresses from the Proxy Filter.
        if let node = provisioner.node {
            let unicastAddresses = node.elements.map { $0.unicastAddress }
            manager.proxyFilter?.remove(addresses: unicastAddresses)
        }
        // Try assigning the new Unicast Address. Hopefully this will not throw,
        // as ranges were already allocated.
        do {
            try meshNetwork.assign(unicastAddress: newAddress, for: provisioner)
            // Add the new addresses to the Proxy Filter.
            let unicastAddresses = provisioner.node!.elements.map { $0.unicastAddress }
            manager.proxyFilter?.add(addresses: unicastAddresses)
        } catch  {
            print(error)
        }
    }
}

extension KLMSmartBleMesh {
    
    private func createNewMeshNetwork() {
        let provisioner = Provisioner(name: UIDevice.current.name,
                                      allocatedUnicastRange: [AddressRange(0x0001...0x199A)],
                                      allocatedGroupRange:   [AddressRange(0xC000...0xCC9A)],
                                      allocatedSceneRange:   [SceneRange(0x0001...0x3333)])
        _ = meshNetworkManager.createNewMeshNetwork(withName: "iOS mesh", by: provisioner)
        _ = meshNetworkManager.save()
        
        meshNetworkDidChange()
    }
    
    private func saveAndReload() {
        
        let manager = KLMSmartBleMesh.shared.meshNetworkManager!
        if manager.save() {
            
            DispatchQueue.main.async {
                self.meshNetworkDidChange()
            }
        }
    }
    
    private func meshNetworkDidChange() {
        connection?.close()
        let meshNetwork = meshNetworkManager.meshNetwork!
        connection = NetworkConnection(to: meshNetwork)
        connection!.dataDelegate = meshNetworkManager
//        connection!.logger = self
        meshNetworkManager.transmitter = connection
        connection.isConnectionModeAutomatic = true
        connection!.open()
        
    }
}
