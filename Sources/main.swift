import Foundation

let filePath = Bundle.main.path(forResource: "Resources/CountryDetailedList", ofType: "json")
let defaultPath = "./Resources/CountryDetailedList.json"
readJSONFileAndGetPrayerTimes(filePath: filePath ?? defaultPath)
