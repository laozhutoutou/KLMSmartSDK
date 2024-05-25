//
//  KLMSigActiveManager.swift
//  KLM
//
//  Created by on 2023/6/7.
//

import UIKit
import nRFMeshProvision
import CoreBluetooth

class KLMSigActiveManager: NSObject {
    
    static let shared = KLMSigActiveManager()
    private override init(){}
    
    private lazy var centralManager: CBCentralManager = {
        let centralManager = CBCentralManager()
        centralManager.delegate = self
        return centralManager
    }()
    
    var command: KLMSigMeshCommand?
    var provisonManager :KLMProvisionManager!
    var currentNode: Node!
//    var currentBindModelIndex = 0
    var bearer1828: GattBearer?
    var discoveredPeripheral: DiscoveredPeripheral!
    var gattBearer: PBGattBearer?
    
    ///记录设备是否需要扫描
    private var isNeedScanning: Bool = false
    
    ///开始配网
    func startActive(discoveredPeripheral: DiscoveredPeripheral, gattBearer: PBGattBearer, activeSuccess: @escaping ActiveSuccess, activeFailure: @escaping ActiveFailure) {
        
        let command = KLMSigMeshCommand()
        command.activeSuccess = activeSuccess
        command.activeFailure = activeFailure
        command.timeout = 20
        self.command = command
        command.startTimer { [weak self] error in
            guard let self = self else { return }
            ///停止配网
            stopActive()
            //超时返回失败
            DispatchQueue.main.async {
                activeFailure(discoveredPeripheral, error)
            }
        }
        
        self.discoveredPeripheral = discoveredPeripheral
        self.gattBearer = gattBearer
        
        let provisonManager = KLMProvisionManager.init(discoveredPeripheral: discoveredPeripheral, bearer: gattBearer)
        provisonManager.delegate = self
        provisonManager.identify()
        self.provisonManager = provisonManager
    }
    
    ///停止配网
    private func stopActive() {
        stopScanning()
        bearer1828?.delegate = nil
        bearer1828?.close()
        command?.messageHandle?.cancel()
    }
    
    private func stopScanning() {
        isNeedScanning = false
        centralManager.stopScan()
    }
    
    private func startScanning() {
        centralManager.scanForPeripherals(withServices: [MeshProxyService.uuid], options: nil)
    }
    
    private func getCompositionData(node: Node) {
        
        self.currentNode = node
        let message = ConfigCompositionDataGet()
        do {
            command?.messageHandle = try KLMSmartBleMesh.shared.meshNetworkManager.send(message, to: node)
            
        } catch  {
            print(error)
        }
    }
    
    private func addAppkeyToNode(node: Node) {
        
        self.currentNode = node
        let applicationKey = KLMSmartBleMesh.shared.meshNetworkManager.meshNetwork!.applicationKeys.first
        let message = ConfigAppKeyAdd(applicationKey: applicationKey!)
        do {
            command?.messageHandle = try KLMSmartBleMesh.shared.meshNetworkManager.send(message, to: node)
             
        } catch  {
            print(error)
        }
    }
    
    private func addAppkeyToModel(node: Node) {
        
//        currentBindModelIndex = 0
        
        self.currentNode = node
        
        ///绑定多个Model
//        nextModel()
        
    }
    
//    private func nextModel() {
//
//        if currentBindModelIndex < self.currentNode.primaryElement!.models.count {
//            let model = self.currentNode.primaryElement!.models[currentBindModelIndex]
//            let keys = self.currentNode.applicationKeysAvailableFor(model)
//            if let applicationKey = keys.first {
//                let message = ConfigModelAppBind(applicationKey: applicationKey, to: model)!
//
//                do {
//                    command?.messageHandle = try KLMSmartBleMesh.shared.meshNetworkManager.send(message, to: self.currentNode)
//                } catch  {
//                    print(error)
//                }
//            } else { ///model已经绑定了，开始下一个model
//                currentBindModelIndex += 1
//                nextModel()
//            }
//            
//        } else {
//
//            deviceConfigSuccess()
//        }
//    }
    
    private func deviceConfigSuccess() {
        
//        currentBindModelIndex = 0
                
        //整个流程配置完成
        command?.commandResponseFinishWithCommand()
        if let result = command?.commandResult {
            DispatchQueue.main.async {
                result(true, nil)
            }
        }
        if let activeSuccess = command?.activeSuccess {
            DispatchQueue.main.async {
                activeSuccess(self.currentNode)
            }
        }
    }
}

