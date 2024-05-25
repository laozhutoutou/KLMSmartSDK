/*
* Copyright (c) 2019, Nordic Semiconductor
* All rights reserved.
*
* Redistribution and use in source and binary forms, with or without modification,
* are permitted provided that the following conditions are met:
*
* 1. Redistributions of source code must retain the above copyright notice, this
*    list of conditions and the following disclaimer.
*
* 2. Redistributions in binary form must reproduce the above copyright notice, this
*    list of conditions and the following disclaimer in the documentation and/or
*    other materials provided with the distribution.
*
* 3. Neither the name of the copyright holder nor the names of its contributors may
*    be used to endorse or promote products derived from this software without
*    specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
* ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
* IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
* INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
* NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
* PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
* WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
* ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
* POSSIBILITY OF SUCH DAMAGE.
*/

import Foundation

internal struct NetworkKeyDerivatives {
    /// The Identity Key.
    let identityKey: Data!
    /// The Beacon Key.
    let beaconKey: Data!
    /// The Encryption Key.
    let encryptionKey: Data!
    /// The Privacy Key.
    let privacyKey: Data!
    /// Network identifier.
    let nid: UInt8!
    
    init(withKey key: Data) {
        (nid, encryptionKey, privacyKey, identityKey, beaconKey) =
            Crypto.calculateKeyDerivatives(from: key)
    }
}

public class NetworkKey: Key, Codable {
    /// The timestamp represents the last time the phase property has been
    /// updated.
    public private(set) var timestamp: Date
    /// UTF-8 string, which should be a human readable name of the mesh subnet
    /// associated with this network key.
    public var name: String
    /// Index of this Network Key, in range from 0 through to 4095.
    public internal(set) var index: KeyIndex
    /// Key Refresh phase.
    public internal(set) var phase: KeyRefreshPhase = .normalOperation {
        didSet {
            timestamp = Date()
        }
    }
    /// 128-bit Network Key.
    public internal(set) var key: Data {
        willSet {
            oldKey = key
            oldNetworkId = networkId
            oldKeys = keys
        }
        didSet {
            phase = .keyDistribution
            regenerateKeyDerivatives()
        }
    }
    /// The old Network Key is present when the phase property has a non-zero
    /// value, such as when a Key Refresh procedure is in progress.
    public internal(set) var oldKey: Data? {
        didSet {
            if oldKey == nil {
                oldNetworkId = nil
                oldKeys = nil
                phase = .normalOperation
            }
        }
    }
    /// Minimum security level for a subnet associated with this Network Key.
    /// If all nodes on the subnet associated with this network key have been
    /// provisioned using network the Secure Provisioning procedure, then
    /// the value of this property for the subnet is set to .high; otherwise
    /// the value is set to `.low` and the subnet is considered less secure.
    public private(set) var minSecurity: Security
    
    /// The Network ID derived from this Network Key. This identifier
    /// is public information.
    public private(set) var networkId: Data!
    /// The Network ID derived from the old Network Key. This identifier
    /// is public information. It is set when `oldKey` is set.
    public private(set) var oldNetworkId: Data?
    /// Network Key derivatives.
    internal private(set) var keys: NetworkKeyDerivatives!
    /// Network Key derivatives.
    internal private(set) var oldKeys: NetworkKeyDerivatives?
    /// Returns the key set that should be used for encrypting outgoing packets.
    internal var transmitKeys: NetworkKeyDerivatives {
        if case .keyDistribution = phase, let oldKeys = oldKeys {
            return oldKeys
        }
        return keys
    }
    
    internal init(name: String, index: KeyIndex, key: Data) throws {
        guard index.isValidKeyIndex else {
            throw MeshNetworkError.keyIndexOutOfRange
        }
        self.name        = name
        self.index       = index
        self.key         = key
        self.minSecurity = .secure
        self.timestamp   = Date()
        
        regenerateKeyDerivatives()
    }
    
    /// Creates the primary Network Key for a mesh network.
    internal convenience init() {
        try! self.init(name: "Primary Network Key", index: 0, key: Crypto.generateRandom())
    }
    
    private func regenerateKeyDerivatives() {
        // Calculate Network ID.
        networkId = Crypto.calculateNetworkId(from: key)
        // Calculate other keys.
        keys = NetworkKeyDerivatives(withKey: key)
        
        // When the Network Key is imported from JSON, old key derivatives must
        // be calculated.
        if let oldKey = oldKey, oldNetworkId == nil {
            // Calculate Network ID.
            oldNetworkId = Crypto.calculateNetworkId(from: oldKey)
            // Calculate other keys.
            oldKeys = NetworkKeyDerivatives(withKey: oldKey)
        }
    }
    
    // MARK: - Codable
    
    /// Coding keys used to export / import Network Keys.
    enum CodingKeys: String, CodingKey {
        case name
        case index
        case key
        case oldKey
        case phase
        case minSecurity
        case timestamp
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        index = try container.decode(KeyIndex.self, forKey: .index)
        guard index.isValidKeyIndex else {
            throw DecodingError.dataCorruptedError(forKey: .index, in: container,
                                                   debugDescription: "Key Index must be in range 0-4095.")
        }
        let keyHex = try container.decode(String.self, forKey: .key)
        key = Data(hex: keyHex)
        guard !key.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .key, in: container,
                                                   debugDescription: "Key must be 32-character hexadecimal string.")
        }
        networkId = Crypto.calculateNetworkId(from: key)
        if let oldKeyHex = try container.decodeIfPresent(String.self, forKey: .oldKey) {
            oldKey = Data(hex: oldKeyHex)
            guard !oldKey!.isEmpty else {
                throw DecodingError.dataCorruptedError(forKey: .oldKey, in: container,
                                                       debugDescription: "Old key must be 32-character hexadecimal string.")
            }
        }
        phase = try container.decode(KeyRefreshPhase.self, forKey: .phase)
        minSecurity = try container.decode(Security.self, forKey: .minSecurity)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        
        regenerateKeyDerivatives()
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(index, forKey: .index)
        try container.encode(key.hex, forKey: .key)
        try container.encodeIfPresent(oldKey?.hex, forKey: .oldKey)
        try container.encode(phase, forKey: .phase)
        try container.encode(minSecurity, forKey: .minSecurity)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

// MARK: - Operators

extension NetworkKey: Equatable {
    
    public static func == (lhs: NetworkKey, rhs: NetworkKey) -> Bool {
        return lhs.index == rhs.index
    }
    
    public static func != (lhs: NetworkKey, rhs: NetworkKey) -> Bool {
        return lhs.index != rhs.index
    }
    
}

extension NetworkKey: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        if phase != .normalOperation {
            return "\(name) (index: \(index), phase: \(phase))"
        }
        return "\(name) (index: \(index))"
    }
    
}
