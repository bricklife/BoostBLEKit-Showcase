//
//  HubManager.swift
//  BoostBLEKit-Showcase
//
//  Created by Shinichiro Oba on 10/07/2018.
//  Copyright © 2018 bricklife.com. All rights reserved.
//

import Foundation
import BoostBLEKit
import CoreBluetooth

struct MoveHubService {
    
    static let serviceUuid = CBUUID(string: GATT.serviceUuid)
    static let characteristicUuid = CBUUID(string: GATT.characteristicUuid)
}

protocol HubManagerDelegate: class {
    
    func didConnect(peripheral: CBPeripheral)
    func didFailToConnect(peripheral: CBPeripheral, error: Error?)
    func didDisconnect(peripheral: CBPeripheral, error: Error?)
}

class HubManager: NSObject {
    
    weak var delegate: HubManagerDelegate?
    
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?
    
    var motors: [BoostBLEKit.Port : Motor] = [:]
    var rgbLight: RGBLight?
    
    var isConnectedHub: Bool {
        return peripheral != nil
    }
    
    init(delegate: HubManagerDelegate) {
        super.init()
        
        self.delegate = delegate
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScan() {
        if centralManager.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: [MoveHubService.serviceUuid], options: nil)
        }
    }
    
    func stopScan() {
        centralManager.stopScan()
    }
    
    private func connect(peripheral: CBPeripheral) {
        if self.peripheral == nil {
            self.peripheral = peripheral
            centralManager.connect(peripheral, options: nil)
        }
    }
    
    func disconnect() {
        if let peripheral = peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
            self.peripheral = nil
            self.characteristic = nil
        }
    }
    
    private func set(characteristic: CBCharacteristic) {
        if let peripheral = peripheral, characteristic.properties.contains([.write, .notify]) {
            self.characteristic = characteristic
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }
    
    private func receive(notification: BoostBLEKit.Notification) {
        switch notification {
        case .connected(let port, let deviceType):
            print("connected:", port, deviceType)
            if let motor = Motor(port: port, deviceType: deviceType) {
                motors[port] = motor
            }
            if let rgbLight = RGBLight(port: port, deviceType: deviceType) {
                self.rgbLight = rgbLight
            }
        case .disconnected(let port):
            motors[port] = nil
            print("disconnected:", port)
        }
    }
    
    func write(data: Data) {
        print("<", data.hexString)
        if let peripheral = peripheral, let characteristic = characteristic {
            DispatchQueue.main.async {
                peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
            }
        }
    }
}

extension HubManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            print("unknown")
        case .resetting:
            print("resetting")
        case .unsupported:
            print("unsupported")
        case .unauthorized:
            print("unauthorized")
        case .poweredOff:
            print("poweredOff")
        case .poweredOn:
            print("poweredOn")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print(#function, peripheral)
        print("RSSI:", RSSI)
        print("advertisementData:", advertisementData)
        connect(peripheral: peripheral)
        stopScan()
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([MoveHubService.serviceUuid])
        delegate?.didConnect(peripheral: peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            print(#function, peripheral, error)
        }
        delegate?.didFailToConnect(peripheral: peripheral, error: error)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            print(#function, peripheral, error)
        }
        delegate?.didDisconnect(peripheral: peripheral, error: error)
    }
}

extension HubManager: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let service = peripheral.services?.first(where: { $0.uuid == MoveHubService.serviceUuid }) {
            peripheral.discoverCharacteristics([MoveHubService.characteristicUuid], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristic = service.characteristics?.first(where: { $0.uuid == MoveHubService.characteristicUuid }) {
            set(characteristic: characteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        print(">", data.hexString)
        if let notification = Notification(data: data) {
            receive(notification: notification)
        }
    }
}
