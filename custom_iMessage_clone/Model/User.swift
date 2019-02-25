//
//  User.swift
//  custom_iMessage_clone
//
//  Created by William X. on 2/20/19.
//  Copyright © 2019 Will Xu . All rights reserved.
//

import UIKit
import SwiftyRSA

class User: NSObject {
    @objc var name: String?
    @objc var email: String?
    @objc var id: String?
    @objc var publicKeyString: String? {
        didSet {
            do {
                self.publicKey = try PublicKey(base64Encoded: self.publicKeyString!)
            } catch let error as NSError {
                print(error)
                return
            }
        }
    }
    @objc var privateKeyEncryptedString: String?
    var publicKey: PublicKey?
    var privateKey: PrivateKey?
    static var currentUser: User?
}
