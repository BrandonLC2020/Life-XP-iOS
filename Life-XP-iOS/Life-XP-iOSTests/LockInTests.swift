import Testing
import Foundation
@testable import Life_XP_iOS

@Suite("Lock In Models")
struct LockInModelTests {
    @Test func challengeModel_initializesCorrectly() {
        let id = UUID()
        let habitIDs = [UUID(), UUID()]
        let startDate = Date()
        let challenge = LockInChallenge(
            id: id,
            habitIDs: habitIDs,
            startDate: startDate,
            durationDays: 7
        )
        #expect(challenge.status == .active)
        #expect(challenge.strikesCount == 0)
        #expect(challenge.maxStrikes == 3)
    }
}
