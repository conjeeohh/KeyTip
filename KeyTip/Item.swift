//
//  Item.swift
//  KeyTip
//
//  Created by 粥太浓了 on 2026/4/2.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