extension KLMSigActiveManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            if isNeedScanning {
                startScanning()
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if let networkId = advertisementData.networkId {
            guard KLMSmartBleMesh.shared.meshNetworkManager.meshNetwork!.matches(networkId: networkId) else {
                // A Node from another mesh network.
                return
            }
        } else {
            // Is it a Node Identity beacon?
            guard let nodeIdentity = advertisementData.nodeIdentity,
                  KLMSmartBleMesh.shared.meshNetworkManager.meshNetwork!.matches(hash: nodeIdentity.hash, random: nodeIdentity.random) else {
                // A Node from another mesh network.
                return
            }
        }
        
        let bearer = GattBearer(target: peripheral)
        if bearer.identifier == discoveredPeripheral.peripheral.identifier { ///找到添加的设备
            
            ///停止扫描
            stopScanning()
            bearer.delegate = self
            bearer.open()
            bearer1828 = bearer
        }
    }
}

extension KLMSigActiveManager: BearerDelegate {

    func bearerDidOpen(_ bearer: Bearer) {
        ///连接直连设备成功
        if let bb: GattBearer = bearer as? GattBearer, bb == bearer1828 {
            KLMSmartBleMesh.shared.connection.isConnectionModeAutomatic = false
            KLMSmartBleMesh.shared.connection.use(proxy: bb)
            KLMSmartBleMesh.shared.connection.isConnectionModeAutomatic = true
            ///开始发数据
            //composition

            if let network = KLMSmartBleMesh.shared.meshNetworkManager.meshNetwork {
                
                let node = network.node(for: discoveredPeripheral.device)!
                if !node.isCompositionDataReceived {
                    self.getCompositionData(node: node)
                }
            }
        }
    }

    func bearer(_ bearer: Bearer, didClose error: Error?) {
        
    }
}

extension KLMSigActiveManager: KLMProvisionManagerDelegate {
    
    func provisionManager(_ manager: KLMProvisionManager, didFailChange error: Error?) {

        command?.commandResponseFinishWithCommand()
        if let failure = command?.activeFailure {
            DispatchQueue.main.async {
                failure(self.discoveredPeripheral, error)
            }
        }
    }
    
    func provisionManagerNodeAddSuccess(_ manager: KLMProvisionManager) {
        
        KLMSmartBleMesh.shared.meshNetworkManager.delegate = self
        
        ///如果不是直连设备，切换当前为直连设备然后再继续
        if let bearer = KLMSmartBleMesh.shared.connection.proxies.first {
            
            ///当前配网设备是直连设备
            if bearer.identifier == manager.discoveredPeripheral.peripheral.identifier {
                
                //composition
                if let network = KLMSmartBleMesh.shared.meshNetworkManager.meshNetwork {

                    let node = network.node(for: manager.discoveredPeripheral.device)!
                    if !node.isCompositionDataReceived {
                        self.getCompositionData(node: node)
                    }
                }
                
            } else { ///不是直连设备，要切换直连
                
                isNeedScanning = true
                startScanning()
            }
        }
    }
}

extension KLMSigActiveManager: MeshNetworkDelegate {
    
    func meshNetworkManager(_ manager: MeshNetworkManager, didReceiveMessage message: MeshMessage, sentFrom source: Address, to destination: Address) {
        
        switch message {
        case let status as ConfigAppKeyStatus://node add app key success
            if status.status == .success{
            
                self.addAppkeyToModel(node: self.currentNode)
                return
            }
        case is ConfigCompositionDataStatus:
        
            //给node 配置app key
            self.addAppkeyToNode(node: self.currentNode)
            return
            
        case _ as ConfigModelAppStatus:
            
//            currentBindModelIndex += 1
//            ///继续绑定下一个model
//            nextModel()
            
            return
        default:
            break
        }
    }
    
    func meshNetworkManager(_ manager: MeshNetworkManager,
                            failedToSendMessage message: MeshMessage,
                            from localElement: Element, to destination: Address,
                            error: Error){
        
        command?.commandResponseFinishWithCommand()
        if let result = command?.commandResult {
            DispatchQueue.main.async {
                result(false, error)
            }
        }
        if let failure = command?.activeFailure {
            DispatchQueue.main.async {
                failure(self.discoveredPeripheral, error)
            }
        }
    }
    
    func meshNetworkManager(_ manager: MeshNetworkManager,
                            didSendMessage message: MeshMessage,
                            from localElement: Element, to destination: Address) {
        
       
    }
}
