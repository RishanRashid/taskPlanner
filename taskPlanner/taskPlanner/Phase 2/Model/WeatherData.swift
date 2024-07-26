//
//  WeatherData.swift
//  taskPlanner
//
//  Created by Allnet Systems on 7/26/24.
//

import Foundation

struct WeatherData:Decodable {
    let name: String
    let main: Main
    let weather: [Weather]
}

struct Main: Decodable {
    let temp: Double
}

struct Weather: Decodable {
    let id: Int
}

