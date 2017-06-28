//
//  functions.swift
//  perfect-namazvakitleri
//
//  Created by Uğurcan Polat on 20.06.2017.
//
//

import Foundation
import PerfectLib
import PerfectThread // Multithread tasks
import Kanna // HTML Parsing

// Global variables for current city ID info
var countryId: Int?
var stateId:   Int?
var countyId:  Int?

// 0.15 is optimal value to avoid getting blocked because of exceeding
// allowed number of requests per time.
var sleepTime: Double = 0.10

var allDatas = Dictionary<NSUUID, Dictionary<String, prayerTimes>>()
var entriesWithError = [Dictionary<String, Any>]()
var allDays = [String]()

let generalGroup = DispatchGroup()
let retryGroup = DispatchGroup()

// Create an ephemeral session to get datas without cache
let session = URLSession(configuration: URLSessionConfiguration.ephemeral)

func readJSONFileAndGetPrayerTimes(filePath: String)
{
    var arrayOfCountries = [[String: Any]]()
    
    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath), options: .alwaysMapped)
        arrayOfCountries = try JSONSerialization.jsonObject(with: data, options: []) as! [[String:Any]]
    } catch let error {
        print(error)
        return
    }
    
    for country in arrayOfCountries {
        let name = country["CountryName"] as? String
        let displayName = country["CountryDisplayName"] as? String
        let id = country["CountryId"] as? Int
        let arrayOfCities: [[String: Any]] = country["Cities"] as! [[String : Any]]
        let countryObj = Country(name: name!, displayName: displayName!, id: id!, cities: arrayOfCities)
        
        countryId = countryObj.countryId!
        for city in countryObj.citiesOfCountry! {
            stateId = city["CityId"] as? Int
            let arrayOfCounties: [[String: Any]] = city["Counties"] as! [[String : Any]]
            for var county in arrayOfCounties {
                countyId = county["CountyId"] as? Int
                
                if countyId == 0 {
                    countyId = stateId
                }
                
                generalGroup.enter()
                getUnparsedAylik("http://www.diyanet.gov.tr/tr/PrayerTime/PrayerTimesList") { (html, status) in
                    if status == false {
                        var errorEntry = Dictionary<String, Any>()
                        errorEntry.updateValue(countryId!, forKey: "CountryId")
                        errorEntry.updateValue(stateId!, forKey: "StateId")
                        errorEntry.updateValue(countyId!, forKey: "CityId")
                        errorEntry.updateValue(country["CountryName"]!, forKey: "CountryName")
                        errorEntry.updateValue(county["uuid"]!, forKey: "uuid")
                        
                        if county["CountyName"] as? String == "No County" {
                            print("Error: \(country["CountryName"] ?? "Error!!!")/\(city["CityName"] ?? "Error!!!")")
                            errorEntry.updateValue(city["CityName"]!, forKey: "CountyName")
                        } else {
                            print("Error: \(country["CountryName"] ?? "Error!!!")/\(county["CountyName"] ?? "Error!!!")")
                            errorEntry.updateValue(county["CountyName"]!, forKey: "CountyName")
                        }
                        entriesWithError.append(errorEntry)
                        generalGroup.leave()
                        return
                    }
                    
                    // Parse html and get Dictionary of 'Aylik' prayer times
                    let times: Dictionary<String, prayerTimes> = parseAylik(html)
                    let uuid = NSUUID(uuidString: county["uuid"] as! String)
                    // Store prayer times in the dictionary for specific UUID key
                    allDatas.updateValue(times, forKey: uuid!)
                    if county["CountyName"] as? String == "No County" {
                        print("Data is gathered for: \(country["CountryName"] ?? "Error!!!")/\(city["CityName"] ?? "Error!!!")")
                    } else {
                        print("Data is gathered for: \(country["CountryName"] ?? "Error!!!")/\(county["CountyName"] ?? "Error!!!")")
                    }
                    saveToJSONFile(uuid: county["uuid"] as! String)
                    generalGroup.leave()
                }
            }
        }
    }

    // If there are entries with error, retry them
    if entriesWithError.isEmpty == false {
        retryEntriesWithError()
        
        // Wait retryEntriesWithError function to finish its job (dispatch groups)
        retryGroup.wait()
    }
    // Wait all dataTask operations to finish
    generalGroup.wait()
    
    if entriesWithError.isEmpty == false {
        print("Datas have been gathered except:")
        for entry in entriesWithError {
            print("Fail: \(entry["CountryName"] ?? "Error!!!")/\(entry["CountyName"] ?? "Error!!!")")
        }
    } else {
        print("Datas have been successfully gathered.")
    }
    
    print("All jobs are done.")
}

