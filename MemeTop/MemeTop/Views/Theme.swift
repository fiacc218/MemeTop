import SwiftUI

enum Theme {
    static let up = Color(red: 0.2, green: 0.6, blue: 1.0)       // bright blue
    static let down = Color(red: 1.0, green: 0.6, blue: 0.2)     // orange
    static let upBg = Color(red: 0.2, green: 0.6, blue: 1.0).opacity(0.12)
    static let downBg = Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.12)
}
