import Foundation
import CloudKit

class CloudKitManager {
    static let shared = CloudKitManager()
    
    let container = CKContainer.default()
    let privateDatabase = CKContainer.default().privateCloudDatabase
    
    // User Record Type
    let userRecordType = "UserStats"
    let habitRecordType = "Habit"
    
    func saveUserStats(_ user: LifeXPUser, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        let recordID = CKRecord.ID(recordName: "DefaultUserStats")
        
        privateDatabase.fetch(withRecordID: recordID) { (record, error) in
            let userRecord = record ?? CKRecord(recordType: self.userRecordType, recordID: recordID)
            
            userRecord["name"] = user.name as CKRecordValue
            userRecord["level"] = user.level as CKRecordValue
            userRecord["experience"] = user.experience as CKRecordValue
            userRecord["strength"] = user.strength as CKRecordValue
            userRecord["intelligence"] = user.intelligence as CKRecordValue
            userRecord["vitality"] = user.vitality as CKRecordValue
            userRecord["charisma"] = user.charisma as CKRecordValue
            userRecord["lastSyncedSteps"] = user.lastSyncedSteps as CKRecordValue
            userRecord["lastSyncedCalories"] = user.lastSyncedCalories as CKRecordValue
            userRecord["lastSyncedSleep"] = user.lastSyncedSleep as CKRecordValue
            userRecord["lastSyncedWater"] = user.lastSyncedWater as CKRecordValue
            
            self.privateDatabase.save(userRecord) { (savedRecord, saveError) in
                if let saveError = saveError {
                    completion(.failure(saveError))
                } else if let savedRecord = savedRecord {
                    completion(.success(savedRecord))
                }
            }
        }
    }
    
    func fetchUserStats(completion: @escaping (Result<LifeXPUser, Error>) -> Void) {
        let recordID = CKRecord.ID(recordName: "DefaultUserStats")
        
        privateDatabase.fetch(withRecordID: recordID) { (record, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let record = record else {
                completion(.failure(NSError(domain: "CloudKitManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "No user record found"])))
                return
            }
            
            var user = LifeXPUser()
            user.name = record["name"] as? String ?? "Adventurer"
            user.level = record["level"] as? Int ?? 1
            user.experience = record["experience"] as? Int ?? 0
            user.strength = record["strength"] as? Int ?? 10
            user.intelligence = record["intelligence"] as? Int ?? 10
            user.vitality = record["vitality"] as? Int ?? 10
            user.charisma = record["charisma"] as? Int ?? 10
            user.lastSyncedSteps = record["lastSyncedSteps"] as? Int ?? 0
            user.lastSyncedCalories = record["lastSyncedCalories"] as? Double ?? 0.0
            user.lastSyncedSleep = record["lastSyncedSleep"] as? Double ?? 0.0
            user.lastSyncedWater = record["lastSyncedWater"] as? Double ?? 0.0
            
            completion(.success(user))
        }
    }
    
    func saveHabits(_ habits: [Habit], completion: @escaping (Error?) -> Void) {
        // Delete old habits first (simple approach for MVP)
        let query = CKQuery(recordType: habitRecordType, predicate: NSPredicate(value: true))
        
        privateDatabase.perform(query, inZoneWith: nil) { (records, error) in
            let deleteIDs = records?.map { $0.recordID } ?? []
            let deleteOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: deleteIDs)
            
            deleteOperation.modifyRecordsCompletionBlock = { (_, _, deleteError) in
                if let deleteError = deleteError {
                    completion(deleteError)
                    return
                }
                
                let recordsToSave = habits.map { habit -> CKRecord in
                    let record = CKRecord(recordType: self.habitRecordType)
                    record["title"] = habit.title as CKRecordValue
                    record["description"] = habit.description as CKRecordValue
                    record["xpReward"] = habit.xpReward as CKRecordValue
                    record["frequency"] = habit.frequency.rawValue as CKRecordValue
                    if let lastDate = habit.lastCompletedDate {
                        record["lastCompletedDate"] = lastDate as CKRecordValue
                    }
                    return record
                }
                
                let saveOperation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
                saveOperation.modifyRecordsCompletionBlock = { (_, _, saveError) in
                    completion(saveError)
                }
                self.privateDatabase.add(saveOperation)
            }
            self.privateDatabase.add(deleteOperation)
        }
    }
    
    func fetchHabits(completion: @escaping (Result<[Habit], Error>) -> Void) {
        let query = CKQuery(recordType: habitRecordType, predicate: NSPredicate(value: true))
        
        privateDatabase.perform(query, inZoneWith: nil) { (records, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            let habits = records?.compactMap { record -> Habit? in
                guard let title = record["title"] as? String,
                      let description = record["description"] as? String,
                      let xpReward = record["xpReward"] as? Int,
                      let frequencyString = record["frequency"] as? String,
                      let frequency = HabitFrequency(rawValue: frequencyString) else {
                    return nil
                }
                
                var habit = Habit(title: title, description: description, xpReward: xpReward, frequency: frequency)
                habit.lastCompletedDate = record["lastCompletedDate"] as? Date
                return habit
            } ?? []
            
            completion(.success(habits))
        }
    }
}
