//
//  KLMTool.swift
//  KLMSmartSDK
//
//  Created by 朱雨 on 2024/5/15.
//

import Foundation
import nRFMeshProvision

/// The Company Identifier or `nil`, if the model is Bluetooth SIG-assigned.
private let companyIdentifier: UInt16 = 0xff00
///Bluetooth SIG or vendor-assigned model identifier.
private let modelIdentifier: UInt16 = 2

class KLMTool {
    
    static func getModelFromNode(node: Node) -> Model? {
        
        let models = node.primaryElement!.models
        for M in models {
            if M.modelIdentifier == modelIdentifier && M.companyIdentifier == companyIdentifier {
                return M
            }
        }
        return nil
    }
}

///传的参数
public struct requestparame {
    var dpId: Int
    var dpValue: Any?
}

///返回参数
public struct responseParame {
    var dpId: Int?
    var dpValue: Any?
    var opCodeType: OpCodeType?
}

enum OpCodeType {
    case set
    case get
}

extension Int {
    
    /// 十进制转16进制 1个字节
    /// - Returns: 16进制字符串
    func decimalTo2Hexadecimal() -> String {
        
        return String(format: "%02X", self)
    }
}

struct RuntimeVendorMessage: VendorMessage {
    
    let opCode: UInt32
    let parameters: Data?
    
    var isSegmented: Bool = false
    var security: MeshMessageSecurity = .low
    
    init(opCode: UInt8, for model: Model, parameters: Data?) {
        self.opCode = (UInt32(0xC0 | opCode) << 16) | UInt32(model.companyIdentifier!.bigEndian)
        self.parameters = parameters
    }
    
    init?(parameters: Data) {
        // This init will never be used, as it's used for incoming messages.
        return nil
    }
}

extension UInt32 {
    func hex() -> String {
        return String(format: "%08X", self)
    }
}

