import Foundation

let filePath = Bundle.main.path(forResource: "Resources/CountryDetailedList", ofType: "json")

readJSONFileAndGetPrayerTimes(filePath: filePath!)
