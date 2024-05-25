//
//  KLMSmartGroup.swift
//  KLM
//
//  Created by 朱雨 on 2021/7/20.
//

import UIKit
import nRFMeshProvision

public class KLMSmartGroup: NSObject {
    
    static let sharedInstacnce = KLMSmartGroup()
    private override init(){
        super.init()
    }
    
    public typealias SuccessBlock = () -> Void
    public typealias FailureBlock = (_ error: KLMMessageError?) -> Void
    
    ///分组 send
    public func setGroupData(_ parame: requestparame, toGroup group: Group,_ success: @escaping SuccessBlock, failure: @escaping FailureBlock) {
        
        let manager = KLMSmartBleMesh.shared.meshNetworkManager!
        
        //一个设备都没连接
        if !KLMSmartBleMesh.shared.connection.isOpen {
            var error = KLMMessageError(dpId: parame.dpId)
            let errorInfo = NSLocalizedString("Make sure the device is powered on and nearby.Otherwise,check if it is connected by others or out of order.", comment: "")
            error.error = KLMError.error(errorInfo)
            failure(error)
            return
        }
        
        var parameString: String?
        if let intParame: Int = parame.dpValue as? Int {
            parameString = intParame.decimalTo2Hexadecimal()
        } else if let stringParame: String = parame.dpValue as? String {
            parameString = stringParame
        } else {
            let error = KLMMessageError(dpId: parame.dpId, error: KLMError.invalidParameter)
            failure(error)
            return
        }
        
        let dpString = parame.dpId.decimalTo2Hexadecimal()
        if let opCode = UInt8("1A", radix: 16) {
            let parameters = Data(hex: dpString + (parameString ?? ""))
            print("requestparame = \(parameters.hex)")
            let network = manager.meshNetwork!
            let models = network.models(subscribedTo: group)
            if let model = models.first {
                
                let message = RuntimeVendorMessage(opCode: opCode, for: model, parameters: parameters)
                do {
                    
                    try manager.send(message, to: group, using: model.boundApplicationKeys.first!)
                    success()
                    
                } catch {
                    let error1 = KLMMessageError(dpId: parame.dpId, error: error)
                    failure(error1)
                }
            } else {
                var error = KLMMessageError(dpId: parame.dpId)
                let errorInfo = NSLocalizedString("No devices", comment: "")
                error.error = KLMError.error(errorInfo)
                failure(error)
            }
        }
    }
    
    /// 给所有节点发消息
    /// - Parameters:
    ///   - parame: 参数
    ///   - success: success
    ///   - failure: failure
    public func setDataToAllNodes(_ parame: requestparame,_ success: @escaping SuccessBlock, failure: @escaping FailureBlock) {
        
        let manager = KLMSmartBleMesh.shared.meshNetworkManager!
                
        //一个设备都没连接
        if !KLMSmartBleMesh.shared.connection.isOpen {
            var error = KLMMessageError(dpId: parame.dpId)
            let errorInfo = NSLocalizedString("Make sure the device is powered on and nearby.Otherwise,check if it is connected by others or out of order.", comment: "")
            error.error = KLMError.error(errorInfo)
            failure(error)
            return
        }
        
        var parameString: String?
        if let intParame: Int = parame.dpValue as? Int {
            parameString = intParame.decimalTo2Hexadecimal()
        } else if let stringParame: String = parame.dpValue as? String {
            parameString = stringParame
        } else {
            let error = KLMMessageError(dpId: parame.dpId, error: KLMError.invalidParameter)
            failure(error)
            return
        }
        
        let dpString = parame.dpId.decimalTo2Hexadecimal()
        if let opCode = UInt8("1A", radix: 16) {
            let parameters = Data(hex: dpString + (parameString ?? ""))
            print("requestparame = \(parameters.hex)")
            
            let network = manager.meshNetwork!
            let notConfiguredNodes = network.nodes.filter({ !$0.isConfigComplete && !$0.isProvisioner })
            guard !notConfiguredNodes.isEmpty else {
                
                //没有节点
                var error = KLMMessageError(dpId: parame.dpId)
                let errorInfo = NSLocalizedString("No devices", comment: "")
                error.error = KLMError.error(errorInfo)
                failure(error)
                return
            }
            
            ///可能节点没配置完成
            guard let model = KLMTool.getModelFromNode(node: notConfiguredNodes.first!), model.boundApplicationKeys.first != nil else {
                var error = KLMMessageError(dpId: parame.dpId)
                let errorInfo = NSLocalizedString("Application Key is not bound", comment: "")
                error.error = KLMError.error(errorInfo)
                failure(error)
                return
            }
            let message = RuntimeVendorMessage(opCode: opCode, for: model, parameters: parameters)
            do {
                //allNodes 为所有节点
                try  manager.send(message, to: MeshAddress.init(.allNodes), using: model.boundApplicationKeys.first!)
                success()
                
            } catch {
                
                let error1 = KLMMessageError(dpId: parame.dpId, error: error)
                failure(error1)
                
            }
        }
    }
}
