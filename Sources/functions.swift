//
//  functions.swift
//  perfect-namazvakitleri
//
//  Created by Uğurcan Polat on 20.06.2017.
//
//

import Foundation
import PerfectLib
import PerfectHTTP
import PerfectHTTPServer
import PerfectThread
import Kanna

var countryId: Int?
var stateId:   Int?
var countyId:  Int?

var allDatas = Dictionary<NSUUID, Dictionary<String, prayerTimes>>()
var allDays = [String]()

let session = URLSession(configuration: URLSessionConfiguration.ephemeral)

var dataTaskQueue = Threading.getQueue(type: Threading.QueueType.concurrent)
var tasks = [URLSessionDataTask]()

func readJSONFileAndGetParameters()
{
    var arrayOfCountries = [[String: Any]]()
    
    let path2: String? = "/Users/ugurcanpolat/Downloads/CountryDetailedList.json"
    
    if let path = path2 {
        //if let path = Bundle.main.path(forResource: "CountryDetailedList", ofType: "json") {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
            arrayOfCountries = try! JSONSerialization.jsonObject(with: data, options: []) as! [[String:Any]]
            
            for country in arrayOfCountries {
                let name = country["CountryName"] as? String
                let displayName = country["CountryDisplayName"] as? String
                let id = country["CountryId"] as? Int
                var arrayOfCities: [[String: Any]] = country["Cities"] as! [[String : Any]]
                let countryObj = Country(name: name!, displayName: displayName!, id: id!, cities: arrayOfCities)
                
                arrayOfCities.removeAll()
                countryId = countryObj.countryId!
                for city in countryObj.citiesOfCountry! {
                    stateId = city["CityId"] as? Int
                    var arrayOfCounties: [[String: Any]] = city["Counties"] as! [[String : Any]]
                    for var county in arrayOfCounties {
                        countyId = county["CountyId"] as? Int
                        
                        if countyId == 0 {
                            countyId = stateId
                        }
                        
                        var condition = true
                        //while condition {
                            getUnparsedAylikAndParse("http://www.diyanet.gov.tr/tr/PrayerTime/PrayerTimesList") { (html, status) in
                                if status == false {
                                    if county["CountyName"] as? String == "No County" {
                                        print("Retrying: \(country["CountryName"] ?? "Error!!!")/\(city["CityName"] ?? "Error!!!")")
                                    } else {
                                        print("Retrying: \(country["CountryName"] ?? "Error!!!")/\(county["CountyName"] ?? "Error!!!")")
                                    }
                                    return
                                }
                                // Parse html and get Dictionary of 'Aylik' prayer times
                                var times: Dictionary<String, prayerTimes> = parseAylik(html)
                                let uuid = NSUUID(uuidString: county["uuid"] as! String)
                                allDatas.updateValue(times, forKey: uuid!)
                                times.removeAll()
                                if county["CountyName"] as? String == "No County" {
                                    print("Data is gathered for: \(country["CountryName"] ?? "Error!!!")/\(city["CityName"] ?? "Error!!!")")
                                } else {
                                    print("Data is gathered for: \(country["CountryName"] ?? "Error!!!")/\(county["CountyName"] ?? "Error!!!")")
                                }
                                saveToJSONFile(uuid: county["uuid"] as! String)
                                condition = false
                            }
                        //}
                    }
                }
            }
        } catch let error {
            print(error)
        }
    } else {
        print("Invalid filename/path.")
    }
}

func getUnparsedAylikAndParse(_ url:String, completionHandler: @escaping (_ html: String?, _ isCompleted: Bool)->())
{
    var request = URLRequest(url: URL(string: url)!)
    request.httpMethod = "POST"
    // parameters for country, state and city
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    var parametersString = "Country=\(countryId ?? 0)&"
    parametersString.append("State=\(stateId ?? 0)&")
    parametersString.append("City=\(countyId ?? 0)&period=Aylik")
    request.httpBody = parametersString.data(using: .utf8)
    
    Threading.dispatch {
        let task = session.dataTask(with: request) { (data, response, error) in
            guard let data = data, error == nil else {
                // check for fundamental networking error
                completionHandler(nil, false)
                return
            }
            
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                // check for http errors
                completionHandler(nil, false)
                return
            }
            // Data is as format of html for period=Aylik
            let responseString = String(data: data, encoding: .utf8)
            
            completionHandler(responseString, true)
        }
        task.resume()
        tasks.append(task)
    }
    Threading.sleep(seconds: 0.15)
}

func parseAylik(_ html: String?) -> Dictionary<String, prayerTimes>
{
    var allTimes = Dictionary<String, prayerTimes>()
    
    if let doc = HTML(html: html!, encoding: .utf8) {
        let bodyNode = doc.body
        var count: Int = 1
        var day = String()
        var times: [String] = [String]()
        if let inputNodes = bodyNode?.xpath("//td") {
            for node in inputNodes {
                if count == 1 {
                    day = node.content!
                    allDays.append(day)
                    count += 1
                } else if count == 8 {
                    times.append(node.content!)
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
    var times: Dictionary<String, prayerTimes> = allDatas[NSUUID(uuidString: uuid)!]!
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
        
        guard var saveDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
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
                allDays.removeAll()
                return
            }
            try data.write(to: fileUrl, options: [])
        } catch {
            print(error)
        }
        datas.removeAll()
    }
    times.removeAll()
    allDays.removeAll()
}