func retryEntriesWithError()
{
    print("RETRYING TO GET DATA FOR ENTRIES WITH ERRORS")

    for entry in entriesWithError {
        // Enter a dispatch queue to track the status of all entries
        retryGroup.enter()
        print("Retrying: \(entry["CountryName"] ?? "Error!!!")/\(entry["CountyName"] ?? "Error!!!")")
        getUnparsedAylik("http://www.diyanet.gov.tr/tr/PrayerTime/PrayerTimesList") { (html, status) in
            if status == true {
                // Parse html and get Dictionary of 'Aylik' prayer times
                let times: Dictionary<String, prayerTimes> = parseAylik(html)
                let uuid = NSUUID(uuidString: entry["uuid"] as! String)
                // Store prayer times in the dictionary for specific UUID key
                allDatas.updateValue(times, forKey: uuid!)
                print("Data is gathered for: \(entry["CountryName"] ?? "Error!!!")/\(entry["CountyName"] ?? "Error!!!")")
                saveToJSONFile(uuid: entry["uuid"] as! String)
                entriesWithError.removeFirst()
            }
            retryGroup.leave()
        }
    }
}

func getUnparsedAylik(_ url:String, completionHandler: @escaping (_ html: String?, _ isCompleted: Bool)->())
{
    var request = URLRequest(url: URL(string: url)!)
    request.httpMethod = "POST"
    // Parameters for country, state and city to send POST request
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    var parametersString = "Country=\(countryId ?? 0)&"
    parametersString.append("State=\(stateId ?? 0)&")
    parametersString.append("City=\(countyId ?? 0)&period=Aylik")
    request.httpBody = parametersString.data(using: .utf8)
    
    Threading.dispatch {
        let task = session.dataTask(with: request) { (data, response, error) in
            guard let data = data, error == nil else {
                // Check for fundamental networking errors
                completionHandler(nil, false)
                return
            }
            
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                // Check for HTTP errors
                completionHandler(nil, false)
                return
            }
            // Data is as format of html for period=Aylik
            let responseString = String(data: data, encoding: .utf8)
            
            completionHandler(responseString, true)
        }
        // Resume the task since it is in the suspended state when it is created
        task.resume()
    }
    
    // Give some time to threads to finish their job. 0.15 is optimal value to avoid
    // getting blocked because of exceeding allowed number of requests per time.
    Threading.sleep(seconds: sleepTime)
}

func parseAylik(_ html: String?) -> Dictionary<String, prayerTimes>
{
    // Dictionary of all prayer times with key of day
    var allTimes = Dictionary<String, prayerTimes>()
    
    if let doc = HTML(html: html!, encoding: .utf8) {
        let bodyNode = doc.body
        var count: Int = 1
        var day = String()
        var times: [String] = [String]()
        if let inputNodes = bodyNode?.xpath("//td") {
            for node in inputNodes {
                // First node is always day
                if count == 1 {
                    day = node.content!
                    allDays.append(day)
                    count += 1
                } else if count == 8 {
                    times.append(node.content!)
                    // Construct a prayerTimes object that stores prayer times for day
                    let prayerTime = prayerTimes(times: times)
                    allTimes.updateValue(prayerTime, forKey: day)
                    times.removeAll()
                    count = 1
                } else {
                    times.append(node.content!)
                    count += 1
                }
            }
        }
    }
    return allTimes
}

func saveToJSONFile(uuid: String) {
    // Get prayer times for a specific UUID
    var times: Dictionary<String, prayerTimes> = allDatas[NSUUID(uuidString: uuid)!]!
    // This dictionary will be used to get JSON file
    var datas = Dictionary<String, String>()
    
    if times.isEmpty {
        allDatas.removeAll()
        return
    }
    
    // Remove all datas in the dictionary since it is no longer needed
    allDatas.removeAll()
    
    for day in allDays {
        let time: prayerTimes = times[day] ?? prayerTimes()
        datas.updateValue(day, forKey: "day")
        datas.updateValue(time.imsak!,  forKey: "imsak")
        datas.updateValue(time.gunes!,  forKey: "gunes")
        datas.updateValue(time.ogle!,   forKey: "ogle")
        datas.updateValue(time.ikindi!, forKey: "ikindi")
        datas.updateValue(time.aksam!,  forKey: "aksam")
        datas.updateValue(time.yatsi!,  forKey: "yatsi")
        datas.updateValue(time.kible!,  forKey: "kible")

        guard var saveDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { allDays.removeAll(); return }
        
        // Convert date format to "yyyy.MM.dd" from "dd.MM.yyyy"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy"
        let date =  dateFormatter.date(from: day)
        dateFormatter.dateFormat = "yyyy.MM.dd"
        let convertedDate = dateFormatter.string(from: date!)
        
        saveDirectory.appendPathComponent("JSON", isDirectory: true)
        try? FileManager.default.createDirectory(atPath: saveDirectory.path, withIntermediateDirectories: false, attributes: nil)
        
        saveDirectory.appendPathComponent("\(convertedDate)", isDirectory: true)
        
        try? FileManager.default.createDirectory(atPath: saveDirectory.path, withIntermediateDirectories: false, attributes: nil)
        
        // Transform dictionary into data and save it into file
        do {
            let data = try JSONSerialization.data(withJSONObject: datas, options: [])
            let fileUrl = saveDirectory.appendingPathComponent("\(uuid).json")
            
            if FileManager.default.fileExists(atPath: fileUrl.path) {
                times.removeAll()
            } else {
                try data.write(to: fileUrl, options: [])
            }
        } catch {
            print(error)
        }
    }
    // Remove allDays array since it is created for every city.
    allDays.removeAll()
}
