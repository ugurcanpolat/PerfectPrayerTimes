//
//  country.swift
//  perfect-namazvakitleri
//
//  Created by Uğurcan Polat on 15.06.2017.
//
//

import Foundation

class Country {
    var countryName: String?
    var countryDisplayName: String?
    var countryId: Int?
    
    var citiesOfCountry: [[String: Any]]?
    
    init() {
    }
    
    init(name: String, displayName: String, id: Int, cities: [[String: Any]]) {
        countryName = name
        countryDisplayName = displayName
        countryId = id
        citiesOfCountry = cities
    }
}
