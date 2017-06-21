//
//  prayerTimes.swift
//  perfect-namazvakitleri
//
//  Created by Uğurcan Polat on 15.06.2017.
//
//

import Foundation

class prayerTimes {
    var imsak: String?
    var gunes: String?
    var ogle: String?
    var ikindi: String?
    var aksam: String?
    var yatsi: String?
    var kible: String?
    
    init() {
        imsak = ""
        gunes = ""
        ogle = ""
        ikindi = ""
        aksam = ""
        yatsi = ""
        kible = ""
    }
    
    init(times: [String]) {
        imsak = times[0]
        gunes = times[1]
        ogle = times[2]
        ikindi = times[3]
        aksam = times[4]
        yatsi = times[5]
        kible = times[6]
    }
}
